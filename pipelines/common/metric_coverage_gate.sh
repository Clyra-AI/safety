#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  metric_coverage_gate.sh --report-id <id> --claims <path> --thresholds <path> [--strict]

Validates claim/threshold mapping coverage:
  - every threshold claim id exists in the claim ledger
  - every claim id is mapped in required or recommended thresholds
USAGE
}

REPORT_ID=""
CLAIMS_FILE=""
THRESHOLDS_FILE=""
STRICT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --report-id)
      REPORT_ID="${2:-}"
      shift 2
      ;;
    --claims)
      CLAIMS_FILE="${2:-}"
      shift 2
      ;;
    --thresholds)
      THRESHOLDS_FILE="${2:-}"
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
      echo "[metric-coverage] unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "${REPORT_ID}" || -z "${CLAIMS_FILE}" || -z "${THRESHOLDS_FILE}" ]]; then
  echo "[metric-coverage] --report-id, --claims, and --thresholds are required" >&2
  usage >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "[metric-coverage] missing required command: jq" >&2
  exit 1
fi

if [[ ! -f "${CLAIMS_FILE}" ]]; then
  echo "[metric-coverage] claims file not found: ${CLAIMS_FILE}" >&2
  exit 1
fi
if [[ ! -f "${THRESHOLDS_FILE}" ]]; then
  echo "[metric-coverage] thresholds file not found: ${THRESHOLDS_FILE}" >&2
  exit 1
fi

if ! jq -e --arg rid "${REPORT_ID}" '(.report_id == $rid) and ((.claims | type) == "array")' "${CLAIMS_FILE}" >/dev/null; then
  echo "[metric-coverage] report_id mismatch or invalid claims shape in ${CLAIMS_FILE}" >&2
  exit 1
fi

if ! jq -e --arg rid "${REPORT_ID}" '.reports[$rid] != null' "${THRESHOLDS_FILE}" >/dev/null; then
  echo "[metric-coverage] report not found in thresholds: ${REPORT_ID}" >&2
  exit 1
fi

claim_ids=()
while IFS= read -r line; do
  claim_ids+=("${line}")
done < <(jq -r '.claims[].id' "${CLAIMS_FILE}" | sort)

duplicate_claim_ids=()
while IFS= read -r line; do
  [[ -z "${line}" ]] && continue
  duplicate_claim_ids+=("${line}")
done < <(printf '%s\n' "${claim_ids[@]}" | uniq -d)

failures=0
warnings=0

if [[ "${#duplicate_claim_ids[@]}" -gt 0 ]]; then
  echo "[metric-coverage] duplicate claim ids: ${duplicate_claim_ids[*]}" >&2
  failures=$((failures + 1))
fi

required_ids=()
while IFS= read -r line; do
  [[ -z "${line}" ]] && continue
  required_ids+=("${line}")
done < <(jq -r --arg rid "${REPORT_ID}" '.reports[$rid].required_claim_thresholds | keys[]' "${THRESHOLDS_FILE}" | sort)

recommended_ids=()
while IFS= read -r line; do
  [[ -z "${line}" ]] && continue
  recommended_ids+=("${line}")
done < <(jq -r --arg rid "${REPORT_ID}" '.reports[$rid].recommended_claim_thresholds | keys[]' "${THRESHOLDS_FILE}" | sort)

threshold_ids=()
while IFS= read -r line; do
  [[ -z "${line}" ]] && continue
  threshold_ids+=("${line}")
done < <(printf '%s\n' "${required_ids[@]}" "${recommended_ids[@]}" | sed '/^$/d' | sort -u)

for tid in "${threshold_ids[@]}"; do
  if ! jq -e --arg tid "${tid}" '.claims[] | select(.id == $tid)' "${CLAIMS_FILE}" >/dev/null; then
    echo "[metric-coverage] threshold claim id missing in claims ledger: ${tid}" >&2
    failures=$((failures + 1))
  fi
done

for cid in "${claim_ids[@]}"; do
  if ! printf '%s\n' "${threshold_ids[@]}" | grep -Fxq "${cid}"; then
    msg="[metric-coverage] claim id not mapped in thresholds: ${cid}"
    if [[ "${STRICT}" -eq 1 ]]; then
      echo "${msg}" >&2
      failures=$((failures + 1))
    else
      echo "${msg} (warning)" >&2
      warnings=$((warnings + 1))
    fi
  fi
done

for cid in "${claim_ids[@]}"; do
  query="$(jq -r --arg cid "${cid}" '.claims[] | select(.id == $cid) | .query' "${CLAIMS_FILE}")"
  artifact="$(jq -r --arg cid "${cid}" '.claims[] | select(.id == $cid) | .artifact_path' "${CLAIMS_FILE}")"
  if [[ -z "${query}" || "${query}" == "null" ]]; then
    echo "[metric-coverage] claim missing query: ${cid}" >&2
    failures=$((failures + 1))
  fi
  if [[ -z "${artifact}" || "${artifact}" == "null" ]]; then
    echo "[metric-coverage] claim missing artifact_path: ${cid}" >&2
    failures=$((failures + 1))
  fi
done

echo "[metric-coverage] report=${REPORT_ID} claims=${#claim_ids[@]} thresholds=${#threshold_ids[@]} warnings=${warnings} failures=${failures}"
if [[ "${failures}" -gt 0 ]]; then
  exit 1
fi
