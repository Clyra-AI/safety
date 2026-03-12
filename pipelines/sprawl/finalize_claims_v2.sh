#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  finalize_claims_v2.sh --run-id <id> [--claims-template <path>] [--output-claims <path>]
                        [--claim-values-output <path>] [--threshold-output <path>]
                        [--update-ledger] [--validate] [--lane test|full] [--strict]

Derives finalized v2 claim values from an immutable run, writes an updated claims ledger,
and optionally validates the result.
USAGE
}

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUN_ID=""
CLAIMS_TEMPLATE="claims/ai-tool-sprawl-v2-2026/claims.json"
OUTPUT_CLAIMS=""
CLAIM_VALUES_OUTPUT=""
THRESHOLD_OUTPUT=""
UPDATE_LEDGER=0
VALIDATE=0
LANE="full"
STRICT_VALIDATE=0

resolve_path() {
  local path="$1"
  local root="$2"
  if [[ "${path}" = /* ]]; then
    printf '%s\n' "${path}"
  else
    printf '%s/%s\n' "${root}" "${path}"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)
      RUN_ID="${2:-}"
      shift 2
      ;;
    --claims-template)
      CLAIMS_TEMPLATE="${2:-}"
      shift 2
      ;;
    --output-claims)
      OUTPUT_CLAIMS="${2:-}"
      shift 2
      ;;
    --claim-values-output)
      CLAIM_VALUES_OUTPUT="${2:-}"
      shift 2
      ;;
    --threshold-output)
      THRESHOLD_OUTPUT="${2:-}"
      shift 2
      ;;
    --update-ledger)
      UPDATE_LEDGER=1
      shift
      ;;
    --validate)
      VALIDATE=1
      shift
      ;;
    --lane)
      LANE="${2:-}"
      shift 2
      ;;
    --strict)
      STRICT_VALIDATE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[sprawl-finalize-claims-v2] unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "${RUN_ID}" ]]; then
  echo "[sprawl-finalize-claims-v2] --run-id is required" >&2
  exit 1
fi
if [[ "${LANE}" != "test" && "${LANE}" != "full" ]]; then
  echo "[sprawl-finalize-claims-v2] --lane must be test or full" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "[sprawl-finalize-claims-v2] jq is required" >&2
  exit 1
fi

RUN_DIR="${REPO_ROOT}/runs/tool-sprawl/${RUN_ID}"
if [[ ! -d "${RUN_DIR}" || ! -f "${RUN_DIR}/agg/campaign-summary-v2.json" ]]; then
  echo "[sprawl-finalize-claims-v2] missing v2 run artifacts under ${RUN_DIR}" >&2
  exit 1
fi

CLAIMS_TEMPLATE_ABS="$(resolve_path "${CLAIMS_TEMPLATE}" "${REPO_ROOT}")"
if [[ ! -f "${CLAIMS_TEMPLATE_ABS}" ]]; then
  echo "[sprawl-finalize-claims-v2] claims template not found: ${CLAIMS_TEMPLATE_ABS}" >&2
  exit 1
fi

if [[ -z "${OUTPUT_CLAIMS}" ]]; then
  OUTPUT_CLAIMS="runs/tool-sprawl/${RUN_ID}/artifacts/claims-finalized-v2.json"
fi
if [[ -z "${CLAIM_VALUES_OUTPUT}" ]]; then
  CLAIM_VALUES_OUTPUT="runs/tool-sprawl/${RUN_ID}/artifacts/claim-values-v2.json"
fi
if [[ -z "${THRESHOLD_OUTPUT}" ]]; then
  THRESHOLD_OUTPUT="runs/tool-sprawl/${RUN_ID}/artifacts/threshold-evaluation-v2.json"
fi

OUTPUT_CLAIMS_ABS="$(resolve_path "${OUTPUT_CLAIMS}" "${REPO_ROOT}")"
CLAIM_VALUES_OUTPUT_ABS="$(resolve_path "${CLAIM_VALUES_OUTPUT}" "${REPO_ROOT}")"
THRESHOLD_OUTPUT_ABS="$(resolve_path "${THRESHOLD_OUTPUT}" "${REPO_ROOT}")"

mkdir -p "$(dirname "${OUTPUT_CLAIMS_ABS}")"
mkdir -p "$(dirname "${CLAIM_VALUES_OUTPUT_ABS}")"
mkdir -p "$(dirname "${THRESHOLD_OUTPUT_ABS}")"

"${REPO_ROOT}/pipelines/common/derive_claim_values.sh" \
  --repo-root "${REPO_ROOT}" \
  --claims "${CLAIMS_TEMPLATE_ABS}" \
  --run-id "${RUN_ID}" \
  --output "${CLAIM_VALUES_OUTPUT_ABS}" \
  --strict \
  --write-updated-claims "${OUTPUT_CLAIMS_ABS}"

"${REPO_ROOT}/pipelines/common/claim_gates.sh" \
  --repo-root "${REPO_ROOT}" \
  --claims "${OUTPUT_CLAIMS_ABS}" \
  --run-id "${RUN_ID}" \
  --strict

"${REPO_ROOT}/pipelines/common/evaluate_claim_values.sh" \
  --report-id "ai-tool-sprawl-v2-2026" \
  --repo-root "${REPO_ROOT}" \
  --claim-values "${CLAIM_VALUES_OUTPUT_ABS}" \
  --thresholds "${REPO_ROOT}/pipelines/config/publish-thresholds.json" \
  --output "${THRESHOLD_OUTPUT_ABS}"

if [[ "${UPDATE_LEDGER}" -eq 1 ]]; then
  cp "${OUTPUT_CLAIMS_ABS}" "${CLAIMS_TEMPLATE_ABS}"
fi

if [[ "${VALIDATE}" -eq 1 ]]; then
  validate_cmd=(
    "${REPO_ROOT}/pipelines/sprawl/validate_v2.sh"
    --run-id "${RUN_ID}"
    --lane "${LANE}"
    --claims-file "${OUTPUT_CLAIMS_ABS}"
  )
  if [[ "${STRICT_VALIDATE}" -eq 1 ]]; then
    validate_cmd+=(--strict)
  fi
  "${validate_cmd[@]}"
fi

echo "[sprawl-finalize-claims-v2] claim-values=${CLAIM_VALUES_OUTPUT_ABS}"
echo "[sprawl-finalize-claims-v2] updated-claims=${OUTPUT_CLAIMS_ABS}"
echo "[sprawl-finalize-claims-v2] threshold-evaluation=${THRESHOLD_OUTPUT_ABS}"
