#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  validate_v2.sh [--run-id <id>] [--lane test|full] [--strict]

Validates v2 sprawl report readiness:
  - v2 control files and citation log exist
  - v2 claim/threshold mapping coverage is complete
  - v2 claims ledger structure and query reproducibility
  - optional run artifact layout when --run-id is provided
  - calibration and publish gates are advisory in `test` lane and hard in `full --strict`
USAGE
}

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUN_ID="${RUN_ID:-}"
LANE="test"
STRICT=0
FAILURES=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)
      RUN_ID="${2:-}"
      shift 2
      ;;
    --lane)
      LANE="${2:-}"
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
      echo "[sprawl-validate-v2] unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ "${LANE}" != "test" && "${LANE}" != "full" ]]; then
  echo "[sprawl-validate-v2] --lane must be test or full" >&2
  exit 1
fi

required_files=(
  "internal/AI_TOOL_SPRAWL_V2_2026_REPORT_TEMPLATE.md"
  "reports/ai-tool-sprawl-v2-2026/definitions.md"
  "reports/ai-tool-sprawl-v2-2026/study-protocol.md"
  "reports/ai-tool-sprawl-v2-2026/methodology.md"
  "reports/ai-tool-sprawl-v2-2026/preregistration.md"
  "claims/ai-tool-sprawl-v2-2026/claims.json"
  "citations/sprawl-v2-regulatory-sources.md"
  "pipelines/config/publish-thresholds.json"
  "pipelines/config/calibration-thresholds.json"
  "pipelines/sprawl/generate_targets_v2.sh"
  "pipelines/sprawl/rebuild_from_scans_v2.sh"
  "pipelines/sprawl/calibrate_detectors_v2.sh"
  "pipelines/common/metric_coverage_gate.sh"
  "pipelines/common/derive_claim_values.sh"
  "pipelines/common/evaluate_claim_values.sh"
)

for rel in "${required_files[@]}"; do
  if [[ ! -f "${REPO_ROOT}/${rel}" ]]; then
    echo "[sprawl-validate-v2] missing required file: ${rel}" >&2
    FAILURES=$((FAILURES + 1))
  fi
done

if [[ "${FAILURES}" -gt 0 ]]; then
  echo "[sprawl-validate-v2] required-file failures=${FAILURES}" >&2
  exit 1
fi

if [[ "${STRICT}" -eq 1 && "${LANE}" == "full" ]]; then
  for rel in \
    "reports/ai-tool-sprawl-v2-2026/definitions.md" \
    "reports/ai-tool-sprawl-v2-2026/study-protocol.md" \
    "reports/ai-tool-sprawl-v2-2026/preregistration.md"
  do
    if grep -Eq '^Status: draft scaffold' "${REPO_ROOT}/${rel}"; then
      echo "[sprawl-validate-v2] strict full mode requires locked control docs; ${rel} is still draft" >&2
      FAILURES=$((FAILURES + 1))
    fi
    if grep -Eq '^Version: `v0`' "${REPO_ROOT}/${rel}"; then
      echo "[sprawl-validate-v2] strict full mode requires non-draft control doc versions; ${rel} is still v0" >&2
      FAILURES=$((FAILURES + 1))
    fi
  done
  if grep -Eq 'Locked by: `TBD`|Locked at \(UTC\): `TBD`|Notes: `TBD`' "${REPO_ROOT}/reports/ai-tool-sprawl-v2-2026/preregistration.md"; then
    echo "[sprawl-validate-v2] strict full mode requires a finalized v2 preregistration lock record" >&2
    FAILURES=$((FAILURES + 1))
  fi
fi

if [[ "${FAILURES}" -gt 0 ]]; then
  echo "[sprawl-validate-v2] control-doc failures=${FAILURES}" >&2
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
    sprawl_v2_non_source_recall_exists_pct)
      jq -r '.evaluations.non_source_exists.recall_exists // empty' "${eval_json}"
      ;;
    sprawl_v2_non_source_precision_exists_pct)
      jq -r '.evaluations.non_source_exists.precision_exists // empty' "${eval_json}"
      ;;
    sprawl_v2_agent_presence_recall_exists_pct)
      jq -r '.evaluations.agent_presence.recall_exists // empty' "${eval_json}"
      ;;
    sprawl_v2_agent_presence_precision_exists_pct)
      jq -r '.evaluations.agent_presence.precision_exists // empty' "${eval_json}"
      ;;
    sprawl_v2_agent_presence_labeled_rows)
      jq -r '.evaluations.agent_presence.rows // empty' "${eval_json}"
      ;;
    sprawl_v2_deployed_agents_recall_exists_pct)
      jq -r '.evaluations.deployed_agents.recall_exists // empty' "${eval_json}"
      ;;
    sprawl_v2_deployed_agents_precision_exists_pct)
      jq -r '.evaluations.deployed_agents.precision_exists // empty' "${eval_json}"
      ;;
    sprawl_v2_binding_incomplete_agents_recall_exists_pct)
      jq -r '.evaluations.binding_incomplete_agents.recall_exists // empty' "${eval_json}"
      ;;
    sprawl_v2_binding_incomplete_agents_precision_exists_pct)
      jq -r '.evaluations.binding_incomplete_agents.precision_exists // empty' "${eval_json}"
      ;;
    sprawl_v2_write_capable_agents_recall_exists_pct)
      jq -r '.evaluations.write_capable_agents.recall_exists // empty' "${eval_json}"
      ;;
    sprawl_v2_exec_capable_agents_recall_exists_pct)
      jq -r '.evaluations.exec_capable_agents.recall_exists // empty' "${eval_json}"
      ;;
    sprawl_v2_targets_with_agents_pct)
      jq -r '.observed.targets_with_agents_pct // empty' "${cov_json}"
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
  local metric_id expected op actual

  while IFS= read -r metric_id; do
    [[ -z "${metric_id}" ]] && continue
    expected="$(jq -r --arg metric_id "${metric_id}" --arg scope "${scope}" '.reports["ai-tool-sprawl-v2-2026"][$scope][$metric_id].value // empty' "${calibration_cfg}")"
    op="$(jq -r --arg metric_id "${metric_id}" --arg scope "${scope}" '.reports["ai-tool-sprawl-v2-2026"][$scope][$metric_id].op // empty' "${calibration_cfg}")"
    if [[ -z "${expected}" || -z "${op}" ]]; then
      continue
    fi

    actual="$(calibration_metric_value "${metric_id}" "${calibration_eval}" "${calibration_cov}")"
    if [[ -z "${actual}" ]]; then
      if [[ "${scope}" == "required_calibration_thresholds" ]]; then
        echo "[sprawl-validate-v2] missing required calibration metric: ${metric_id}" >&2
        if [[ "${STRICT}" -eq 1 && "${LANE}" == "full" ]]; then
          FAILURES=$((FAILURES + 1))
        fi
      else
        echo "[sprawl-validate-v2] advisory: missing recommended calibration metric: ${metric_id}" >&2
      fi
      continue
    fi

    if ! compare_threshold "${actual}" "${op}" "${expected}"; then
      if [[ "${scope}" == "required_calibration_thresholds" ]]; then
        echo "[sprawl-validate-v2] calibration required threshold failed: ${metric_id}=${actual} (${op} ${expected})" >&2
        if [[ "${STRICT}" -eq 1 && "${LANE}" == "full" ]]; then
          FAILURES=$((FAILURES + 1))
        fi
      else
        echo "[sprawl-validate-v2] advisory: recommended calibration threshold missed: ${metric_id}=${actual} (${op} ${expected})" >&2
      fi
    fi
  done < <(jq -r --arg scope "${scope}" '.reports["ai-tool-sprawl-v2-2026"][$scope] | keys[]?' "${calibration_cfg}")
}

coverage_args=(
  --report-id "ai-tool-sprawl-v2-2026"
  --claims "${REPO_ROOT}/claims/ai-tool-sprawl-v2-2026/claims.json"
  --thresholds "${REPO_ROOT}/pipelines/config/publish-thresholds.json"
)
if [[ "${STRICT}" -eq 1 && "${LANE}" == "full" ]]; then
  coverage_args+=(--strict)
fi
"${REPO_ROOT}/pipelines/common/metric_coverage_gate.sh" "${coverage_args[@]}"

claim_args=(
  --repo-root "${REPO_ROOT}"
  --claims "claims/ai-tool-sprawl-v2-2026/claims.json"
)
if [[ -n "${RUN_ID}" ]]; then
  claim_args+=(--run-id "${RUN_ID}")
fi
if [[ "${STRICT}" -eq 1 && "${LANE}" == "full" ]]; then
  claim_args+=(--strict)
fi
"${REPO_ROOT}/pipelines/common/claim_gates.sh" "${claim_args[@]}"

citation_args=(
  --citations "${REPO_ROOT}/citations/sprawl-v2-regulatory-sources.md"
)
if [[ "${STRICT}" -eq 1 && "${LANE}" == "full" ]]; then
  citation_args+=(--strict)
fi
"${REPO_ROOT}/pipelines/common/citation_gates.sh" "${citation_args[@]}"

if [[ -n "${RUN_ID}" ]]; then
  run_dir="${REPO_ROOT}/runs/tool-sprawl/${RUN_ID}"
  for dir in states scans agg appendix artifacts states-v2; do
    if [[ ! -d "${run_dir}/${dir}" ]]; then
      echo "[sprawl-validate-v2] missing run directory: runs/tool-sprawl/${RUN_ID}/${dir}" >&2
      FAILURES=$((FAILURES + 1))
    fi
  done

  if [[ -f "${run_dir}/agg/campaign-summary-v2.json" ]]; then
    if ! jq -e '
      (.report_id == "ai-tool-sprawl-v2-2026") and
      (.campaign.segmented_totals.source_repo_tools // null) != null and
      (.campaign.segmented_totals.tools_detected_raw // null) != null and
      (.campaign.totals.tools_detected // null) != null and
      (.campaign.segmented_totals.tools_detected_raw >= .campaign.totals.tools_detected) and
      ((.campaign.segmented_totals.tools_detected_raw - .campaign.totals.tools_detected) == .campaign.segmented_totals.source_repo_tools)
    ' "${run_dir}/agg/campaign-summary-v2.json" >/dev/null; then
      echo "[sprawl-validate-v2] v2 campaign summary segmentation check failed" >&2
      FAILURES=$((FAILURES + 1))
    fi
  else
    echo "[sprawl-validate-v2] missing v2 campaign summary: runs/tool-sprawl/${RUN_ID}/agg/campaign-summary-v2.json" >&2
    FAILURES=$((FAILURES + 1))
  fi

  if [[ -f "${run_dir}/artifacts/run-manifest-v2.json" && "${STRICT}" -eq 1 && "${LANE}" == "full" ]]; then
    if ! jq -e '(.cohort_purpose == "publication")' "${run_dir}/artifacts/run-manifest-v2.json" >/dev/null; then
      echo "[sprawl-validate-v2] strict full mode requires a publication cohort run" >&2
      FAILURES=$((FAILURES + 1))
    fi
    if jq -e '(.reproducibility.repository.ref // "" | test("dirty"))' "${run_dir}/artifacts/run-manifest-v2.json" >/dev/null; then
      echo "[sprawl-validate-v2] strict full mode requires a clean CAISI repository ref in v2 manifest" >&2
      FAILURES=$((FAILURES + 1))
    fi
    if ! jq -e '((.reproducibility.wrkr.tree_sha256 // "") | length) > 0 and (.reproducibility.wrkr.tree_sha256 != "unavailable")' "${run_dir}/artifacts/run-manifest-v2.json" >/dev/null; then
      echo "[sprawl-validate-v2] strict full mode requires a reproducible vendored wrkr tree digest in v2 manifest" >&2
      FAILURES=$((FAILURES + 1))
    fi
  fi

  for rel in \
    "appendix/combined-appendix-v2.json" \
    "appendix/tool-inventory.csv" \
    "appendix/agent-inventory.csv" \
    "appendix/agent-privilege-map.csv" \
    "appendix/attack-paths.csv" \
    "appendix/framework-rollups.csv" \
    "appendix/regulatory-gap-matrix-v2.csv" \
    "appendix/org-summary-v2.csv"
  do
    if [[ ! -f "${run_dir}/${rel}" ]]; then
      echo "[sprawl-validate-v2] missing v2 artifact: runs/tool-sprawl/${RUN_ID}/${rel}" >&2
      FAILURES=$((FAILURES + 1))
    fi
  done

  calibration_cfg="${REPO_ROOT}/pipelines/config/calibration-thresholds.json"
  calibration_eval="${run_dir}/calibration/gold-label-evaluation-v2.json"
  calibration_cov="${run_dir}/calibration/detector-coverage-summary-v2.json"
  if [[ ! -f "${calibration_eval}" || ! -f "${calibration_cov}" ]]; then
    if [[ "${STRICT}" -eq 1 && "${LANE}" == "full" ]]; then
      echo "[sprawl-validate-v2] full strict mode requires calibration artifacts: ${calibration_eval} and ${calibration_cov}" >&2
      FAILURES=$((FAILURES + 1))
    else
      if [[ -f "${calibration_cov}" ]]; then
        echo "[sprawl-validate-v2] advisory: calibration coverage exists but gold-label evaluation is missing for run ${RUN_ID}" >&2
      else
        echo "[sprawl-validate-v2] advisory: calibration artifacts missing for run ${RUN_ID}" >&2
      fi
    fi
  else
    evaluate_calibration_scope "required_calibration_thresholds" "${calibration_cfg}" "${calibration_eval}" "${calibration_cov}"
    evaluate_calibration_scope "recommended_calibration_thresholds" "${calibration_cfg}" "${calibration_eval}" "${calibration_cov}"
  fi

  derive_args=(
    --repo-root "${REPO_ROOT}"
    --claims "claims/ai-tool-sprawl-v2-2026/claims.json"
    --run-id "${RUN_ID}"
    --output "${run_dir}/artifacts/claim-values-v2.json"
  )
  if [[ "${STRICT}" -eq 1 && "${LANE}" == "full" ]]; then
    derive_args+=(--strict)
  fi
  "${REPO_ROOT}/pipelines/common/derive_claim_values.sh" "${derive_args[@]}"

  "${REPO_ROOT}/pipelines/common/evaluate_claim_values.sh" \
    --report-id "ai-tool-sprawl-v2-2026" \
    --claim-values "${run_dir}/artifacts/claim-values-v2.json" \
    --thresholds "${REPO_ROOT}/pipelines/config/publish-thresholds.json" \
    --repo-root "${REPO_ROOT}" \
    --output "${run_dir}/artifacts/threshold-evaluation-v2.json"

  if [[ -f "${run_dir}/artifacts/run-manifest-v2.json" && "${STRICT}" -eq 1 && "${LANE}" == "full" ]]; then
    if jq -e '(.reproducibility.wrkr.runtime // "" | test("external:"))' "${run_dir}/artifacts/run-manifest-v2.json" >/dev/null; then
      echo "[sprawl-validate-v2] strict full mode disallows external/local wrkr runtime refs in v2 manifest" >&2
      FAILURES=$((FAILURES + 1))
    fi
  fi
fi

echo "[sprawl-validate-v2] lane=${LANE} strict=${STRICT} failures=${FAILURES}"
if [[ "${FAILURES}" -gt 0 ]]; then
  exit 1
fi
