#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  promote_run_artifacts.sh --run-id <id> [--dest <dir>] [--raw-archive-out <path>] [--force]

Promotes a canonical, git-trackable reproducibility set from a completed OpenClaw run.

Default destination:
  reports/openclaw-2026/data/runs/<run_id>/
EOF
}

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUN_ID=""
DEST_DIR=""
RAW_ARCHIVE_OUT=""
FORCE=0
RAW_ARCHIVE_EXCLUDE_PATTERN=""

file_sha256() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "${file}" | awk '{print $1}'
    return
  fi
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "${file}" | awk '{print $1}'
    return
  fi
  echo "unavailable"
}

contains_machine_path() {
  local file="$1"
  jq -e '.. | strings | select(test("^/Users/|^/home/"))' "${file}" >/dev/null 2>&1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)
      RUN_ID="${2:-}"
      shift 2
      ;;
    --dest)
      DEST_DIR="${2:-}"
      shift 2
      ;;
    --raw-archive-out)
      RAW_ARCHIVE_OUT="${2:-}"
      shift 2
      ;;
    --force)
      FORCE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[openclaw-promote] unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "${RUN_ID}" ]]; then
  echo "[openclaw-promote] --run-id is required" >&2
  usage >&2
  exit 1
fi

RUN_DIR="${REPO_ROOT}/runs/openclaw/${RUN_ID}"
if [[ ! -d "${RUN_DIR}" ]]; then
  echo "[openclaw-promote] run directory not found: ${RUN_DIR}" >&2
  exit 1
fi

if [[ -z "${DEST_DIR}" ]]; then
  DEST_DIR="${REPO_ROOT}/reports/openclaw-2026/data/runs/${RUN_ID}"
fi

if [[ -e "${DEST_DIR}" && "${FORCE}" -ne 1 ]]; then
  if [[ -n "$(find "${DEST_DIR}" -mindepth 1 -maxdepth 1 2>/dev/null)" ]]; then
    echo "[openclaw-promote] destination already contains files: ${DEST_DIR}" >&2
    echo "[openclaw-promote] use --force to overwrite" >&2
    exit 1
  fi
fi
mkdir -p "${DEST_DIR}"

copy_file() {
  local src_rel="$1"
  local dst_rel="$2"
  local src="${RUN_DIR}/${src_rel}"
  local dst="${DEST_DIR}/${dst_rel}"
  if [[ ! -f "${src}" ]]; then
    echo "[openclaw-promote] missing required run artifact: runs/openclaw/${RUN_ID}/${src_rel}" >&2
    exit 1
  fi
  mkdir -p "$(dirname "${dst}")"
  cp "${src}" "${dst}"
}

copy_file "artifacts/run-manifest.json" "run-manifest.json"
copy_file "artifacts/claim-values.json" "claim-values.json"
copy_file "artifacts/threshold-evaluation.json" "threshold-evaluation.json"
copy_file "artifacts/verification/evidence-verification.json" "evidence-verification.json"
copy_file "artifacts/anecdotes.json" "anecdotes.json"
copy_file "artifacts/manifest.sha256" "run-tree-manifest.sha256"
copy_file "derived/scenario_summary.json" "scenario-summary.json"
copy_file "raw/wrkr/wrkr-scan.json" "wrkr-scan.json"

for json_file in "run-manifest.json" "claim-values.json" "threshold-evaluation.json"; do
  if contains_machine_path "${DEST_DIR}/${json_file}"; then
    echo "[openclaw-promote] machine-specific absolute path found in ${json_file}" >&2
    exit 1
  fi
done

if jq -e '.mode == "scaffold"' "${DEST_DIR}/run-manifest.json" >/dev/null; then
  echo "[openclaw-promote] invalid run-manifest mode=scaffold; run must be executed before promotion" >&2
  exit 1
fi

if jq -e '.execution_mode == "container" and .parallel_lanes == false' "${DEST_DIR}/run-manifest.json" >/dev/null; then
  echo "[openclaw-promote] invalid run-manifest: container execution must report parallel_lanes=true" >&2
  exit 1
fi

raw_archive_rel=""
raw_archive_sha="unavailable"
if [[ -n "${RAW_ARCHIVE_OUT}" ]]; then
  raw_archive_path="${RAW_ARCHIVE_OUT}"
  if [[ "${raw_archive_path}" != /* ]]; then
    raw_archive_path="${REPO_ROOT}/${raw_archive_path}"
  fi
  mkdir -p "$(dirname "${raw_archive_path}")"
  if [[ "${raw_archive_path}" == "${RUN_DIR}/"* ]]; then
    RAW_ARCHIVE_EXCLUDE_PATTERN="${RUN_ID}/${raw_archive_path#${RUN_DIR}/}"
  fi
  tar_items=()
  for rel in config raw derived artifacts; do
    if [[ -e "${RUN_DIR}/${rel}" ]]; then
      tar_items+=("${RUN_ID}/${rel}")
    fi
  done
  if [[ "${#tar_items[@]}" -eq 0 ]]; then
    echo "[openclaw-promote] no run content available for raw archive" >&2
    exit 1
  fi
  (
    cd "${REPO_ROOT}/runs/openclaw"
    if [[ -n "${RAW_ARCHIVE_EXCLUDE_PATTERN}" ]]; then
      tar --exclude="${RUN_ID}/artifacts/publish-pack" --exclude="${RAW_ARCHIVE_EXCLUDE_PATTERN}" -czf "${raw_archive_path}" "${tar_items[@]}"
    else
      tar --exclude="${RUN_ID}/artifacts/publish-pack" -czf "${raw_archive_path}" "${tar_items[@]}"
    fi
  )
  raw_archive_sha="$(file_sha256 "${raw_archive_path}")"
  raw_archive_rel="${raw_archive_path#${REPO_ROOT}/}"
  printf '%s  %s\n' "${raw_archive_sha}" "$(basename "${raw_archive_path}")" > "${raw_archive_path}.sha256"
fi

jq -n \
  --arg run_id "${RUN_ID}" \
  --arg promoted_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg source_run_dir "runs/openclaw/${RUN_ID}" \
  --arg destination_dir "${DEST_DIR#${REPO_ROOT}/}" \
  --arg raw_archive_path "${raw_archive_rel}" \
  --arg raw_archive_sha256 "${raw_archive_sha}" \
  '{
    schema_version: "v1",
    report_id: "openclaw-2026",
    run_id: $run_id,
    promoted_at: $promoted_at,
    source_run_dir: $source_run_dir,
    destination_dir: $destination_dir,
    files: [
      "run-manifest.json",
      "claim-values.json",
      "threshold-evaluation.json",
      "evidence-verification.json",
      "anecdotes.json",
      "run-tree-manifest.sha256",
      "scenario-summary.json",
      "wrkr-scan.json"
    ],
    raw_archive: (
      if $raw_archive_path == "" then
        null
      else
        {path: $raw_archive_path, sha256: $raw_archive_sha256}
      end
    )
  }' > "${DEST_DIR}/promoted-artifacts.json"

"${REPO_ROOT}/pipelines/common/hash_manifest.sh" \
  --input "${DEST_DIR}" \
  --output "${DEST_DIR}/bundle.sha256"

echo "[openclaw-promote] wrote ${DEST_DIR}"
if [[ -n "${raw_archive_rel}" ]]; then
  echo "[openclaw-promote] raw archive: ${raw_archive_rel}"
  echo "[openclaw-promote] raw archive sha: ${raw_archive_sha}"
fi
