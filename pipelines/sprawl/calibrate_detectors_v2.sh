#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  calibrate_detectors_v2.sh --run-id <id> [--out-dir <path>] [--gold-labels <path>] [--strict]

Builds v2 detector calibration artifacts from a completed sprawl run:
  - observed-by-target-v2.csv
  - observed-agents-v2.csv
  - gold-labels-v2.template.json
  - detector-coverage-summary-v2.json
  - gold-label-validation-v2.json (when --gold-labels is provided)
  - gold-label-evaluation-v2.json (when --gold-labels is provided)
USAGE
}

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUN_ID=""
OUT_DIR=""
GOLD_LABELS=""
STRICT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)
      RUN_ID="${2:-}"
      shift 2
      ;;
    --out-dir)
      OUT_DIR="${2:-}"
      shift 2
      ;;
    --gold-labels)
      GOLD_LABELS="${2:-}"
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
      echo "[sprawl-calibrate-v2] unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "${RUN_ID}" ]]; then
  echo "[sprawl-calibrate-v2] --run-id is required" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "[sprawl-calibrate-v2] jq is required" >&2
  exit 1
fi

RUN_DIR="${REPO_ROOT}/runs/tool-sprawl/${RUN_ID}"
STATES_DIR="${RUN_DIR}/states-v2"
SUMMARY_PATH="${RUN_DIR}/agg/campaign-summary-v2.json"

if [[ ! -d "${STATES_DIR}" || ! -f "${SUMMARY_PATH}" ]]; then
  echo "[sprawl-calibrate-v2] missing v2 run artifacts under ${RUN_DIR}" >&2
  exit 1
fi

if [[ -z "${OUT_DIR}" ]]; then
  OUT_DIR="${RUN_DIR}/calibration"
fi
if [[ "${OUT_DIR}" != /* ]]; then
  OUT_DIR="${REPO_ROOT}/${OUT_DIR}"
fi
mkdir -p "${OUT_DIR}"

OBSERVED_TARGETS_CSV="${OUT_DIR}/observed-by-target-v2.csv"
OBSERVED_AGENTS_CSV="${OUT_DIR}/observed-agents-v2.csv"
GOLD_TEMPLATE_JSON="${OUT_DIR}/gold-labels-v2.template.json"
COVERAGE_SUMMARY_JSON="${OUT_DIR}/detector-coverage-summary-v2.json"
GOLD_VALIDATION_JSON="${OUT_DIR}/gold-label-validation-v2.json"
GOLD_EVAL_JSON="${OUT_DIR}/gold-label-evaluation-v2.json"

{
  echo 'target,observed_non_source_tools,observed_declared_agents,observed_deployed_agents,observed_binding_incomplete_agents,observed_write_capable_agents,observed_exec_capable_agents,observed_agent_attack_paths,observed_evidence_verifiable,source'
  find "${STATES_DIR}" -type f -name '*.json' | sort | while IFS= read -r state; do
    jq -r '[
      .target,
      (.counts.tools_detected // 0),
      (.counts.declared_agents // 0),
      (.counts.deployed_agents // 0),
      (.counts.binding_incomplete_agents // 0),
      (.counts.write_capable_agents // 0),
      (.counts.exec_capable_agents // 0),
      (.counts.agent_linked_attack_paths // 0),
      (.control_posture.evidence_verifiable // false),
      (.scan_path // "unknown")
    ] | @csv' "${state}"
  done
} > "${OBSERVED_TARGETS_CSV}"

{
  echo 'target,observed_declared_agents,observed_deployed_agents,observed_binding_incomplete_agents,observed_write_capable_agents,observed_exec_capable_agents,observed_agent_attack_paths,source'
  find "${STATES_DIR}" -type f -name '*.json' | sort | while IFS= read -r state; do
    jq -r '[
      .target,
      (.counts.declared_agents // 0),
      (.counts.deployed_agents // 0),
      (.counts.binding_incomplete_agents // 0),
      (.counts.write_capable_agents // 0),
      (.counts.exec_capable_agents // 0),
      (.counts.agent_linked_attack_paths // 0),
      (.scan_path // "unknown")
    ] | @csv' "${state}"
  done
} > "${OBSERVED_AGENTS_CSV}"

jq -n \
  --slurpfile states <(find "${STATES_DIR}" -type f -name '*.json' | sort | xargs -I{} jq -c '.' "{}") \
  '
  ($states // []) as $rows |
  $rows
  | map({
      target,
      observed_non_source_tools: (.counts.tools_detected // 0),
      observed_declared_agents: (.counts.declared_agents // 0),
      observed_deployed_agents: (.counts.deployed_agents // 0),
      observed_binding_incomplete_agents: (.counts.binding_incomplete_agents // 0),
      observed_write_capable_agents: (.counts.write_capable_agents // 0),
      observed_exec_capable_agents: (.counts.exec_capable_agents // 0),
      observed_agent_attack_paths: (.counts.agent_linked_attack_paths // 0),
      expected_non_source_exists: null,
      expected_non_source_count: null,
      expected_agents_exist: null,
      expected_agents_count: null,
      expected_deployed_agents_exist: null,
      expected_deployed_agents_count: null,
      expected_binding_incomplete_agents_exist: null,
      expected_binding_incomplete_agents_count: null,
      expected_write_capable_agents_exist: null,
      expected_exec_capable_agents_exist: null,
      expected_agent_attack_paths_exist: null,
      reviewer: null,
      notes: null
    })
  ' > "${GOLD_TEMPLATE_JSON}"

jq -n \
  --arg run_id "${RUN_ID}" \
  --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --slurpfile summary "${SUMMARY_PATH}" \
  --slurpfile states <(find "${STATES_DIR}" -type f -name '*.json' | sort | xargs -I{} jq -c '.' "{}") \
  '
  ($states // []) as $rows |
  ($rows | length) as $targets_total |
  ($rows | map(select((.counts.tools_detected // 0) > 0)) | length) as $targets_with_non_source |
  ($rows | map(select((.counts.declared_agents // 0) > 0)) | length) as $targets_with_agents |
  ($rows | map(select((.counts.deployed_agents // 0) > 0)) | length) as $targets_with_deployed_agents |
  ($rows | map(select((.counts.binding_incomplete_agents // 0) > 0)) | length) as $targets_with_binding_gaps |
  ($rows | map(select((.counts.write_capable_agents // 0) > 0)) | length) as $targets_with_write_agents |
  ($rows | map(select((.counts.exec_capable_agents // 0) > 0)) | length) as $targets_with_exec_agents |
  ($rows | map(select((.counts.agent_linked_attack_paths // 0) > 0)) | length) as $targets_with_agent_attack_paths |
  ($rows | map(.counts.declared_agents // 0) | add) as $declared_agents_total |
  {
    schema_version: "v2",
    run_id: $run_id,
    generated_at: $generated_at,
    observed: {
      targets_total: $targets_total,
      targets_with_non_source: $targets_with_non_source,
      targets_with_non_source_pct: (if $targets_total == 0 then 0 else ((10000 * $targets_with_non_source / $targets_total) | round / 100) end),
      targets_with_agents: $targets_with_agents,
      targets_with_agents_pct: (if $targets_total == 0 then 0 else ((10000 * $targets_with_agents / $targets_total) | round / 100) end),
      targets_with_deployed_agents: $targets_with_deployed_agents,
      targets_with_deployed_agents_pct: (if $targets_total == 0 then 0 else ((10000 * $targets_with_deployed_agents / $targets_total) | round / 100) end),
      targets_with_binding_gaps: $targets_with_binding_gaps,
      targets_with_write_agents: $targets_with_write_agents,
      targets_with_exec_agents: $targets_with_exec_agents,
      targets_with_agent_attack_paths: $targets_with_agent_attack_paths,
      declared_agents_total: $declared_agents_total,
      avg_agents_per_target: (if $targets_total == 0 then 0 else ((100 * $declared_agents_total / $targets_total) | round / 100) end)
    },
    campaign_metrics_snapshot: (($summary[0].campaign.metrics) // {})
  }
  ' > "${COVERAGE_SUMMARY_JSON}"

if [[ -n "${GOLD_LABELS}" ]]; then
  GOLD_LABELS_PATH="${GOLD_LABELS}"
  if [[ "${GOLD_LABELS_PATH}" != /* ]]; then
    GOLD_LABELS_PATH="${REPO_ROOT}/${GOLD_LABELS_PATH}"
  fi
  if [[ ! -f "${GOLD_LABELS_PATH}" ]]; then
    echo "[sprawl-calibrate-v2] gold labels file not found: ${GOLD_LABELS_PATH}" >&2
    exit 1
  fi
  if ! jq -e 'type == "array"' "${GOLD_LABELS_PATH}" >/dev/null 2>&1; then
    echo "[sprawl-calibrate-v2] gold labels must be a JSON array: ${GOLD_LABELS_PATH}" >&2
    exit 1
  fi

  jq -n \
    --arg run_id "${RUN_ID}" \
    --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --slurpfile labels "${GOLD_LABELS_PATH}" \
    --slurpfile states <(find "${STATES_DIR}" -type f -name '*.json' | sort | xargs -I{} jq -c '.' "{}") \
    '
    def has_expectation($row):
      [
        $row.expected_non_source_exists,
        $row.expected_non_source_count,
        $row.expected_agents_exist,
        $row.expected_agents_count,
        $row.expected_deployed_agents_exist,
        $row.expected_deployed_agents_count,
        $row.expected_binding_incomplete_agents_exist,
        $row.expected_binding_incomplete_agents_count,
        $row.expected_write_capable_agents_exist,
        $row.expected_exec_capable_agents_exist,
        $row.expected_agent_attack_paths_exist
      ] | map(. != null) | any;

    def label_row_ref($entry):
      (($entry.key + 1) | tostring) + ":" + (($entry.value.target // "") | tostring);

    (($labels[0] // []) as $label_rows |
      [($states // [])[] | .target] as $state_targets |
      [($label_rows | to_entries[]) | select(((.value.target // "") | length) == 0) | (.key + 1)] as $rows_missing_target |
      ([ $label_rows[] | (.target // "") ] | group_by(.) | map(select(length > 1 and .[0] != "") | .[0])) as $duplicate_targets |
      ($label_rows | map(
        (.target // "") as $target
        | select(($target | length) > 0 and ($state_targets | index($target) == null))
        | $target
      )) as $unmatched_targets |
      ($label_rows | to_entries | map(select((((.value.reviewer // "") | tostring | gsub("^\\s+|\\s+$"; "")) | length) == 0) | label_row_ref(.))) as $rows_missing_reviewer |
      ($label_rows | to_entries | map(select(has_expectation(.value) | not) | label_row_ref(.))) as $rows_without_expectations |
      {
        schema_version: "v2",
        run_id: $run_id,
        generated_at: $generated_at,
        validation: {
          rows_supplied: ($label_rows | length),
          rows_missing_target: $rows_missing_target,
          rows_missing_target_count: ($rows_missing_target | length),
          matched_targets_count: ($label_rows | map(
            (.target // "") as $target
            | select(($target | length) > 0 and ($state_targets | index($target) != null))
          ) | length),
          duplicate_targets: $duplicate_targets,
          duplicate_targets_count: ($duplicate_targets | length),
          unmatched_targets: $unmatched_targets,
          unmatched_targets_count: ($unmatched_targets | length),
          rows_missing_reviewer: $rows_missing_reviewer,
          rows_missing_reviewer_count: ($rows_missing_reviewer | length),
          rows_without_expectations: $rows_without_expectations,
          rows_without_expectations_count: ($rows_without_expectations | length)
        }
      })' > "${GOLD_VALIDATION_JSON}"

  jq -n \
    --arg run_id "${RUN_ID}" \
    --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --slurpfile labels "${GOLD_LABELS_PATH}" \
    --slurpfile validation "${GOLD_VALIDATION_JSON}" \
    --slurpfile states <(find "${STATES_DIR}" -type f -name '*.json' | sort | xargs -I{} jq -c '.' "{}") \
    '
    def ratio(n; d):
      if d == 0 then null else ((10000 * n / d) | round / 100) end;

    def binary_eval($rows; $expected_key; $pred_key):
      ($rows | map(select((.[ $expected_key ] | type) == "boolean"))) as $b |
      ($b | map(select(.[ $expected_key ] == true and .[ $pred_key ] == true)) | length) as $tp |
      ($b | map(select(.[ $expected_key ] == true and .[ $pred_key ] == false)) | length) as $fn |
      ($b | map(select(.[ $expected_key ] == false and .[ $pred_key ] == true)) | length) as $fp |
      ($b | map(select(.[ $expected_key ] == false and .[ $pred_key ] == false)) | length) as $tn |
      {
        rows: ($b | length),
        true_positive: $tp,
        false_negative: $fn,
        false_positive: $fp,
        true_negative: $tn,
        recall_exists: ratio($tp; ($tp + $fn)),
        precision_exists: ratio($tp; ($tp + $fp))
      };

    def count_eval($rows; $expected_key; $observed_key):
      ($rows | map(select((.[ $expected_key ] | type) == "number" and .[ $expected_key ] >= 0))) as $c |
      ($c | map(.[ $expected_key ]) | add // 0) as $expected_total |
      ($c | map(.[ $observed_key ]) | add // 0) as $observed_total |
      {
        rows: ($c | length),
        expected_total: $expected_total,
        observed_total: $observed_total,
        observed_to_expected_ratio: ratio($observed_total; $expected_total)
      };

    [($states // [])[] | {
      target,
      observed_non_source_tools: (.counts.tools_detected // 0),
      observed_non_source_exists: ((.counts.tools_detected // 0) > 0),
      observed_declared_agents: (.counts.declared_agents // 0),
      observed_agents_exist: ((.counts.declared_agents // 0) > 0),
      observed_deployed_agents: (.counts.deployed_agents // 0),
      observed_deployed_agents_exist: ((.counts.deployed_agents // 0) > 0),
      observed_binding_incomplete_agents: (.counts.binding_incomplete_agents // 0),
      observed_binding_incomplete_agents_exist: ((.counts.binding_incomplete_agents // 0) > 0),
      observed_write_capable_agents_exist: ((.counts.write_capable_agents // 0) > 0),
      observed_exec_capable_agents_exist: ((.counts.exec_capable_agents // 0) > 0),
      observed_agent_attack_paths_exist: ((.counts.agent_linked_attack_paths // 0) > 0)
    }] as $observed |
    (($labels[0] // []) as $label_rows |
      [ $label_rows[] as $label
        | ($observed | map(select(.target == ($label.target // ""))) | .[0]) as $obs
        | select($obs != null)
        | $obs + {
            expected_non_source_exists: $label.expected_non_source_exists,
            expected_non_source_count: $label.expected_non_source_count,
            expected_agents_exist: $label.expected_agents_exist,
            expected_agents_count: $label.expected_agents_count,
            expected_deployed_agents_exist: $label.expected_deployed_agents_exist,
            expected_deployed_agents_count: $label.expected_deployed_agents_count,
            expected_binding_incomplete_agents_exist: $label.expected_binding_incomplete_agents_exist,
            expected_binding_incomplete_agents_count: $label.expected_binding_incomplete_agents_count,
            expected_write_capable_agents_exist: $label.expected_write_capable_agents_exist,
            expected_exec_capable_agents_exist: $label.expected_exec_capable_agents_exist,
            expected_agent_attack_paths_exist: $label.expected_agent_attack_paths_exist
          }
      ]) as $rows |
    {
      schema_version: "v2",
      run_id: $run_id,
      generated_at: $generated_at,
      labeled_rows: ($rows | length),
      label_validation: (($validation[0].validation) // null),
      evaluations: {
        non_source_exists: binary_eval($rows; "expected_non_source_exists"; "observed_non_source_exists"),
        non_source_count: count_eval($rows; "expected_non_source_count"; "observed_non_source_tools"),
        agent_presence: binary_eval($rows; "expected_agents_exist"; "observed_agents_exist"),
        agent_count: count_eval($rows; "expected_agents_count"; "observed_declared_agents"),
        deployed_agents: binary_eval($rows; "expected_deployed_agents_exist"; "observed_deployed_agents_exist"),
        deployed_agents_count: count_eval($rows; "expected_deployed_agents_count"; "observed_deployed_agents"),
        binding_incomplete_agents: binary_eval($rows; "expected_binding_incomplete_agents_exist"; "observed_binding_incomplete_agents_exist"),
        binding_incomplete_agents_count: count_eval($rows; "expected_binding_incomplete_agents_count"; "observed_binding_incomplete_agents"),
        write_capable_agents: binary_eval($rows; "expected_write_capable_agents_exist"; "observed_write_capable_agents_exist"),
        exec_capable_agents: binary_eval($rows; "expected_exec_capable_agents_exist"; "observed_exec_capable_agents_exist"),
        agent_attack_paths: binary_eval($rows; "expected_agent_attack_paths_exist"; "observed_agent_attack_paths_exist")
      }
    }
    ' > "${GOLD_EVAL_JSON}"
fi

if [[ "${STRICT}" -eq 1 ]]; then
  if [[ ! -f "${GOLD_EVAL_JSON}" || ! -f "${GOLD_VALIDATION_JSON}" ]]; then
    echo "[sprawl-calibrate-v2] --strict requires --gold-labels plus validation and evaluation artifacts" >&2
    exit 1
  fi
  if ! jq -e '
    (.validation.rows_missing_target_count // 0) == 0 and
    (.validation.duplicate_targets_count // 0) == 0 and
    (.validation.unmatched_targets_count // 0) == 0 and
    (.validation.rows_missing_reviewer_count // 0) == 0 and
    (.validation.rows_without_expectations_count // 0) == 0
  ' "${GOLD_VALIDATION_JSON}" >/dev/null; then
    echo "[sprawl-calibrate-v2] --strict requires complete gold labels with no duplicate/unmatched/missing-reviewer/missing-expectation rows" >&2
    exit 1
  fi
fi

echo "[sprawl-calibrate-v2] wrote ${OUT_DIR}"
