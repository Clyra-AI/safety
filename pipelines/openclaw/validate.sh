#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  validate.sh [--run-id <id>] [--strict]

Validates OpenClaw report readiness:
  - required report protocol/definition files exist
  - claims ledger structure and query reproducibility
  - optional run artifact layout when --run-id is provided
  - headline threshold gate when run claims are finalized
  - deterministic SHA-256 manifest generation for run artifacts
EOF
}

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUN_ID="${RUN_ID:-}"
STRICT=0
FAILURES=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)
      RUN_ID="${2:-}"
      shift 2
      ;;
    --strict)
      STRICT=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[openclaw-validate] unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

required_files=(
  "internal/OPENCLAW_REPORT_TEMPLATE.md"
  "reports/openclaw-2026/definitions.md"
  "reports/openclaw-2026/study-protocol.md"
  "reports/openclaw-2026/methodology.md"
  "claims/openclaw-2026/claims.json"
  "pipelines/config/publish-thresholds.json"
)

for rel in "${required_files[@]}"; do
  if [[ ! -f "${REPO_ROOT}/${rel}" ]]; then
    echo "[openclaw-validate] missing required file: ${rel}" >&2
    FAILURES=$((FAILURES + 1))
  fi
done

if [[ "${FAILURES}" -gt 0 ]]; then
  echo "[openclaw-validate] required-file failures=${FAILURES}" >&2
  exit 1
fi

claim_args=(
  --repo-root "${REPO_ROOT}"
  --claims "claims/openclaw-2026/claims.json"
)
if [[ -n "${RUN_ID}" ]]; then
  claim_args+=(--run-id "${RUN_ID}")
fi
if [[ "${STRICT}" -eq 1 ]]; then
  claim_args+=(--strict)
fi
"${REPO_ROOT}/pipelines/common/claim_gates.sh" "${claim_args[@]}"

if [[ -n "${RUN_ID}" ]]; then
  run_dir="${REPO_ROOT}/runs/openclaw/${RUN_ID}"
  for dir in config raw derived artifacts; do
    if [[ ! -d "${run_dir}/${dir}" ]]; then
      echo "[openclaw-validate] missing run directory: runs/openclaw/${RUN_ID}/${dir}" >&2
      FAILURES=$((FAILURES + 1))
    fi
  done

  threshold_args=(
    --report-id "openclaw-2026"
    --claims "${REPO_ROOT}/claims/openclaw-2026/claims.json"
    --thresholds "${REPO_ROOT}/pipelines/config/publish-thresholds.json"
  )
  if jq -e '.claims[] | select((.value | type) == "string" and .value == "TBD")' \
    "${REPO_ROOT}/claims/openclaw-2026/claims.json" >/dev/null; then
    if [[ "${STRICT}" -eq 1 ]]; then
      threshold_args+=(--strict)
      "${REPO_ROOT}/pipelines/common/threshold_gate.sh" "${threshold_args[@]}"
    else
      echo "[openclaw-validate] threshold gate skipped (claims not finalized)." >&2
    fi
  else
    if [[ "${STRICT}" -eq 1 ]]; then
      threshold_args+=(--strict)
    fi
    "${REPO_ROOT}/pipelines/common/threshold_gate.sh" "${threshold_args[@]}"
  fi

  if [[ -d "${run_dir}" ]]; then
    mkdir -p "${run_dir}/artifacts"
    "${REPO_ROOT}/pipelines/common/hash_manifest.sh" \
      --input "${run_dir}" \
      --output "${run_dir}/artifacts/manifest.sha256"
  fi
fi

if [[ "${FAILURES}" -gt 0 ]]; then
  echo "[openclaw-validate] failures=${FAILURES}" >&2
  exit 1
fi

echo "[openclaw-validate] ok"
