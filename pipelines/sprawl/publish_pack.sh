#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  publish_pack.sh --run-id <id> [--output <dir>]

Assembles a publication bundle for the AI Tool Sprawl report.
EOF
}

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUN_ID=""
OUTPUT_DIR=""

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
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[sprawl-publish] unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "${RUN_ID}" ]]; then
  echo "[sprawl-publish] --run-id is required" >&2
  usage >&2
  exit 1
fi

if [[ -z "${OUTPUT_DIR}" ]]; then
  OUTPUT_DIR="${REPO_ROOT}/runs/tool-sprawl/${RUN_ID}/artifacts/publish-pack"
fi
mkdir -p "${OUTPUT_DIR}"
RUN_DIR="${REPO_ROOT}/runs/tool-sprawl/${RUN_ID}"
if [[ ! -d "${RUN_DIR}" ]]; then
  echo "[sprawl-publish] run directory not found: ${RUN_DIR}" >&2
  exit 1
fi

required_paths=(
  "reports/ai-tool-sprawl-q1-2026/definitions.md"
  "reports/ai-tool-sprawl-q1-2026/study-protocol.md"
  "reports/ai-tool-sprawl-q1-2026/methodology.md"
  "reports/ai-tool-sprawl-q1-2026/data"
  "claims/ai-tool-sprawl-q1-2026/claims.json"
  "citations/sprawl-regulatory-sources.md"
)

for rel in "${required_paths[@]}"; do
  if [[ ! -e "${REPO_ROOT}/${rel}" ]]; then
    echo "[sprawl-publish] missing required path: ${rel}" >&2
    exit 1
  fi
done

mkdir -p "${OUTPUT_DIR}/report-package"
cp -R "${REPO_ROOT}/reports/ai-tool-sprawl-q1-2026/." "${OUTPUT_DIR}/report-package/"
cp "${REPO_ROOT}/claims/ai-tool-sprawl-q1-2026/claims.json" "${OUTPUT_DIR}/claims.json"
cp "${REPO_ROOT}/citations/sprawl-regulatory-sources.md" "${OUTPUT_DIR}/regulatory-sources.md"

if [[ -f "${RUN_DIR}/artifacts/run-manifest.json" ]]; then
  cp "${RUN_DIR}/artifacts/run-manifest.json" "${OUTPUT_DIR}/run-manifest.json"
fi
if [[ -f "${RUN_DIR}/artifacts/manifest.sha256" ]]; then
  cp "${RUN_DIR}/artifacts/manifest.sha256" "${OUTPUT_DIR}/run-manifest.sha256"
fi
if [[ -f "${RUN_DIR}/agg/campaign-summary.json" ]]; then
  cp "${RUN_DIR}/agg/campaign-summary.json" "${OUTPUT_DIR}/campaign-summary.json"
fi
if [[ -f "${RUN_DIR}/appendix/combined-appendix.json" ]]; then
  cp "${RUN_DIR}/appendix/combined-appendix.json" "${OUTPUT_DIR}/combined-appendix.json"
fi

cat > "${OUTPUT_DIR}/publish-manifest.json" <<EOF
{
  "schema_version": "v1",
  "report_id": "ai-tool-sprawl-q1-2026",
  "run_id": "${RUN_ID}",
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "contents": [
    "report-package/",
    "claims.json",
    "regulatory-sources.md",
    "run-manifest.json (if present)",
    "run-manifest.sha256 (if present)",
    "campaign-summary.json (if present)",
    "combined-appendix.json (if present)"
  ]
}
EOF

"${REPO_ROOT}/pipelines/common/hash_manifest.sh" \
  --input "${OUTPUT_DIR}" \
  --output "${OUTPUT_DIR}/bundle.sha256"

echo "[sprawl-publish] wrote ${OUTPUT_DIR}"
