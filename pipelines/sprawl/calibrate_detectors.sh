#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  calibrate_detectors.sh --run-id <id> [--out-dir <path>] [--gold-labels <path>] [--strict]

Builds detector calibration artifacts from a completed sprawl run:
  - observed-by-target.csv
  - observed-non-source-tools.csv
  - gold-labels.template.json
  - detector-coverage-summary.json
  - gold-label-evaluation.json (when --gold-labels is provided)

Notes:
  - Headline scope is non-source tools only (`tool_type != "source_repo"`).
  - Gold labels are JSON array entries keyed by `target`.
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
      echo "[sprawl-calibrate] unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "${RUN_ID}" ]]; then
  echo "[sprawl-calibrate] --run-id is required" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "[sprawl-calibrate] jq is required" >&2
  exit 1
fi

RUN_DIR="${REPO_ROOT}/runs/tool-sprawl/${RUN_ID}"
SCANS_DIR="${RUN_DIR}/scans"
STATES_DIR="${RUN_DIR}/states"
SUMMARY_PATH="${RUN_DIR}/agg/campaign-summary.json"

if [[ ! -d "${SCANS_DIR}" || ! -d "${STATES_DIR}" ]]; then
  echo "[sprawl-calibrate] missing run dirs under ${RUN_DIR}" >&2
  exit 1
fi
if [[ ! -f "${SUMMARY_PATH}" ]]; then
  echo "[sprawl-calibrate] missing campaign summary: ${SUMMARY_PATH}" >&2
  exit 1
fi

if [[ -z "${OUT_DIR}" ]]; then
  OUT_DIR="${RUN_DIR}/calibration"
fi
if [[ "${OUT_DIR}" != /* ]]; then
  OUT_DIR="${REPO_ROOT}/${OUT_DIR}"
fi
mkdir -p "${OUT_DIR}"

OBSERVED_TARGETS_CSV="${OUT_DIR}/observed-by-target.csv"
OBSERVED_NON_SOURCE_CSV="${OUT_DIR}/observed-non-source-tools.csv"
GOLD_TEMPLATE_JSON="${OUT_DIR}/gold-labels.template.json"
COVERAGE_SUMMARY_JSON="${OUT_DIR}/detector-coverage-summary.json"
GOLD_EVAL_JSON="${OUT_DIR}/gold-label-evaluation.json"

{
  echo 'target,observed_non_source_tools,observed_source_repo_tools,observed_raw_tools,destructive_tooling,approval_gate_present,prompt_only_controls,audit_artifacts_present,source'
  find "${STATES_DIR}" -type f -name '*.json' | sort | while IFS= read -r state; do
    jq -r '[
      .target,
      (.counts.tools_detected // 0),
      (.segments.source_repo_tools // 0),
      (.segments.raw_counts.tools_detected // 0),
      (.control_posture.destructive_tooling // false),
      (.control_posture.approval_gate_present // false),
      (.control_posture.prompt_only_controls // false),
      (.control_posture.audit_artifacts_present // false),
      (.source // "unknown")
    ] | @csv' "${state}"
  done
} > "${OBSERVED_TARGETS_CSV}"

{
  echo 'target,tool_key,tool_type,approval_classification,permission_write,permission_admin,permissions'
  find "${SCANS_DIR}" -type f -name '*.scan.json' | sort | while IFS= read -r scan; do
    slug="$(basename "${scan}" .scan.json)"
    target="$(jq -r '.target // empty' "${STATES_DIR}/${slug}.json" 2>/dev/null || true)"
    if [[ -z "${target}" ]]; then
      target="$(jq -r 'if (.target | type) == "string" then .target elif (.target | type) == "object" then (.target.value // "unknown") else "unknown" end' "${scan}")"
    fi

    jq -r --arg target "${target}" '
      def as_cell:
        if . == null then "unknown"
        elif (type == "string") then .
        elif (type == "number" or type == "boolean") then tostring
        else @json
        end;
      (.inventory.tools // [])[]? |
      select((.tool_type // "") != "source_repo") |
      [
        $target,
        ((.tool_name // .name // .tool_id // .id // .repo // "unknown") | as_cell),
        ((.tool_type // "unknown") | as_cell),
        ((.approval_classification // "unknown") | as_cell),
        ((.permission_surface.write // false) | tostring),
        ((.permission_surface.admin // false) | tostring),
        (((.permissions // []) | map(if type == "string" then . else @json end) | join("|")) // "")
      ] | @csv
    ' "${scan}"
  done
} > "${OBSERVED_NON_SOURCE_CSV}"

jq -n \
  --slurpfile states <(find "${STATES_DIR}" -type f -name '*.json' | sort | xargs -I{} jq -c '.' "{}") \
  '
  ($states // []) as $rows |
  $rows
  | map({
      target,
      observed_non_source_tools: (.counts.tools_detected // 0),
      observed_source_repo_tools: (.segments.source_repo_tools // 0),
      observed_raw_tools: (.segments.raw_counts.tools_detected // 0),
      observed_destructive_tooling: (.control_posture.destructive_tooling // false),
      observed_approval_gate_absent: ((.control_posture.approval_gate_present // false) | not),
      observed_unknown_tools: (.counts.approval_unknown // .counts.unknown // 0),
      expected_non_source_exists: null,
      expected_non_source_count: null,
      expected_destructive_tooling: null,
      expected_approval_gate_absent: null,
      expected_unknown_exists: null,
      expected_unknown_count: null,
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
  ($rows | map(.counts.tools_detected // 0) | add) as $non_source_total |
  ($rows | map(.segments.source_repo_tools // 0) | add) as $source_repo_total |
  ($rows | map(.segments.raw_counts.tools_detected // 0) | add) as $raw_total |
  {
    schema_version: "v1",
    run_id: $run_id,
    generated_at: $generated_at,
    headline_scope: "exclude_source_repo",
    observed: {
      targets_total: $targets_total,
      targets_with_non_source: $targets_with_non_source,
      targets_with_non_source_pct: (if $targets_total == 0 then 0 else ((10000 * $targets_with_non_source / $targets_total) | round / 100) end),
      non_source_tools_total: $non_source_total,
      source_repo_tools_total: $source_repo_total,
      raw_tools_total: $raw_total,
      source_repo_share_pct: (if $raw_total == 0 then 0 else ((10000 * $source_repo_total / $raw_total) | round / 100) end),
      avg_non_source_tools_per_target: (if $targets_total == 0 then 0 else ((100 * $non_source_total / $targets_total) | round / 100) end)
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
    echo "[sprawl-calibrate] gold labels file not found: ${GOLD_LABELS_PATH}" >&2
    exit 1
  fi

  jq -n \
    --arg run_id "${RUN_ID}" \
    --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --slurpfile labels "${GOLD_LABELS_PATH}" \
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

    def gate_absent_from($r):
      if (($r.control_posture // {}) | has("approval_gate_absent")) then
        ($r.control_posture.approval_gate_absent)
      else
        (($r.control_posture.approval_gate_present // false) | not)
      end;

    [($states // [])[] | {
      target,
      observed_non_source_tools: (.counts.tools_detected // 0),
      predicted_non_source_exists: ((.counts.tools_detected // 0) > 0),
      observed_destructive_tooling: (.control_posture.destructive_tooling // false),
      predicted_destructive_tooling: (.control_posture.destructive_tooling // false),
      observed_approval_gate_absent: gate_absent_from(.),
      predicted_approval_gate_absent: gate_absent_from(.),
      observed_unknown_tools: (.counts.approval_unknown // .counts.unknown // 0),
      predicted_unknown_exists: ((.counts.approval_unknown // .counts.unknown // 0) > 0)
    }] as $observed |
    (($labels[0] // []) | map(select(.target != null))) as $gold |
    def value_or_null($obj; $key):
      if ($obj | has($key)) then $obj[$key] else null end;

    [ $gold[] as $g |
      (
        ($observed | map(select(.target == $g.target)) | .[0]) // {
          target: $g.target,
          observed_non_source_tools: 0,
          predicted_non_source_exists: false,
          observed_destructive_tooling: false,
          predicted_destructive_tooling: false,
          observed_approval_gate_absent: false,
          predicted_approval_gate_absent: false,
          observed_unknown_tools: 0,
          predicted_unknown_exists: false
        }
      ) as $o |
      {
        target: $g.target,
        expected_non_source_exists: value_or_null($g; "expected_non_source_exists"),
        expected_non_source_count: value_or_null($g; "expected_non_source_count"),
        expected_destructive_tooling: value_or_null($g; "expected_destructive_tooling"),
        expected_approval_gate_absent: value_or_null($g; "expected_approval_gate_absent"),
        expected_unknown_exists: value_or_null($g; "expected_unknown_exists"),
        expected_unknown_count: value_or_null($g; "expected_unknown_count"),
        reviewer: value_or_null($g; "reviewer"),
        notes: value_or_null($g; "notes"),
        observed_non_source_tools: ($o.observed_non_source_tools // 0),
        predicted_non_source_exists: ($o.predicted_non_source_exists // false),
        observed_destructive_tooling: ($o.observed_destructive_tooling // false),
        predicted_destructive_tooling: ($o.predicted_destructive_tooling // false),
        observed_approval_gate_absent: ($o.observed_approval_gate_absent // false),
        predicted_approval_gate_absent: ($o.predicted_approval_gate_absent // false),
        observed_unknown_tools: ($o.observed_unknown_tools // 0),
        predicted_unknown_exists: ($o.predicted_unknown_exists // false)
      }
    ] as $rows |

    (binary_eval($rows; "expected_non_source_exists"; "predicted_non_source_exists")) as $non_source_exists |
    (binary_eval($rows; "expected_destructive_tooling"; "predicted_destructive_tooling")) as $destructive_tooling |
    (binary_eval($rows; "expected_approval_gate_absent"; "predicted_approval_gate_absent")) as $approval_gate_absence |
    (binary_eval($rows; "expected_unknown_exists"; "predicted_unknown_exists")) as $unknown_exists |
    (count_eval($rows; "expected_non_source_count"; "observed_non_source_tools")) as $non_source_count |
    (count_eval($rows; "expected_unknown_count"; "observed_unknown_tools")) as $unknown_count |

    {
      schema_version: "v2",
      run_id: $run_id,
      generated_at: $generated_at,
      labeled_rows_total: ($rows | length),
      # Backward-compatible top-level metrics map to non_source_exists evaluation.
      binary_eval_rows: ($non_source_exists.rows),
      binary_metrics: {
        true_positive: ($non_source_exists.true_positive),
        false_negative: ($non_source_exists.false_negative),
        false_positive: ($non_source_exists.false_positive),
        true_negative: ($non_source_exists.true_negative),
        recall_exists: ($non_source_exists.recall_exists),
        precision_exists: ($non_source_exists.precision_exists)
      },
      count_eval_rows: ($non_source_count.rows),
      count_metrics: {
        expected_non_source_total: ($non_source_count.expected_total),
        observed_non_source_total: ($non_source_count.observed_total),
        observed_to_expected_ratio: ($non_source_count.observed_to_expected_ratio)
      },
      evaluations: {
        non_source_exists: $non_source_exists,
        destructive_tooling: $destructive_tooling,
        approval_gate_absence: $approval_gate_absence,
        unknown_exists: $unknown_exists
      },
      count_evaluations: {
        non_source_count: $non_source_count,
        unknown_count: $unknown_count
      }
    }
    ' > "${GOLD_EVAL_JSON}"
fi

if [[ "${STRICT}" -eq 1 ]]; then
  if ! jq -e '.observed.targets_total > 0 and .observed.raw_tools_total >= .observed.non_source_tools_total' "${COVERAGE_SUMMARY_JSON}" >/dev/null; then
    echo "[sprawl-calibrate] strict validation failed for coverage summary" >&2
    exit 1
  fi
fi

echo "[sprawl-calibrate] run_id=${RUN_ID}"
echo "[sprawl-calibrate] wrote ${OBSERVED_TARGETS_CSV}"
echo "[sprawl-calibrate] wrote ${OBSERVED_NON_SOURCE_CSV}"
echo "[sprawl-calibrate] wrote ${GOLD_TEMPLATE_JSON}"
echo "[sprawl-calibrate] wrote ${COVERAGE_SUMMARY_JSON}"
if [[ -n "${GOLD_LABELS}" ]]; then
  echo "[sprawl-calibrate] wrote ${GOLD_EVAL_JSON}"
fi
