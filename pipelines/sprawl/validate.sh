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
  for opt_dir in wrkr-state wrkr-state-enrich; do
    if [[ ! -d "${run_dir}/${opt_dir}" ]]; then
      echo "[sprawl-validate] advisory: optional run directory not present (legacy run layout): runs/tool-sprawl/${RUN_ID}/${opt_dir}" >&2
    fi
  done

  if [[ -d "${run_dir}" ]]; then
    scan_count=0
    while IFS= read -r scan_file; do
      scan_count=$((scan_count + 1))
      if [[ ! -s "${scan_file}" ]] || ! jq -e . "${scan_file}" >/dev/null 2>&1; then
        echo "[sprawl-validate] invalid or empty scan artifact: ${scan_file}" >&2
        FAILURES=$((FAILURES + 1))
      fi
    done < <(find "${run_dir}/scans" -type f -name '*.scan.json' | sort)

    if [[ "${scan_count}" -eq 0 ]]; then
      echo "[sprawl-validate] no scan artifacts found under runs/tool-sprawl/${RUN_ID}/scans" >&2
      FAILURES=$((FAILURES + 1))
    fi

    if [[ -f "${run_dir}/agg/campaign-summary.json" ]]; then
      if ! jq -e '
        (.campaign.segmented_totals.source_repo_tools // null) != null and
        (.campaign.segmented_totals.tools_detected_raw // null) != null and
        (.campaign.totals.tools_detected // null) != null and
        (.campaign.segmented_totals.tools_detected_raw >= .campaign.totals.tools_detected) and
        ((.campaign.segmented_totals.tools_detected_raw - .campaign.totals.tools_detected) == .campaign.segmented_totals.source_repo_tools)
      ' "${run_dir}/agg/campaign-summary.json" >/dev/null; then
        echo "[sprawl-validate] campaign summary segmentation check failed (source_repo scope mismatch)" >&2
        FAILURES=$((FAILURES + 1))
      fi
    fi

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
    hash_args=(
      --input "${run_dir}"
      --output "${run_dir}/artifacts/manifest.sha256"
    )
    if [[ -f "${run_dir}/artifacts/run-manifest.json" ]]; then
      if jq -e '.mode == "scaffold"' "${run_dir}/artifacts/run-manifest.json" >/dev/null; then
        echo "[sprawl-validate] run manifest mode must not be scaffold for completed runs" >&2
        FAILURES=$((FAILURES + 1))
      fi
      if [[ "${STRICT}" -eq 1 ]]; then
        if jq -e '
          (.reproducibility.wrkr.runtime // "" | test("external:"))
        ' "${run_dir}/artifacts/run-manifest.json" >/dev/null; then
          echo "[sprawl-validate] strict mode disallows external/local wrkr runtime refs in run-manifest" >&2
          FAILURES=$((FAILURES + 1))
        fi
      fi
      scan_source="$(jq -r '.reproducibility.wrkr.scan_source // empty' "${run_dir}/artifacts/run-manifest.json" 2>/dev/null || true)"
      if [[ "${scan_source}" == "clone" ]]; then
        hash_args+=(--exclude-prefix "sources/")
      fi
    fi
    "${REPO_ROOT}/pipelines/common/hash_manifest.sh" "${hash_args[@]}"

    if [[ -f "${run_dir}/artifacts/claim-values.json" ]]; then
      claims_path="$(jq -r '.claims_file // empty' "${run_dir}/artifacts/claim-values.json" 2>/dev/null || true)"
      if [[ "${claims_path}" == /* ]]; then
        echo "[sprawl-validate] claim-values artifact contains absolute claims_file path" >&2
        FAILURES=$((FAILURES + 1))
      fi
    fi
    if [[ -f "${run_dir}/artifacts/threshold-evaluation.json" ]]; then
      thresholds_path="$(jq -r '.thresholds_path // empty' "${run_dir}/artifacts/threshold-evaluation.json" 2>/dev/null || true)"
      if [[ "${thresholds_path}" == /* ]]; then
        echo "[sprawl-validate] threshold-evaluation artifact contains absolute thresholds_path" >&2
        FAILURES=$((FAILURES + 1))
      fi
    fi
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

if [[ "${STRICT}" -eq 1 ]] && command -v git >/dev/null 2>&1; then
  tracked_sprawl_runs="$(git -C "${REPO_ROOT}" ls-files 'runs/tool-sprawl/sprawl-*' 2>/dev/null | grep -v '^runs/tool-sprawl/.gitkeep$' || true)"
  if [[ -n "${tracked_sprawl_runs}" ]]; then
    echo "[sprawl-validate] strict mode disallows tracked files under runs/tool-sprawl/sprawl-*; keep sprawl run dirs local-only" >&2
    FAILURES=$((FAILURES + 1))
  fi
fi

if [[ "${FAILURES}" -gt 0 ]]; then
  echo "[sprawl-validate] failures=${FAILURES}" >&2
  exit 1
fi

echo "[sprawl-validate] ok"
