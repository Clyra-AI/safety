#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  validate.sh [--run-id <id>] [--strict]

Validates sprawl report readiness:
  - required report protocol/definition files exist
  - preregistration and citation controls exist
  - claim/threshold mapping coverage is complete
  - claims ledger structure and query reproducibility
  - citation gate (TBD markers fail in strict mode)
  - optional run artifact layout when --run-id is provided
  - headline threshold gate when run claims are finalized
  - deterministic SHA-256 manifest generation for run artifacts
USAGE
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
      echo "[sprawl-validate] unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

required_files=(
  "internal/AI_TOOL_SPRAWL_Q1_2026_REPORT_TEMPLATE.md"
  "reports/ai-tool-sprawl-q1-2026/definitions.md"
  "reports/ai-tool-sprawl-q1-2026/study-protocol.md"
  "reports/ai-tool-sprawl-q1-2026/methodology.md"
  "reports/ai-tool-sprawl-q1-2026/preregistration.md"
  "claims/ai-tool-sprawl-q1-2026/claims.json"
  "citations/sprawl-regulatory-sources.md"
  "pipelines/config/publish-thresholds.json"
  "pipelines/common/metric_coverage_gate.sh"
  "pipelines/common/derive_claim_values.sh"
)

for rel in "${required_files[@]}"; do
  if [[ ! -f "${REPO_ROOT}/${rel}" ]]; then
    echo "[sprawl-validate] missing required file: ${rel}" >&2
    FAILURES=$((FAILURES + 1))
  fi
done

if [[ "${FAILURES}" -gt 0 ]]; then
  echo "[sprawl-validate] required-file failures=${FAILURES}" >&2
  exit 1
fi

coverage_args=(
  --report-id "ai-tool-sprawl-q1-2026"
  --claims "${REPO_ROOT}/claims/ai-tool-sprawl-q1-2026/claims.json"
  --thresholds "${REPO_ROOT}/pipelines/config/publish-thresholds.json"
)
if [[ "${STRICT}" -eq 1 ]]; then
  coverage_args+=(--strict)
fi
"${REPO_ROOT}/pipelines/common/metric_coverage_gate.sh" "${coverage_args[@]}"

claim_args=(
  --repo-root "${REPO_ROOT}"
  --claims "claims/ai-tool-sprawl-q1-2026/claims.json"
)
if [[ -n "${RUN_ID}" ]]; then
  claim_args+=(--run-id "${RUN_ID}")
fi
if [[ "${STRICT}" -eq 1 ]]; then
  claim_args+=(--strict)
fi
"${REPO_ROOT}/pipelines/common/claim_gates.sh" "${claim_args[@]}"

citation_args=(
  --citations "${REPO_ROOT}/citations/sprawl-regulatory-sources.md"
)
if [[ "${STRICT}" -eq 1 ]]; then
  citation_args+=(--strict)
fi
"${REPO_ROOT}/pipelines/common/citation_gates.sh" "${citation_args[@]}"

if [[ -n "${RUN_ID}" ]]; then
  run_dir="${REPO_ROOT}/runs/tool-sprawl/${RUN_ID}"
  for dir in states states-enrich scans agg appendix artifacts; do
    if [[ ! -d "${run_dir}/${dir}" ]]; then
      echo "[sprawl-validate] missing run directory: runs/tool-sprawl/${RUN_ID}/${dir}" >&2
      FAILURES=$((FAILURES + 1))
    fi
  done

  if [[ -d "${run_dir}" ]]; then
    derive_args=(
      --repo-root "${REPO_ROOT}"
      --claims "claims/ai-tool-sprawl-q1-2026/claims.json"
      --run-id "${RUN_ID}"
      --output "${run_dir}/artifacts/claim-values.json"
    )
    if [[ "${STRICT}" -eq 1 ]]; then
      derive_args+=(--strict)
    fi
    "${REPO_ROOT}/pipelines/common/derive_claim_values.sh" "${derive_args[@]}"

    mkdir -p "${run_dir}/artifacts"
    "${REPO_ROOT}/pipelines/common/hash_manifest.sh" \
      --input "${run_dir}" \
      --output "${run_dir}/artifacts/manifest.sha256"
  fi

  threshold_args=(
    --report-id "ai-tool-sprawl-q1-2026"
    --claims "${REPO_ROOT}/claims/ai-tool-sprawl-q1-2026/claims.json"
    --thresholds "${REPO_ROOT}/pipelines/config/publish-thresholds.json"
  )
  if jq -e '.claims[] | select((.value | type) == "string" and .value == "TBD")' \
    "${REPO_ROOT}/claims/ai-tool-sprawl-q1-2026/claims.json" >/dev/null; then
    if [[ "${STRICT}" -eq 1 ]]; then
      threshold_args+=(--strict)
      "${REPO_ROOT}/pipelines/common/threshold_gate.sh" "${threshold_args[@]}"
    else
      echo "[sprawl-validate] threshold gate skipped (claims not finalized)." >&2
    fi
  else
    if [[ "${STRICT}" -eq 1 ]]; then
      threshold_args+=(--strict)
    fi
    "${REPO_ROOT}/pipelines/common/threshold_gate.sh" "${threshold_args[@]}"
  fi
fi

if [[ "${FAILURES}" -gt 0 ]]; then
  echo "[sprawl-validate] failures=${FAILURES}" >&2
  exit 1
fi

echo "[sprawl-validate] ok"
