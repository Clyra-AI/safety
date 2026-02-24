#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  run.sh [--run-id <id>]

Creates immutable run layout for OpenClaw dual-lane execution:
  runs/openclaw/<run_id>/{config,raw,derived,artifacts}

This script currently prepares deterministic run scaffolding and snapshots config.
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
mkdir -p "${RUN_DIR}"/{config,raw,derived,artifacts}

cp -R "${REPO_ROOT}/reports/openclaw-2026/container-config/." "${RUN_DIR}/config/"

cat > "${RUN_DIR}/artifacts/run-manifest.json" <<EOF
{
  "schema_version": "v1",
  "report_id": "openclaw-2026",
  "run_id": "${RUN_ID}",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": "scaffolded",
  "notes": [
    "Populate raw and derived artifacts from isolated ungoverned and governed lanes.",
    "Use reports/openclaw-2026/study-protocol.md as execution contract."
  ]
}
EOF

echo "[openclaw-run] scaffolded ${RUN_DIR}"
echo "[openclaw-run] next: execute lane workloads and write outputs under raw/ and derived/"
