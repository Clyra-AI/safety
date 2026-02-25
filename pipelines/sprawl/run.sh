#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  run.sh [--run-id <id>] [--resume] [--dry-run]

Creates immutable run layout for Wrkr campaign execution:
  runs/tool-sprawl/<run_id>/{states,states-enrich,scans,agg,appendix,artifacts}

Defaults:
  - If --run-id is omitted, a timestamped run ID is generated.
  - Existing run IDs fail fast unless --resume is provided.
  - --dry-run performs no writes and only prints planned actions.
EOF
}

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUN_ID="${RUN_ID:-}"
RESUME=0
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)
      RUN_ID="${2:-}"
      shift 2
      ;;
    --resume)
      RESUME=1
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
      echo "[sprawl-run] unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "${RUN_ID}" ]]; then
  RUN_ID="sprawl-$(date -u +%Y%m%dT%H%M%SZ)"
fi

RUN_DIR="${REPO_ROOT}/runs/tool-sprawl/${RUN_ID}"
MANIFEST_PATH="${RUN_DIR}/artifacts/run-manifest.json"

if [[ -d "${RUN_DIR}" && "${RESUME}" -eq 0 ]]; then
  echo "[sprawl-run] run directory already exists: ${RUN_DIR}" >&2
  echo "[sprawl-run] choose a new --run-id or use --resume to continue this run." >&2
  exit 1
fi

if [[ ! -d "${RUN_DIR}" && "${RESUME}" -eq 1 ]]; then
  echo "[sprawl-run] --resume requested but run directory does not exist: ${RUN_DIR}" >&2
  exit 1
fi

MODE="scaffold"
if [[ "${RESUME}" -eq 1 ]]; then
  MODE="resume"
fi

if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "[sprawl-run] dry-run mode"
  echo "[sprawl-run] run_id=${RUN_ID}"
  echo "[sprawl-run] mode=${MODE}"
  echo "[sprawl-run] run_dir=${RUN_DIR}"
  echo "[sprawl-run] actions:"
  echo "  - ensure directories: states, states-enrich, scans, agg, appendix, artifacts"
  if [[ "${MODE}" = "scaffold" ]]; then
    echo "  - create run manifest at ${MANIFEST_PATH}"
  else
    echo "  - preserve existing run manifest if present"
  fi
  echo "[sprawl-run] no files written"
  exit 0
fi

mkdir -p "${RUN_DIR}"/{states,states-enrich,scans,agg,appendix,artifacts}

if [[ ! -f "${MANIFEST_PATH}" ]]; then
  STATUS="scaffolded"
  if [[ "${MODE}" = "resume" ]]; then
    STATUS="resumed"
  fi
  cat > "${MANIFEST_PATH}" <<EOF
{
  "schema_version": "v1",
  "report_id": "ai-tool-sprawl-q1-2026",
  "run_id": "${RUN_ID}",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": "${STATUS}",
  "notes": [
    "Populate scans and aggregate outputs using Wrkr campaign workflow.",
    "Use reports/ai-tool-sprawl-q1-2026/study-protocol.md as execution contract."
  ]
}
EOF
else
  echo "[sprawl-run] preserving existing run manifest: ${MANIFEST_PATH}"
fi

if [[ "${MODE}" = "scaffold" ]]; then
  echo "[sprawl-run] scaffolded ${RUN_DIR}"
else
  echo "[sprawl-run] resumed ${RUN_DIR}"
fi
echo "[sprawl-run] next: run campaign scans and write outputs under scans/, agg/, and appendix/"
