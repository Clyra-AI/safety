#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  run.sh [--run-id <id>]

Creates immutable run layout for Wrkr campaign execution:
  runs/tool-sprawl/<run_id>/{states,states-enrich,scans,agg,appendix,artifacts}

This script currently prepares deterministic run scaffolding and a run manifest.
EOF
}

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUN_ID="${RUN_ID:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)
      RUN_ID="${2:-}"
      shift 2
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
mkdir -p "${RUN_DIR}"/{states,states-enrich,scans,agg,appendix,artifacts}

cat > "${RUN_DIR}/artifacts/run-manifest.json" <<EOF
{
  "schema_version": "v1",
  "report_id": "ai-tool-sprawl-q1-2026",
  "run_id": "${RUN_ID}",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": "scaffolded",
  "notes": [
    "Populate scans and aggregate outputs using Wrkr campaign workflow.",
    "Use reports/ai-tool-sprawl-q1-2026/study-protocol.md as execution contract."
  ]
}
EOF

echo "[sprawl-run] scaffolded ${RUN_DIR}"
echo "[sprawl-run] next: run campaign scans and write outputs under scans/, agg/, and appendix/"
