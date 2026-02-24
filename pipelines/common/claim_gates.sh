#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  claim_gates.sh --claims <path> [--run-id <id>] [--repo-root <path>] [--strict]

Behavior:
  - Verifies claims JSON shape and required fields.
  - Resolves artifact paths (supports <run_id> placeholder).
  - Executes each claim query and compares computed value to claim value when claim value is set.
  - In non-strict mode, unresolved placeholders or TBD values are warnings.
  - In strict mode, unresolved placeholders or TBD values are failures.
EOF
}

require_cmd() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "[claim-gates] missing required command: ${cmd}" >&2
    exit 1
  fi
}

trim() {
  # shellcheck disable=SC2001
  sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
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

compare_values() {
  local expected="$1"
  local actual="$2"

  local expected_json actual_json
  expected_json="$(printf '%s' "${expected}" | jq -Rc 'try fromjson catch .')"
  actual_json="$(printf '%s' "${actual}" | jq -Rc 'try fromjson catch .')"
  [[ "${expected_json}" = "${actual_json}" ]]
}

CLAIMS_FILE=""
RUN_ID="${RUN_ID:-}"
STRICT=0
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --claims)
      CLAIMS_FILE="${2:-}"
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
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[claim-gates] unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "${CLAIMS_FILE}" ]]; then
  echo "[claim-gates] --claims is required" >&2
  usage >&2
  exit 1
fi

require_cmd jq

CLAIMS_FILE_ABS="$(resolve_path "${CLAIMS_FILE}" "${REPO_ROOT}")"
if [[ ! -f "${CLAIMS_FILE_ABS}" ]]; then
  echo "[claim-gates] claims file not found: ${CLAIMS_FILE_ABS}" >&2
  exit 1
fi

jq -e '.schema_version == "v1" and (.claims | type == "array")' "${CLAIMS_FILE_ABS}" >/dev/null

claims=()
while IFS= read -r line; do
  claims+=("${line}")
done < <(jq -c '.claims[]' "${CLAIMS_FILE_ABS}")
if [[ "${#claims[@]}" -eq 0 ]]; then
  echo "[claim-gates] no claims found in ${CLAIMS_FILE_ABS}" >&2
  exit 1
fi

failures=0
warnings=0
checked=0

for claim in "${claims[@]}"; do
  id="$(printf '%s' "${claim}" | jq -r '.id')"
  headline="$(printf '%s' "${claim}" | jq -r '.headline')"
  raw_value="$(printf '%s' "${claim}" | jq -r '.value')"
  raw_artifact="$(printf '%s' "${claim}" | jq -r '.artifact_path')"
  query="$(printf '%s' "${claim}" | jq -r '.query')"

  if [[ -z "${id}" || -z "${headline}" || -z "${raw_artifact}" || -z "${query}" ]]; then
    echo "[claim-gates] invalid claim entry detected in ${CLAIMS_FILE_ABS}" >&2
    failures=$((failures + 1))
    continue
  fi

  artifact="${raw_artifact}"
  if [[ "${artifact}" == *"<run_id>"* ]]; then
    if [[ -n "${RUN_ID}" ]]; then
      artifact="${artifact//<run_id>/${RUN_ID}}"
    else
      msg="[claim-gates] ${id}: unresolved <run_id> placeholder"
      if [[ "${STRICT}" -eq 1 ]]; then
        echo "${msg}" >&2
        failures=$((failures + 1))
      else
        echo "${msg} (warning)" >&2
        warnings=$((warnings + 1))
      fi
      continue
    fi
  fi

  artifact_abs="$(resolve_path "${artifact}" "${REPO_ROOT}")"
  if [[ ! -f "${artifact_abs}" ]]; then
    msg="[claim-gates] ${id}: artifact not found: ${artifact_abs}"
    if [[ "${STRICT}" -eq 1 ]]; then
      echo "${msg}" >&2
      failures=$((failures + 1))
    else
      echo "${msg} (warning)" >&2
      warnings=$((warnings + 1))
    fi
    continue
  fi

  computed="$(run_query "${query}" "${artifact_abs}" | trim)"
  if [[ -z "${computed}" ]]; then
    echo "[claim-gates] ${id}: query produced empty output: ${query}" >&2
    failures=$((failures + 1))
    continue
  fi

  checked=$((checked + 1))

  if [[ "${raw_value}" = "TBD" || -z "${raw_value}" ]]; then
    msg="[claim-gates] ${id}: claim value is not finalized (value=${raw_value})"
    if [[ "${STRICT}" -eq 1 ]]; then
      echo "${msg}" >&2
      failures=$((failures + 1))
    else
      echo "${msg} (warning)" >&2
      warnings=$((warnings + 1))
    fi
    continue
  fi

  if ! compare_values "${raw_value}" "${computed}"; then
    echo "[claim-gates] ${id}: value mismatch expected='${raw_value}' computed='${computed}'" >&2
    failures=$((failures + 1))
    continue
  fi

  echo "[claim-gates] ${id}: ok"
done

echo "[claim-gates] checked=${checked} warnings=${warnings} failures=${failures}"
if [[ "${failures}" -gt 0 ]]; then
  exit 1
fi
