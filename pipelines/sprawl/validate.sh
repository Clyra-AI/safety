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
  "pipelines/policies/regulatory-scope.v1.json"
  "pipelines/policies/regulatory-mappings.v1.yaml"
  "pipelines/config/publish-thresholds.json"
  "pipelines/config/calibration-thresholds.json"
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

compare_threshold() {
  local actual="$1"
  local op="$2"
  local expected="$3"
  awk -v a="${actual}" -v b="${expected}" -v op="${op}" '
    BEGIN {
      ok = 0
      if (op == ">=") ok = (a >= b)
      else if (op == "<=") ok = (a <= b)
      else if (op == ">") ok = (a > b)
      else if (op == "<") ok = (a < b)
      else if (op == "==") ok = (a == b)
      exit(ok ? 0 : 1)
    }'
}

calibration_metric_value() {
  local metric_id="$1"
  local eval_json="$2"
  local cov_json="$3"
  case "${metric_id}" in
    sprawl_non_source_recall_exists_pct)
      jq -r '.evaluations.non_source_exists.recall_exists // .binary_metrics.recall_exists // empty' "${eval_json}"
      ;;
    sprawl_non_source_precision_exists_pct)
      jq -r '.evaluations.non_source_exists.precision_exists // .binary_metrics.precision_exists // empty' "${eval_json}"
      ;;
    sprawl_destructive_tooling_recall_exists_pct)
      jq -r '.evaluations.destructive_tooling.recall_exists // empty' "${eval_json}"
      ;;
    sprawl_destructive_tooling_precision_exists_pct)
      jq -r '.evaluations.destructive_tooling.precision_exists // empty' "${eval_json}"
      ;;
    sprawl_destructive_tooling_labeled_rows)
      jq -r '.evaluations.destructive_tooling.rows // empty' "${eval_json}"
      ;;
    sprawl_approval_gate_absence_recall_exists_pct)
      jq -r '.evaluations.approval_gate_absence.recall_exists // empty' "${eval_json}"
      ;;
    sprawl_approval_gate_absence_precision_exists_pct)
      jq -r '.evaluations.approval_gate_absence.precision_exists // empty' "${eval_json}"
      ;;
    sprawl_approval_gate_absence_labeled_rows)
      jq -r '.evaluations.approval_gate_absence.rows // empty' "${eval_json}"
      ;;
    sprawl_unknown_exists_recall_exists_pct)
      jq -r '.evaluations.unknown_exists.recall_exists // empty' "${eval_json}"
      ;;
    sprawl_unknown_exists_precision_exists_pct)
      jq -r '.evaluations.unknown_exists.precision_exists // empty' "${eval_json}"
      ;;
    sprawl_unknown_exists_labeled_rows)
      jq -r '.evaluations.unknown_exists.rows // empty' "${eval_json}"
      ;;
    sprawl_targets_with_non_source_pct)
      jq -r '.observed.targets_with_non_source_pct // empty' "${cov_json}"
      ;;
    *)
      printf '%s\n' ""
      ;;
  esac
}

evaluate_calibration_scope() {
  local scope="$1"
  local calibration_cfg="$2"
  local calibration_eval="$3"
  local calibration_cov="$4"
  local metric_id
  local expected
  local op
  local actual

  while IFS= read -r metric_id; do
    [[ -z "${metric_id}" ]] && continue
    expected="$(jq -r --arg metric_id "${metric_id}" --arg scope "${scope}" '.reports["ai-tool-sprawl-q1-2026"][$scope][$metric_id].value // empty' "${calibration_cfg}")"
    op="$(jq -r --arg metric_id "${metric_id}" --arg scope "${scope}" '.reports["ai-tool-sprawl-q1-2026"][$scope][$metric_id].op // empty' "${calibration_cfg}")"
    if [[ -z "${expected}" || -z "${op}" ]]; then
      continue
    fi

    actual="$(calibration_metric_value "${metric_id}" "${calibration_eval}" "${calibration_cov}")"
    if [[ -z "${actual}" ]]; then
      if [[ "${scope}" == "required_calibration_thresholds" ]]; then
        echo "[sprawl-validate] missing required calibration metric: ${metric_id}" >&2
        if [[ "${STRICT}" -eq 1 ]]; then
          FAILURES=$((FAILURES + 1))
        fi
      else
        echo "[sprawl-validate] advisory: missing recommended calibration metric: ${metric_id}" >&2
      fi
      continue
    fi

    if ! compare_threshold "${actual}" "${op}" "${expected}"; then
      if [[ "${scope}" == "required_calibration_thresholds" ]]; then
        echo "[sprawl-validate] calibration required threshold failed: ${metric_id}=${actual} (${op} ${expected})" >&2
        if [[ "${STRICT}" -eq 1 ]]; then
          FAILURES=$((FAILURES + 1))
        fi
      else
        echo "[sprawl-validate] advisory: recommended calibration threshold missed: ${metric_id}=${actual} (${op} ${expected})" >&2
      fi
    fi
  done < <(jq -r --arg scope "${scope}" '.reports["ai-tool-sprawl-q1-2026"][$scope] | keys[]?' "${calibration_cfg}")
}

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

    calibration_cfg="${REPO_ROOT}/pipelines/config/calibration-thresholds.json"
    calibration_eval="${run_dir}/calibration/gold-label-evaluation.json"
    calibration_cov="${run_dir}/calibration/detector-coverage-summary.json"
    if [[ ! -f "${calibration_eval}" || ! -f "${calibration_cov}" ]]; then
      if [[ "${STRICT}" -eq 1 ]]; then
        echo "[sprawl-validate] strict mode requires calibration artifacts: ${calibration_eval} and ${calibration_cov}" >&2
        FAILURES=$((FAILURES + 1))
      else
        echo "[sprawl-validate] advisory: calibration artifacts missing for run ${RUN_ID}" >&2
      fi
    else
      evaluate_calibration_scope "required_calibration_thresholds" "${calibration_cfg}" "${calibration_eval}" "${calibration_cov}"
      evaluate_calibration_scope "recommended_calibration_thresholds" "${calibration_cfg}" "${calibration_eval}" "${calibration_cov}"
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
