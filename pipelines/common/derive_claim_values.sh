#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  derive_claim_values.sh --claims <path> --output <path> [--run-id <id>] [--repo-root <path>] [--strict] [--write-updated-claims <path>]

Derives claim values by executing each claim query against its artifact.
Supports <run_id> placeholder replacement in artifact paths.
USAGE
}

require_cmd() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "[derive-claims] missing required command: ${cmd}" >&2
    exit 1
  fi
}

resolve_path() {
  local path="$1"
  local root="$2"
  if [[ "${path}" = /* ]]; then
    printf '%s\n' "${path}"
  else
    printf '%s/%s\n' "${root}" "${path}"
  fi
}

relativize_path() {
  local path="$1"
  local root="$2"
  case "${path}" in
    "${root}")
      printf '.\n'
      ;;
    "${root}"/*)
      printf '%s\n' "${path#${root}/}"
      ;;
    *)
      printf '%s\n' "${path}"
      ;;
  esac
}

trim() {
  # shellcheck disable=SC2001
  sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

run_query() {
  local query="$1"
  local artifact="$2"
  local out
  if [[ "${query}" =~ ^jq[[:space:]] ]]; then
    out="$(bash -lc "${query} \"${artifact}\"" 2>/dev/null || true)"
  else
    out="$(bash -lc "${query}" 2>/dev/null || true)"
  fi
  printf '%s' "${out}"
}

CLAIMS_FILE=""
OUTPUT_FILE=""
RUN_ID="${RUN_ID:-}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STRICT=0
UPDATED_CLAIMS_OUTPUT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --claims)
      CLAIMS_FILE="${2:-}"
      shift 2
      ;;
    --output)
      OUTPUT_FILE="${2:-}"
      shift 2
      ;;
    --run-id)
      RUN_ID="${2:-}"
      shift 2
      ;;
    --repo-root)
      REPO_ROOT="${2:-}"
      shift 2
      ;;
    --strict)
      STRICT=1
      shift
      ;;
    --write-updated-claims)
      UPDATED_CLAIMS_OUTPUT="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[derive-claims] unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "${CLAIMS_FILE}" || -z "${OUTPUT_FILE}" ]]; then
  echo "[derive-claims] --claims and --output are required" >&2
  usage >&2
  exit 1
fi

require_cmd jq

CLAIMS_FILE_ABS="$(resolve_path "${CLAIMS_FILE}" "${REPO_ROOT}")"
if [[ ! -f "${CLAIMS_FILE_ABS}" ]]; then
  echo "[derive-claims] claims file not found: ${CLAIMS_FILE_ABS}" >&2
  exit 1
fi
CLAIMS_FILE_REL="$(relativize_path "${CLAIMS_FILE_ABS}" "${REPO_ROOT}")"

mkdir -p "$(dirname "${OUTPUT_FILE}")"

if ! jq -e '.schema_version == "v1" and (.claims | type == "array")' "${CLAIMS_FILE_ABS}" >/dev/null; then
  echo "[derive-claims] invalid claims schema: ${CLAIMS_FILE_ABS}" >&2
  exit 1
fi

results_tmp="$(mktemp)"
printf '[' > "${results_tmp}"
first=1

total=0
computed=0
warnings=0
failures=0

while IFS= read -r claim; do
  total=$((total + 1))

  id="$(printf '%s' "${claim}" | jq -r '.id')"
  artifact_raw="$(printf '%s' "${claim}" | jq -r '.artifact_path')"
  query="$(printf '%s' "${claim}" | jq -r '.query')"

  status="ok"
  error=""
  computed_json="null"

  if [[ -z "${id}" || -z "${artifact_raw}" || -z "${query}" ]]; then
    status="failure"
    error="missing required claim fields"
  else
    artifact="${artifact_raw}"
    if [[ "${artifact}" == *"<run_id>"* ]]; then
      if [[ -n "${RUN_ID}" ]]; then
        artifact="${artifact//<run_id>/${RUN_ID}}"
      else
        status="warning"
        error="unresolved <run_id> placeholder"
      fi
    fi

    if [[ "${status}" == "ok" ]]; then
      artifact_abs="$(resolve_path "${artifact}" "${REPO_ROOT}")"
      if [[ ! -f "${artifact_abs}" ]]; then
        status="warning"
        error="artifact not found: ${artifact_abs}"
      else
        computed_raw="$(run_query "${query}" "${artifact_abs}" | trim)"
        if [[ -z "${computed_raw}" ]]; then
          status="failure"
          error="query produced empty output"
        else
          computed_json="$(printf '%s' "${computed_raw}" | jq -Rc 'try fromjson catch .')"
          computed=$((computed + 1))
        fi
      fi
    fi
  fi

  case "${status}" in
    warning)
      warnings=$((warnings + 1))
      if [[ "${STRICT}" -eq 1 ]]; then
        failures=$((failures + 1))
      fi
      ;;
    failure)
      failures=$((failures + 1))
      ;;
  esac

  row="$(jq -n \
    --arg id "${id}" \
    --arg status "${status}" \
    --arg artifact_path "${artifact_raw}" \
    --arg query "${query}" \
    --arg error "${error}" \
    --argjson computed_value "${computed_json}" \
    '{
      id: $id,
      status: $status,
      artifact_path: $artifact_path,
      query: $query,
      computed_value: $computed_value,
      error: (if $error == "" then null else $error end)
    }')"

  if [[ "${first}" -eq 1 ]]; then
    printf '%s' "${row}" >> "${results_tmp}"
    first=0
  else
    printf ',%s' "${row}" >> "${results_tmp}"
  fi
done < <(jq -c '.claims[]' "${CLAIMS_FILE_ABS}")

printf ']\n' >> "${results_tmp}"

jq -n \
  --arg schema_version "v1" \
  --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg run_id "${RUN_ID}" \
  --arg claims_file "${CLAIMS_FILE_REL}" \
  --argjson total "${total}" \
  --argjson computed "${computed}" \
  --argjson warnings "${warnings}" \
  --argjson failures "${failures}" \
  --slurpfile results "${results_tmp}" \
  '{
    schema_version: $schema_version,
    generated_at: $generated_at,
    run_id: (if $run_id == "" then null else $run_id end),
    claims_file: $claims_file,
    coverage: {
      total_claims: $total,
      computed_claims: $computed,
      warnings: $warnings,
      failures: $failures
    },
    results: $results[0]
  }' > "${OUTPUT_FILE}"

rm -f "${results_tmp}"

if [[ -n "${UPDATED_CLAIMS_OUTPUT}" ]]; then
  mkdir -p "$(dirname "${UPDATED_CLAIMS_OUTPUT}")"
  jq --slurpfile derived "${OUTPUT_FILE}" '
    .claims |= map(
      . as $claim
      | (
          $derived[0].results
          | map(select(.id == $claim.id and .status == "ok"))
          | .[0].computed_value
        ) as $value
      | if $value == null then $claim else ($claim + {value: $value}) end
    )
  ' "${CLAIMS_FILE_ABS}" > "${UPDATED_CLAIMS_OUTPUT}"
fi

echo "[derive-claims] wrote ${OUTPUT_FILE}"
if [[ -n "${UPDATED_CLAIMS_OUTPUT}" ]]; then
  echo "[derive-claims] wrote ${UPDATED_CLAIMS_OUTPUT}"
fi

echo "[derive-claims] coverage total=${total} computed=${computed} warnings=${warnings} failures=${failures}"
if [[ "${failures}" -gt 0 ]]; then
  exit 1
fi
