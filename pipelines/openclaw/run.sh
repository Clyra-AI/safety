#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  run.sh [--run-id <id>] [--resume] [--dry-run]

Creates immutable run layout for OpenClaw dual-lane execution:
  runs/openclaw/<run_id>/{config,raw,derived,artifacts}

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
      echo "[openclaw-run] unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "${RUN_ID}" ]]; then
  RUN_ID="openclaw-$(date -u +%Y%m%dT%H%M%SZ)"
fi

RUN_DIR="${REPO_ROOT}/runs/openclaw/${RUN_ID}"
MANIFEST_PATH="${RUN_DIR}/artifacts/run-manifest.json"

if [[ -d "${RUN_DIR}" && "${RESUME}" -eq 0 ]]; then
  echo "[openclaw-run] run directory already exists: ${RUN_DIR}" >&2
  echo "[openclaw-run] choose a new --run-id or use --resume to continue this run." >&2
  exit 1
fi

if [[ ! -d "${RUN_DIR}" && "${RESUME}" -eq 1 ]]; then
  echo "[openclaw-run] --resume requested but run directory does not exist: ${RUN_DIR}" >&2
  exit 1
fi

MODE="scaffold"
if [[ "${RESUME}" -eq 1 ]]; then
  MODE="resume"
fi

if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "[openclaw-run] dry-run mode"
  echo "[openclaw-run] run_id=${RUN_ID}"
  echo "[openclaw-run] mode=${MODE}"
  echo "[openclaw-run] run_dir=${RUN_DIR}"
  echo "[openclaw-run] actions:"
  echo "  - ensure directories: config, raw, derived, artifacts"
  if [[ "${MODE}" = "scaffold" ]]; then
    echo "  - copy container config into run config snapshot"
    echo "  - create run manifest at ${MANIFEST_PATH}"
  else
    echo "  - preserve existing config snapshot"
    echo "  - preserve existing run manifest if present"
  fi
  echo "[openclaw-run] no files written"
  exit 0
fi

mkdir -p "${RUN_DIR}"/{config,raw,derived,artifacts}

if [[ "${MODE}" = "scaffold" ]]; then
  cp -R "${REPO_ROOT}/reports/openclaw-2026/container-config/." "${RUN_DIR}/config/"
fi

if [[ ! -f "${MANIFEST_PATH}" ]]; then
  STATUS="scaffolded"
  if [[ "${MODE}" = "resume" ]]; then
    STATUS="resumed"
  fi
  cat > "${MANIFEST_PATH}" <<EOF
{
  "schema_version": "v1",
  "report_id": "openclaw-2026",
  "run_id": "${RUN_ID}",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": "${STATUS}",
  "notes": [
    "Populate raw and derived artifacts from isolated ungoverned and governed lanes.",
    "Use reports/openclaw-2026/study-protocol.md as execution contract."
  ]
}
EOF
else
  echo "[openclaw-run] preserving existing run manifest: ${MANIFEST_PATH}"
fi

if [[ "${MODE}" = "scaffold" ]]; then
  echo "[openclaw-run] scaffolded ${RUN_DIR}"
else
  echo "[openclaw-run] resumed ${RUN_DIR}"
fi
echo "[openclaw-run] next: execute lane workloads and write outputs under raw/ and derived/"
