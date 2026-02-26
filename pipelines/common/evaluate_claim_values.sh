#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  evaluate_claim_values.sh --report-id <id> --claim-values <path> --thresholds <path> [--lane-duration-sec <n>] [--scale-ids <csv>] [--output <path>]

Evaluates required and recommended thresholds against derived claim values.
Scaling behavior for time-window runs:
- claims ending in `_24h` are scaled to a 24h projection when lane-duration-sec is set
- additional claim ids can be scaled with --scale-ids
USAGE
}

REPORT_ID=""
CLAIM_VALUES=""
THRESHOLDS=""
LANE_DURATION_SEC=""
SCALE_IDS_CSV=""
OUTPUT_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --report-id)
      REPORT_ID="${2:-}"
      shift 2
      ;;
    --claim-values)
      CLAIM_VALUES="${2:-}"
      shift 2
      ;;
    --thresholds)
      THRESHOLDS="${2:-}"
      shift 2
      ;;
    --lane-duration-sec)
      LANE_DURATION_SEC="${2:-}"
      shift 2
      ;;
    --scale-ids)
      SCALE_IDS_CSV="${2:-}"
      shift 2
      ;;
    --output)
      OUTPUT_PATH="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[evaluate-claims] unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "${REPORT_ID}" || -z "${CLAIM_VALUES}" || -z "${THRESHOLDS}" ]]; then
  echo "[evaluate-claims] --report-id, --claim-values, and --thresholds are required" >&2
  usage >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "[evaluate-claims] missing required command: jq" >&2
  exit 1
fi

if [[ ! -f "${CLAIM_VALUES}" ]]; then
  echo "[evaluate-claims] claim-values file not found: ${CLAIM_VALUES}" >&2
  exit 1
fi
if [[ ! -f "${THRESHOLDS}" ]]; then
  echo "[evaluate-claims] thresholds file not found: ${THRESHOLDS}" >&2
  exit 1
fi

if [[ -n "${LANE_DURATION_SEC}" && ! "${LANE_DURATION_SEC}" =~ ^[0-9]+$ ]]; then
  echo "[evaluate-claims] --lane-duration-sec must be an integer" >&2
  exit 1
fi

if [[ -n "${LANE_DURATION_SEC}" && "${LANE_DURATION_SEC}" -gt 0 ]]; then
  SCALE_FACTOR="$(awk -v d="${LANE_DURATION_SEC}" 'BEGIN{printf "%.12f", (24*3600)/d}')"
else
  SCALE_FACTOR="1"
fi

SCALE_IDS_JSON='[]'
if [[ -n "${SCALE_IDS_CSV}" ]]; then
  SCALE_IDS_JSON="$(printf '%s' "${SCALE_IDS_CSV}" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed '/^$/d' | jq -R . | jq -s .)"
fi

result_json="$({
  jq -n \
    --arg report_id "${REPORT_ID}" \
    --arg claim_values_path "${CLAIM_VALUES}" \
    --arg thresholds_path "${THRESHOLDS}" \
    --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --argjson scale_factor "${SCALE_FACTOR}" \
    --argjson scale_ids "${SCALE_IDS_JSON}" \
    --slurpfile cv "${CLAIM_VALUES}" \
    --slurpfile th "${THRESHOLDS}" '
      def should_scale($id):
        ($id | endswith("_24h")) or (($scale_ids | index($id)) != null);

      def project($id; $value):
        if should_scale($id) and (($value | type) == "number") then
          ($value * $scale_factor)
        else
          $value
        end;

      def compare($op; $a; $b):
        if $op == ">=" then ($a >= $b)
        elif $op == "<=" then ($a <= $b)
        elif $op == ">" then ($a > $b)
        elif $op == "<" then ($a < $b)
        elif $op == "==" then ($a == $b)
        else false
        end;

      def eval_scope($scope):
        (($th[0].reports[$report_id][$scope] // {}) | to_entries) as $rows
        | ($rows | map(
            .key as $id
            | .value.op as $op
            | .value.value as $threshold
            | (($cv[0].results[] | select(.id == $id) | .computed_value) // null) as $measured
            | (project($id; $measured)) as $projected
            | {
                id: $id,
                operator: $op,
                threshold: $threshold,
                measured: $measured,
                projected_24h: $projected,
                scaled_to_24h: should_scale($id),
                passed: (
                  if ($projected | type) == "number" then
                    compare($op; $projected; $threshold)
                  else
                    false
                  end
                ),
                error: (
                  if $measured == null then
                    "missing_claim_value"
                  elif ($measured | type) != "number" then
                    "non_numeric_claim_value"
                  else
                    null
                  end
                )
              }
          )) as $evaluated
        | {
            total: ($evaluated | length),
            passed: ($evaluated | map(select(.passed == true)) | length),
            failed: ($evaluated | map(select(.passed != true)) | length),
            results: $evaluated
          };

      {
        schema_version: "v1",
        generated_at: $generated_at,
        report_id: $report_id,
        run_id: ($cv[0].run_id // null),
        claim_values_path: $claim_values_path,
        thresholds_path: $thresholds_path,
        scaling: {
          lane_duration_sec: (if $scale_factor == 1 then null else (86400 / $scale_factor) end),
          scale_factor_to_24h: $scale_factor,
          additional_scaled_claim_ids: $scale_ids
        },
        required: eval_scope("required_claim_thresholds"),
        recommended: eval_scope("recommended_claim_thresholds")
      }
    '
})"

if [[ -n "${OUTPUT_PATH}" ]]; then
  mkdir -p "$(dirname "${OUTPUT_PATH}")"
  printf '%s\n' "${result_json}" > "${OUTPUT_PATH}"
  echo "[evaluate-claims] wrote ${OUTPUT_PATH}"
fi

req_passed="$(printf '%s' "${result_json}" | jq -r '.required.passed')"
req_total="$(printf '%s' "${result_json}" | jq -r '.required.total')"
rec_passed="$(printf '%s' "${result_json}" | jq -r '.recommended.passed')"
rec_total="$(printf '%s' "${result_json}" | jq -r '.recommended.total')"
echo "[evaluate-claims] required=${req_passed}/${req_total} recommended=${rec_passed}/${rec_total}"

if [[ -z "${OUTPUT_PATH}" ]]; then
  printf '%s\n' "${result_json}"
fi
