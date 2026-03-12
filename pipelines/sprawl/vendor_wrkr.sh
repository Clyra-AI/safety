#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  vendor_wrkr.sh [--source <path>] [--dest <path>] [--lock-file <path>] [--allow-dirty-source] [--dry-run]

Copies a clean Wrkr source tree into third_party/wrkr, strips nested git state,
and writes reproducible vendor provenance metadata.
USAGE
}

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE_PATH="${SOURCE_PATH:-${REPO_ROOT}/../wrkr}"
DEST_PATH="${DEST_PATH:-${REPO_ROOT}/third_party/wrkr}"
LOCK_FILE="${LOCK_FILE:-${REPO_ROOT}/pipelines/sprawl/tooling.lock.json}"
ALLOW_DIRTY_SOURCE=0
DRY_RUN=0

sha256_cmd() {
  if command -v sha256sum >/dev/null 2>&1; then
    echo "sha256sum"
  elif command -v shasum >/dev/null 2>&1; then
    echo "shasum -a 256"
  else
    echo ""
  fi
}

dir_sha256() {
  local dir="$1"
  shift || true
  local find_args=(find . -type f)
  local exclude_prefix
  if [[ ! -d "${dir}" ]]; then
    echo "unavailable"
    return
  fi
  if [[ "$#" -gt 0 ]]; then
    for exclude_prefix in "$@"; do
      [[ -z "${exclude_prefix}" ]] && continue
      find_args+=(! -path "./${exclude_prefix}" ! -path "./${exclude_prefix}/*")
    done
  fi
  if command -v sha256sum >/dev/null 2>&1; then
    (
      cd "${dir}" &&
      "${find_args[@]}" -print0 |
        LC_ALL=C sort -z |
        xargs -0 sha256sum |
        sha256sum | awk '{print $1}'
    )
  elif command -v shasum >/dev/null 2>&1; then
    (
      cd "${dir}" &&
      "${find_args[@]}" -print0 |
        LC_ALL=C sort -z |
        xargs -0 shasum -a 256 |
        shasum -a 256 | awk '{print $1}'
    )
  else
    echo "unavailable"
  fi
}

resolve_path() {
  local path="$1"
  local root="$2"
  if [[ "${path}" = /* ]]; then
    printf '%s\n' "${path}"
  else
    printf '%s/%s\n' "${root}" "${path}"
  fi
}

relative_to_repo() {
  local path="$1"
  case "${path}" in
    "${REPO_ROOT}")
      printf '.\n'
      ;;
    "${REPO_ROOT}"/*)
      printf '%s\n' "${path#${REPO_ROOT}/}"
      ;;
    *)
      printf '%s\n' "${path}"
      ;;
  esac
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source)
      SOURCE_PATH="${2:-}"
      shift 2
      ;;
    --dest)
      DEST_PATH="${2:-}"
      shift 2
      ;;
    --lock-file)
      LOCK_FILE="${2:-}"
      shift 2
      ;;
    --allow-dirty-source)
      ALLOW_DIRTY_SOURCE=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[vendor-wrkr] unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if ! command -v git >/dev/null 2>&1; then
  echo "[vendor-wrkr] git is required" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "[vendor-wrkr] jq is required" >&2
  exit 1
fi
if ! command -v rsync >/dev/null 2>&1; then
  echo "[vendor-wrkr] rsync is required" >&2
  exit 1
fi

SOURCE_ABS="$(resolve_path "${SOURCE_PATH}" "${REPO_ROOT}")"
DEST_ABS="$(resolve_path "${DEST_PATH}" "${REPO_ROOT}")"
LOCK_FILE_ABS="$(resolve_path "${LOCK_FILE}" "${REPO_ROOT}")"

if [[ ! -d "${SOURCE_ABS}/.git" ]]; then
  echo "[vendor-wrkr] source must be a git checkout: ${SOURCE_ABS}" >&2
  exit 1
fi

SOURCE_STATUS="$(git -C "${SOURCE_ABS}" status --short 2>/dev/null || true)"
if [[ "${ALLOW_DIRTY_SOURCE}" -ne 1 && -n "${SOURCE_STATUS}" ]]; then
  echo "[vendor-wrkr] source checkout is dirty: ${SOURCE_ABS}" >&2
  echo "[vendor-wrkr] use --allow-dirty-source only for explicit non-public lab exceptions" >&2
  exit 1
fi

SOURCE_COMMIT="$(git -C "${SOURCE_ABS}" rev-parse HEAD)"
SOURCE_REF="$(git -C "${SOURCE_ABS}" describe --tags --always --dirty 2>/dev/null || echo "${SOURCE_COMMIT}")"
SOURCE_REMOTE_URL="$(git -C "${SOURCE_ABS}" config --get remote.origin.url 2>/dev/null || echo "unavailable")"
DEST_REL="$(relative_to_repo "${DEST_ABS}")"

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "${tmp_dir}"
}
trap cleanup EXIT

rsync -a --delete --exclude '.git' --exclude '.DS_Store' "${SOURCE_ABS}/" "${tmp_dir}/wrkr/"
rm -rf "${tmp_dir}/wrkr/.git"
VENDORED_TREE_SHA256="$(dir_sha256 "${tmp_dir}/wrkr")"

jq -n \
  --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg vendored_path "${DEST_REL}" \
  --arg source_remote_url "${SOURCE_REMOTE_URL}" \
  --arg source_commit_sha "${SOURCE_COMMIT}" \
  --arg source_ref "${SOURCE_REF}" \
  --arg source_tree_sha256 "${VENDORED_TREE_SHA256}" \
  --argjson source_clean "$(if [[ -z "${SOURCE_STATUS}" ]]; then echo "true"; else echo "false"; fi)" \
  '{
    schema_version: "v1",
    dependency: "wrkr",
    generated_at: $generated_at,
    vendored_path: $vendored_path,
    source: {
      remote_url: $source_remote_url,
      commit_sha: $source_commit_sha,
      ref: $source_ref,
      clean: $source_clean,
      tree_sha256: $source_tree_sha256
    }
  }' > "${tmp_dir}/wrkr/VENDOR_PROVENANCE.json"

if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "[vendor-wrkr] dry-run source=${SOURCE_ABS} commit=${SOURCE_COMMIT} ref=${SOURCE_REF}"
  echo "[vendor-wrkr] dry-run dest=${DEST_ABS}"
  echo "[vendor-wrkr] dry-run lock-file=${LOCK_FILE_ABS}"
  exit 0
fi

mkdir -p "$(dirname "${DEST_ABS}")"
rsync -a --delete "${tmp_dir}/wrkr/" "${DEST_ABS}/"
rm -rf "${DEST_ABS}/.git"

mkdir -p "$(dirname "${LOCK_FILE_ABS}")"
if [[ -f "${LOCK_FILE_ABS}" ]]; then
  jq --arg repo "${SOURCE_REMOTE_URL}" \
     --arg commit "${SOURCE_COMMIT}" \
     --arg ref "${SOURCE_REF}" \
     --arg tree_sha256 "${VENDORED_TREE_SHA256}" '
    .schema_version = "v1"
    | .tools = ((.tools // []) | map(select(.name != "wrkr")) + [{
        name: "wrkr",
        repository: $repo,
        commit: $commit,
        ref: $ref,
        tree_sha256: $tree_sha256
      }])
  ' "${LOCK_FILE_ABS}" > "${LOCK_FILE_ABS}.tmp"
else
  jq -n \
    --arg repo "${SOURCE_REMOTE_URL}" \
    --arg commit "${SOURCE_COMMIT}" \
    --arg ref "${SOURCE_REF}" \
    --arg tree_sha256 "${VENDORED_TREE_SHA256}" '
    {
      schema_version: "v1",
      tools: [{
        name: "wrkr",
        repository: $repo,
        commit: $commit,
        ref: $ref,
        tree_sha256: $tree_sha256
      }]
    }
  ' > "${LOCK_FILE_ABS}.tmp"
fi
mv "${LOCK_FILE_ABS}.tmp" "${LOCK_FILE_ABS}"

echo "[vendor-wrkr] vendored ${SOURCE_COMMIT} (${SOURCE_REF}) into ${DEST_ABS}"
echo "[vendor-wrkr] provenance=${DEST_ABS}/VENDOR_PROVENANCE.json"
echo "[vendor-wrkr] tooling-lock=${LOCK_FILE_ABS}"
