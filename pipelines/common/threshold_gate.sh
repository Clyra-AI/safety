#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  threshold_gate.sh --report-id <id> --claims <file> --thresholds <file> [--strict]

Compares numeric claim values against configured publish thresholds.

Threshold config shape:
{
  "schema_version": "v1",
  "reports": {
    "<report-id>": {
      "required_claim_thresholds": {
        "<claim-id>": { "op": ">=", "value": 100 }
      },
      "recommended_claim_thresholds": {
        "<claim-id>": { "op": ">=", "value": 200 }
      }
    }
  }
}

Note: this gate enforces only `required_claim_thresholds`.
EOF
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
      echo "[threshold-gate] unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "${REPORT_ID}" || -z "${CLAIMS_FILE}" || -z "${THRESHOLDS_FILE}" ]]; then
  echo "[threshold-gate] --report-id, --claims, and --thresholds are required" >&2
  usage >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "[threshold-gate] missing required command: jq" >&2
  exit 1
fi

if [[ ! -f "${CLAIMS_FILE}" ]]; then
  echo "[threshold-gate] claims file not found: ${CLAIMS_FILE}" >&2
  exit 1
fi
if [[ ! -f "${THRESHOLDS_FILE}" ]]; then
  echo "[threshold-gate] thresholds file not found: ${THRESHOLDS_FILE}" >&2
  exit 1
fi

if ! jq -e --arg id "${REPORT_ID}" '.reports[$id] != null' "${THRESHOLDS_FILE}" >/dev/null; then
  msg="[threshold-gate] no thresholds configured for report '${REPORT_ID}'"
  if [[ "${STRICT}" -eq 1 ]]; then
    echo "${msg}" >&2
    exit 1
  fi
  echo "${msg} (warning)" >&2
  exit 0
fi

checks=()
while IFS= read -r line; do
  checks+=("${line}")
done < <(jq -c --arg id "${REPORT_ID}" '.reports[$id].required_claim_thresholds | to_entries[]' "${THRESHOLDS_FILE}")
if [[ "${#checks[@]}" -eq 0 ]]; then
  msg="[threshold-gate] empty threshold set for report '${REPORT_ID}'"
  if [[ "${STRICT}" -eq 1 ]]; then
    echo "${msg}" >&2
    exit 1
  fi
  echo "${msg} (warning)" >&2
  exit 0
fi

failures=0
for item in "${checks[@]}"; do
  claim_id="$(printf '%s' "${item}" | jq -r '.key')"
  op="$(printf '%s' "${item}" | jq -r '.value.op')"
  threshold="$(printf '%s' "${item}" | jq -r '.value.value')"

  case "${op}" in
    ">"|">="|"=="|"<="|"<")
      ;;
    *)
      echo "[threshold-gate] unsupported operator '${op}' for claim '${claim_id}'" >&2
      failures=$((failures + 1))
      continue
      ;;
  esac

  claim_value="$(jq -r --arg cid "${claim_id}" '.claims[] | select(.id == $cid) | .value' "${CLAIMS_FILE}")"
  if [[ -z "${claim_value}" ]]; then
    echo "[threshold-gate] missing claim '${claim_id}' in ${CLAIMS_FILE}" >&2
    failures=$((failures + 1))
    continue
  fi

  if [[ "${claim_value}" = "TBD" ]]; then
    echo "[threshold-gate] claim '${claim_id}' not finalized (value=TBD)" >&2
    failures=$((failures + 1))
    continue
  fi

  if ! awk "BEGIN{exit !(${claim_value} ${op} ${threshold})}"; then
    echo "[threshold-gate] threshold fail: ${claim_id} value=${claim_value} required '${op} ${threshold}'" >&2
    failures=$((failures + 1))
    continue
  fi

  echo "[threshold-gate] ${claim_id}: pass (${claim_value} ${op} ${threshold})"
done

if [[ "${failures}" -gt 0 ]]; then
  echo "[threshold-gate] failures=${failures}" >&2
  exit 1
fi

echo "[threshold-gate] all thresholds satisfied for ${REPORT_ID}"
