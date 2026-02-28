#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  publish_pack.sh --run-id <id> [--output <dir>] [--include-raw-archive]

Assembles dual publication bundles for the OpenClaw report:
  - research-pack
  - press-pack
EOF
}

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUN_ID=""
OUTPUT_DIR=""
INCLUDE_RAW_ARCHIVE=0

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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)
      RUN_ID="${2:-}"
      shift 2
      ;;
    --output)
      OUTPUT_DIR="${2:-}"
      shift 2
      ;;
    --include-raw-archive)
      INCLUDE_RAW_ARCHIVE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[openclaw-publish] unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "${RUN_ID}" ]]; then
  echo "[openclaw-publish] --run-id is required" >&2
  usage >&2
  exit 1
fi

if [[ -z "${OUTPUT_DIR}" ]]; then
  OUTPUT_DIR="${REPO_ROOT}/runs/openclaw/${RUN_ID}/artifacts/publish-pack"
fi
mkdir -p "${OUTPUT_DIR}"
RUN_DIR="${REPO_ROOT}/runs/openclaw/${RUN_ID}"
if [[ ! -d "${RUN_DIR}" ]]; then
  echo "[openclaw-publish] run directory not found: ${RUN_DIR}" >&2
  exit 1
fi

required_paths=(
  "reports/openclaw-2026/definitions.md"
  "reports/openclaw-2026/study-protocol.md"
  "reports/openclaw-2026/methodology.md"
  "reports/openclaw-2026/manuscript"
  "reports/openclaw-2026/press-pack"
  "reports/openclaw-2026/container-config"
  "reports/openclaw-2026/data"
  "claims/openclaw-2026/claims.json"
  "citations/openclaw-timeline-sources.md"
)

for rel in "${required_paths[@]}"; do
  if [[ ! -e "${REPO_ROOT}/${rel}" ]]; then
    echo "[openclaw-publish] missing required path: ${rel}" >&2
    exit 1
  fi
done

RESEARCH_DIR="${OUTPUT_DIR}/research-pack"
PRESS_DIR="${OUTPUT_DIR}/press-pack"

mkdir -p "${RESEARCH_DIR}/report-package"
cp -R "${REPO_ROOT}/reports/openclaw-2026/." "${RESEARCH_DIR}/report-package/"
cp "${REPO_ROOT}/claims/openclaw-2026/claims.json" "${RESEARCH_DIR}/claims.json"
cp "${REPO_ROOT}/citations/openclaw-timeline-sources.md" "${RESEARCH_DIR}/timeline-sources.md"

mkdir -p "${PRESS_DIR}"
cp -R "${REPO_ROOT}/reports/openclaw-2026/press-pack/." "${PRESS_DIR}/"
cp "${REPO_ROOT}/claims/openclaw-2026/claims.json" "${PRESS_DIR}/claims.json"

if [[ -f "${RUN_DIR}/artifacts/run-manifest.json" ]]; then
  cp "${RUN_DIR}/artifacts/run-manifest.json" "${RESEARCH_DIR}/run-manifest.json"
  cp "${RUN_DIR}/artifacts/run-manifest.json" "${PRESS_DIR}/run-manifest.json"
fi
if [[ -f "${RUN_DIR}/artifacts/claim-values.json" ]]; then
  cp "${RUN_DIR}/artifacts/claim-values.json" "${RESEARCH_DIR}/claim-values.json"
fi
if [[ -f "${RUN_DIR}/artifacts/threshold-evaluation.json" ]]; then
  cp "${RUN_DIR}/artifacts/threshold-evaluation.json" "${RESEARCH_DIR}/threshold-evaluation.json"
  cp "${RUN_DIR}/artifacts/threshold-evaluation.json" "${PRESS_DIR}/threshold-evaluation.json"
fi
if [[ -f "${RUN_DIR}/artifacts/anecdotes.json" ]]; then
  cp "${RUN_DIR}/artifacts/anecdotes.json" "${RESEARCH_DIR}/anecdotes.json"
  cp "${RUN_DIR}/artifacts/anecdotes.json" "${PRESS_DIR}/anecdotes.json"
fi
if [[ -f "${RUN_DIR}/artifacts/verification/evidence-verification.json" ]]; then
  cp "${RUN_DIR}/artifacts/verification/evidence-verification.json" "${RESEARCH_DIR}/evidence-verification.json"
fi
if [[ -f "${RUN_DIR}/artifacts/manifest.sha256" ]]; then
  cp "${RUN_DIR}/artifacts/manifest.sha256" "${RESEARCH_DIR}/run-manifest.sha256"
fi
if [[ -f "${RUN_DIR}/derived/scenario_summary.json" ]]; then
  cp "${RUN_DIR}/derived/scenario_summary.json" "${RESEARCH_DIR}/scenario-summary.json"
  cp "${RUN_DIR}/derived/scenario_summary.json" "${PRESS_DIR}/scenario-summary.json"
fi
if [[ -f "${RUN_DIR}/raw/wrkr/wrkr-scan.json" ]]; then
  cp "${RUN_DIR}/raw/wrkr/wrkr-scan.json" "${RESEARCH_DIR}/wrkr-scan.json"
fi
if [[ -d "${RUN_DIR}/derived" ]]; then
  mkdir -p "${RESEARCH_DIR}/run-derived"
  cp -R "${RUN_DIR}/derived/." "${RESEARCH_DIR}/run-derived/"
fi

raw_archive_rel=""
raw_archive_sha="unavailable"
if [[ "${INCLUDE_RAW_ARCHIVE}" -eq 1 ]]; then
  raw_archive_rel="openclaw-${RUN_ID}-full-run.tar.gz"
  raw_archive_path="${OUTPUT_DIR}/${raw_archive_rel}"
  tar_items=()
  for rel in config raw derived artifacts; do
    if [[ -e "${RUN_DIR}/${rel}" ]]; then
      tar_items+=("${RUN_ID}/${rel}")
    fi
  done
  if [[ "${#tar_items[@]}" -eq 0 ]]; then
    echo "[openclaw-publish] no run content found for raw archive" >&2
    exit 1
  fi
  (
    cd "${REPO_ROOT}/runs/openclaw"
    tar --exclude="${RUN_ID}/artifacts/publish-pack" -czf "${raw_archive_path}" "${tar_items[@]}"
  )
  raw_archive_sha="$(file_sha256 "${raw_archive_path}")"
  printf '%s  %s\n' "${raw_archive_sha}" "${raw_archive_rel}" > "${raw_archive_path}.sha256"
fi

jq -n \
  --arg run_id "${RUN_ID}" \
  --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson include_raw_archive "${INCLUDE_RAW_ARCHIVE}" \
  --arg raw_archive_path "${raw_archive_rel}" \
  --arg raw_archive_sha256 "${raw_archive_sha}" \
  '{
    schema_version: "v2",
    report_id: "openclaw-2026",
    run_id: $run_id,
    generated_at: $generated_at,
    include_raw_archive: $include_raw_archive,
    raw_archive: (
      if $include_raw_archive then
        {path: $raw_archive_path, sha256: $raw_archive_sha256}
      else null
      end
    ),
    contents: [
      "research-pack/",
      "press-pack/",
      "research-pack/run-derived/ (if present)"
    ]
  }' > "${OUTPUT_DIR}/publish-manifest.json"

"${REPO_ROOT}/pipelines/common/hash_manifest.sh" \
  --input "${OUTPUT_DIR}" \
  --output "${OUTPUT_DIR}/bundle.sha256"

echo "[openclaw-publish] wrote ${OUTPUT_DIR}"
