#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  bootstrap_tools.sh [--lock <file>] [--root <dir>]

Clones or updates pinned tool repositories for reproducible OpenClaw research runs.

Defaults:
  --lock pipelines/openclaw/tooling.lock.json
  --root third_party
USAGE
}

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOCK_FILE="${REPO_ROOT}/pipelines/openclaw/tooling.lock.json"
TOOLS_ROOT="${REPO_ROOT}/third_party"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --lock)
      LOCK_FILE="${2:-}"
      shift 2
      ;;
    --root)
      TOOLS_ROOT="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[openclaw-bootstrap] unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ "${LOCK_FILE}" != /* ]]; then
  LOCK_FILE="${REPO_ROOT}/${LOCK_FILE}"
fi
if [[ "${TOOLS_ROOT}" != /* ]]; then
  TOOLS_ROOT="${REPO_ROOT}/${TOOLS_ROOT}"
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "[openclaw-bootstrap] missing required command: jq" >&2
  exit 1
fi
if ! command -v git >/dev/null 2>&1; then
  echo "[openclaw-bootstrap] missing required command: git" >&2
  exit 1
fi
if [[ ! -f "${LOCK_FILE}" ]]; then
  echo "[openclaw-bootstrap] lock file not found: ${LOCK_FILE}" >&2
  exit 1
fi

if ! jq -e '.schema_version == "v1" and (.tools | type == "array")' "${LOCK_FILE}" >/dev/null; then
  echo "[openclaw-bootstrap] invalid lock schema: ${LOCK_FILE}" >&2
  exit 1
fi

mkdir -p "${TOOLS_ROOT}"

bootstrap_one() {
  local name="$1"
  local repo="$2"
  local commit="$3"
  local dest="${TOOLS_ROOT}/${name}"

  if [[ -d "${dest}/.git" ]]; then
    echo "[openclaw-bootstrap] update ${name} at ${dest}"
    git -C "${dest}" fetch --tags --prune origin
  else
    echo "[openclaw-bootstrap] clone ${name} from ${repo}"
    git clone --filter=blob:none --no-checkout "${repo}" "${dest}"
    git -C "${dest}" fetch --tags --prune origin
  fi

  if ! git -C "${dest}" cat-file -e "${commit}^{commit}" 2>/dev/null; then
    git -C "${dest}" fetch --tags --prune origin "${commit}" >/dev/null 2>&1 || true
  fi
  git -C "${dest}" checkout --detach "${commit}" >/dev/null
  if [[ -f "${dest}/.gitmodules" ]]; then
    git -C "${dest}" submodule update --init --recursive >/dev/null
  fi

  local head_sha
  head_sha="$(git -C "${dest}" rev-parse HEAD)"
  if [[ "${head_sha}" != "${commit}" ]]; then
    echo "[openclaw-bootstrap] commit mismatch for ${name}: expected=${commit} got=${head_sha}" >&2
    exit 1
  fi
  echo "[openclaw-bootstrap] pinned ${name} @ ${head_sha}"
}

while IFS= read -r row; do
  name="$(printf '%s' "${row}" | jq -r '.name')"
  repo="$(printf '%s' "${row}" | jq -r '.repository')"
  commit="$(printf '%s' "${row}" | jq -r '.commit')"
  if [[ -z "${name}" || -z "${repo}" || -z "${commit}" || "${name}" == "null" || "${repo}" == "null" || "${commit}" == "null" ]]; then
    echo "[openclaw-bootstrap] invalid tool entry in lock file" >&2
    exit 1
  fi
  bootstrap_one "${name}" "${repo}" "${commit}"
done < <(jq -c '.tools[]' "${LOCK_FILE}")

echo "[openclaw-bootstrap] done"
echo "[openclaw-bootstrap] export WRKR_REPO_PATH=${TOOLS_ROOT}/wrkr"
echo "[openclaw-bootstrap] export GAIT_REPO_PATH=${TOOLS_ROOT}/gait"
echo "[openclaw-bootstrap] export OPENCLAW_REPO_PATH=${TOOLS_ROOT}/openclaw"
