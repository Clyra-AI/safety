#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  run_v2.sh [--run-id <id>] [--lane test|full] [--purpose calibration|publication]
            [--targets-file <path>] [--freeze-targets-file <path>] [--max-targets <n>]
            [--mode baseline-only|baseline+enrich] [--detector-list <csv>]
            [--approved-tools <path>] [--production-targets <path>] [--segment-metadata <path>]
            [--regulatory-scope <path>] [--egress-allowlist <path>] [--scan-source repo|clone]
            [--clone-root <path>] [--gold-labels <path>] [--max-runtime-sec <n>] [--max-run-disk-mb <n>]
            [--purge-clones-after-scan|--keep-clones] [--publish-validate] [--resume] [--dry-run]
            [--min-pushed <YYYY-MM-DD>] [--pages <n>] [--per-page <n>] [--max-size-kb <n>]

Executes the v2 sprawl lane end to end:
  1. generate or use a v2 target list
  2. run the baseline scan engine
  3. rebuild v2 campaign and appendix artifacts
  4. generate calibration artifacts
  5. validate the run in test or full mode
USAGE
}

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUN_ID="${RUN_ID:-}"
LANE="test"
PURPOSE=""
TARGETS_FILE=""
FREEZE_TARGETS_FILE=""
MAX_TARGETS=""
MODE="baseline-only"
DETECTOR_LIST="${WRKR_DETECTORS:-default}"
APPROVED_TOOLS_POLICY="pipelines/policies/approved-tools.v1.yaml"
PRODUCTION_TARGETS_POLICY="pipelines/policies/production-targets.v1.yaml"
SEGMENT_METADATA_POLICY="pipelines/policies/campaign-segments.v1.yaml"
REGULATORY_SCOPE_POLICY="pipelines/policies/regulatory-scope.v1.json"
EGRESS_ALLOWLIST="pipelines/policies/sprawl-egress-allowlist.txt"
SCAN_SOURCE="${SCAN_SOURCE:-clone}"
CLONE_ROOT="${CLONE_ROOT:-}"
GOLD_LABELS=""
MAX_RUNTIME_SEC=""
MAX_RUN_DISK_MB=""
PURGE_CLONES_AFTER_SCAN=""
PUBLISH_VALIDATE=0
RESUME=0
DRY_RUN=0
MIN_PUSHED=""
PAGES=""
PER_PAGE=""
MAX_SIZE_KB=""

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
    --purpose)
      PURPOSE="${2:-}"
      shift 2
      ;;
    --targets-file)
      TARGETS_FILE="${2:-}"
      shift 2
      ;;
    --freeze-targets-file)
      FREEZE_TARGETS_FILE="${2:-}"
      shift 2
      ;;
    --max-targets)
      MAX_TARGETS="${2:-}"
      shift 2
      ;;
    --mode)
      MODE="${2:-}"
      shift 2
      ;;
    --detector-list)
      DETECTOR_LIST="${2:-}"
      shift 2
      ;;
    --approved-tools)
      APPROVED_TOOLS_POLICY="${2:-}"
      shift 2
      ;;
    --production-targets)
      PRODUCTION_TARGETS_POLICY="${2:-}"
      shift 2
      ;;
    --segment-metadata)
      SEGMENT_METADATA_POLICY="${2:-}"
      shift 2
      ;;
    --regulatory-scope)
      REGULATORY_SCOPE_POLICY="${2:-}"
      shift 2
      ;;
    --egress-allowlist)
      EGRESS_ALLOWLIST="${2:-}"
      shift 2
      ;;
    --scan-source)
      SCAN_SOURCE="${2:-}"
      shift 2
      ;;
    --clone-root)
      CLONE_ROOT="${2:-}"
      shift 2
      ;;
    --gold-labels)
      GOLD_LABELS="${2:-}"
      shift 2
      ;;
    --max-runtime-sec)
      MAX_RUNTIME_SEC="${2:-}"
      shift 2
      ;;
    --max-run-disk-mb)
      MAX_RUN_DISK_MB="${2:-}"
      shift 2
      ;;
    --purge-clones-after-scan)
      PURGE_CLONES_AFTER_SCAN="1"
      shift
      ;;
    --keep-clones)
      PURGE_CLONES_AFTER_SCAN="0"
      shift
      ;;
    --publish-validate)
      PUBLISH_VALIDATE=1
      shift
      ;;
    --resume)
      RESUME=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --min-pushed)
      MIN_PUSHED="${2:-}"
      shift 2
      ;;
    --pages)
      PAGES="${2:-}"
      shift 2
      ;;
    --per-page)
      PER_PAGE="${2:-}"
      shift 2
      ;;
    --max-size-kb)
      MAX_SIZE_KB="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[sprawl-run-v2] unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "${RUN_ID}" ]]; then
  RUN_ID="sprawl-v2-$(date -u +%Y%m%dT%H%M%SZ)"
fi
if [[ "${LANE}" != "test" && "${LANE}" != "full" ]]; then
  echo "[sprawl-run-v2] --lane must be test or full" >&2
  exit 1
fi
if [[ -z "${PURPOSE}" ]]; then
  if [[ "${LANE}" == "test" ]]; then
    PURPOSE="calibration"
  else
    PURPOSE="publication"
  fi
fi
if [[ "${PURPOSE}" != "calibration" && "${PURPOSE}" != "publication" ]]; then
  echo "[sprawl-run-v2] --purpose must be calibration or publication" >&2
  exit 1
fi
if [[ "${PUBLISH_VALIDATE}" -eq 1 && "${LANE}" != "full" ]]; then
  echo "[sprawl-run-v2] --publish-validate is only supported in --lane full" >&2
  exit 1
fi
if [[ -z "${MAX_TARGETS}" ]]; then
  if [[ "${LANE}" == "test" ]]; then
    MAX_TARGETS="50"
  else
    MAX_TARGETS="1000"
  fi
fi
if [[ -z "${MAX_RUNTIME_SEC}" ]]; then
  if [[ "${LANE}" == "test" ]]; then
    MAX_RUNTIME_SEC="1800"
  else
    MAX_RUNTIME_SEC="86400"
  fi
fi
if [[ -z "${MAX_RUN_DISK_MB}" ]]; then
  if [[ "${LANE}" == "test" ]]; then
    MAX_RUN_DISK_MB="4096"
  else
    MAX_RUN_DISK_MB="12288"
  fi
fi
if [[ -z "${PURGE_CLONES_AFTER_SCAN}" ]]; then
  if [[ "${LANE}" == "full" && "${SCAN_SOURCE}" == "clone" ]]; then
    PURGE_CLONES_AFTER_SCAN="1"
  else
    PURGE_CLONES_AFTER_SCAN="0"
  fi
fi

RUN_DIR="${REPO_ROOT}/runs/tool-sprawl/${RUN_ID}"
ARTIFACTS_DIR="${RUN_DIR}/artifacts"
CALIBRATION_DIR="${RUN_DIR}/calibration"
RUN_DIR_PREEXISTED=0
if [[ -d "${RUN_DIR}" ]]; then
  RUN_DIR_PREEXISTED=1
fi

if [[ "${RUN_DIR_PREEXISTED}" -eq 1 && "${RESUME}" -eq 0 ]]; then
  echo "[sprawl-run-v2] run directory already exists: ${RUN_DIR}" >&2
  echo "[sprawl-run-v2] choose a new --run-id or use --resume." >&2
  exit 1
fi

check_v2_prereg() {
  local prereg="${REPO_ROOT}/reports/ai-tool-sprawl-v2-2026/preregistration.md"
  if [[ ! -f "${prereg}" ]]; then
    echo "[sprawl-run-v2] missing v2 preregistration: ${prereg}" >&2
    exit 1
  fi
  if [[ "${LANE}" == "full" ]]; then
    if grep -Eq 'Locked by: `TBD`|Locked at \(UTC\): `TBD`|Notes: `TBD`' "${prereg}"; then
      echo "[sprawl-run-v2] full lane requires a finalized v2 preregistration lock record" >&2
      exit 1
    fi
  fi
}

resolve_path() {
  local path="$1"
  if [[ "${path}" == /* ]]; then
    printf '%s\n' "${path}"
  else
    printf '%s\n' "${REPO_ROOT}/${path}"
  fi
}

build_clean_env_args() {
  local name value
  CLEAN_ENV_ARGS=()
  while IFS='=' read -r name value; do
    [[ -z "${value}" ]] && continue
    if [[ "${name}" =~ _API_KEY$ || "${name}" == "AWS_ACCESS_KEY_ID" || "${name}" == "AWS_SECRET_ACCESS_KEY" ]]; then
      CLEAN_ENV_ARGS+=("-u" "${name}")
    fi
  done < <(env)
}

check_v2_prereg
build_clean_env_args
WRKR_GITHUB_API_BASE_VALUE="${WRKR_GITHUB_API_BASE:-https://api.github.com}"
WRKR_GITHUB_TOKEN_VALUE="${WRKR_GITHUB_TOKEN:-${GH_TOKEN:-${GITHUB_TOKEN:-}}}"
WRKR_GITHUB_TOKEN_MODE_VALUE="${WRKR_GITHUB_TOKEN_MODE:-}"
if [[ -z "${WRKR_GITHUB_TOKEN_VALUE}" ]] && command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then
    WRKR_GITHUB_TOKEN_VALUE="$(gh auth token 2>/dev/null || true)"
  fi
fi
if [[ -n "${WRKR_GITHUB_TOKEN_VALUE}" && -z "${WRKR_GITHUB_TOKEN_MODE_VALUE}" ]]; then
  WRKR_GITHUB_TOKEN_MODE_VALUE="read-only"
fi

if [[ -z "${TARGETS_FILE}" ]]; then
  TARGETS_FILE="runs/tool-sprawl/${RUN_ID}/artifacts/targets-${PURPOSE}.md"
  TARGETS_CATALOG="runs/tool-sprawl/${RUN_ID}/artifacts/targets-${PURPOSE}.csv"
  gen_cmd=(
    "${REPO_ROOT}/pipelines/sprawl/generate_targets_v2.sh"
    --purpose "${PURPOSE}"
    --total "${MAX_TARGETS}"
    --output "${TARGETS_FILE}"
    --catalog "${TARGETS_CATALOG}"
  )
  [[ -n "${MIN_PUSHED}" ]] && gen_cmd+=(--min-pushed "${MIN_PUSHED}")
  [[ -n "${PAGES}" ]] && gen_cmd+=(--pages "${PAGES}")
  [[ -n "${PER_PAGE}" ]] && gen_cmd+=(--per-page "${PER_PAGE}")
  [[ -n "${MAX_SIZE_KB}" ]] && gen_cmd+=(--max-size-kb "${MAX_SIZE_KB}")
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "[sprawl-run-v2] dry-run would generate targets via: ${gen_cmd[*]}"
  else
    "${gen_cmd[@]}"
  fi

  if [[ -n "${FREEZE_TARGETS_FILE}" ]]; then
    freeze_abs="$(resolve_path "${FREEZE_TARGETS_FILE}")"
    mkdir -p "$(dirname "${freeze_abs}")"
    if [[ "${DRY_RUN}" -eq 1 ]]; then
      echo "[sprawl-run-v2] dry-run would freeze generated targets to ${freeze_abs}"
    else
      cp "$(resolve_path "${TARGETS_FILE}")" "${freeze_abs}"
    fi
  fi
fi

TARGETS_FILE_ABS="$(resolve_path "${TARGETS_FILE}")"
if [[ ! -f "${TARGETS_FILE_ABS}" && "${DRY_RUN}" -eq 0 ]]; then
  echo "[sprawl-run-v2] targets file not found: ${TARGETS_FILE_ABS}" >&2
  exit 1
fi

WRKR_BIN_PATH="${WRKR_BIN:-}"
if [[ -z "${WRKR_BIN_PATH}" ]]; then
  WRKR_BIN_PATH="${RUN_DIR}/artifacts/wrkr-v2-bin"
fi
if [[ "${DRY_RUN}" -eq 0 && ! -x "${WRKR_BIN_PATH}" ]]; then
  mkdir -p "${ARTIFACTS_DIR}"
  if [[ -f "${REPO_ROOT}/third_party/wrkr/cmd/wrkr/main.go" ]] && command -v go >/dev/null 2>&1; then
    (cd "${REPO_ROOT}/third_party/wrkr" && go build -o "${WRKR_BIN_PATH}" ./cmd/wrkr)
  fi
fi

BASE_RUN_RESUME="${RESUME}"
if [[ "${RUN_DIR_PREEXISTED}" -eq 0 && ( "${TARGETS_FILE}" == runs/tool-sprawl/${RUN_ID}/* || "${WRKR_BIN_PATH}" == "${RUN_DIR}"/* ) ]]; then
  BASE_RUN_RESUME=1
fi

base_run_cmd=(
  "${REPO_ROOT}/pipelines/sprawl/run.sh"
  --run-id "${RUN_ID}"
  --mode "${MODE}"
  --targets-file "${TARGETS_FILE}"
  --max-targets "${MAX_TARGETS}"
  --detector-list "${DETECTOR_LIST}"
  --approved-tools "${APPROVED_TOOLS_POLICY}"
  --production-targets "${PRODUCTION_TARGETS_POLICY}"
  --segment-metadata "${SEGMENT_METADATA_POLICY}"
  --regulatory-scope "${REGULATORY_SCOPE_POLICY}"
  --egress-allowlist "${EGRESS_ALLOWLIST}"
  --max-runtime-sec "${MAX_RUNTIME_SEC}"
  --max-run-disk-mb "${MAX_RUN_DISK_MB}"
  --scan-source "${SCAN_SOURCE}"
  --no-synthetic-fallback
)
[[ "${BASE_RUN_RESUME}" -eq 1 ]] && base_run_cmd+=(--resume)
[[ "${DRY_RUN}" -eq 1 ]] && base_run_cmd+=(--dry-run)
[[ -n "${CLONE_ROOT}" ]] && base_run_cmd+=(--clone-root "${CLONE_ROOT}")
[[ "${PURGE_CLONES_AFTER_SCAN}" == "1" ]] && base_run_cmd+=(--purge-clones-after-scan)

if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "[sprawl-run-v2] dry-run lane=${LANE} purpose=${PURPOSE} run_id=${RUN_ID}"
  echo "[sprawl-run-v2] targets_file=${TARGETS_FILE}"
  echo "[sprawl-run-v2] wrkr_bin=${WRKR_BIN_PATH}"
  echo "[sprawl-run-v2] max_runtime_sec=${MAX_RUNTIME_SEC} max_run_disk_mb=${MAX_RUN_DISK_MB} purge_clones_after_scan=${PURGE_CLONES_AFTER_SCAN}"
  echo "[sprawl-run-v2] base scan command: ${base_run_cmd[*]}"
  echo "[sprawl-run-v2] post-run steps:"
  echo "  - rebuild_from_scans_v2.sh --run-id ${RUN_ID}"
  echo "  - calibrate_detectors_v2.sh --run-id ${RUN_ID}"
  if [[ "${PUBLISH_VALIDATE}" -eq 1 ]]; then
    echo "  - validate_v2.sh --run-id ${RUN_ID} --lane ${LANE} --strict"
  else
    echo "  - validate_v2.sh --run-id ${RUN_ID} --lane ${LANE}"
  fi
  exit 0
fi

base_env_cmd=(env "${CLEAN_ENV_ARGS[@]}" "WRKR_GITHUB_API_BASE=${WRKR_GITHUB_API_BASE_VALUE}")
if [[ -n "${WRKR_GITHUB_TOKEN_VALUE}" ]]; then
  base_env_cmd+=("WRKR_GITHUB_TOKEN=${WRKR_GITHUB_TOKEN_VALUE}" "WRKR_GITHUB_TOKEN_MODE=${WRKR_GITHUB_TOKEN_MODE_VALUE}")
fi
if [[ -x "${WRKR_BIN_PATH}" ]]; then
  base_env_cmd+=("WRKR_BIN=${WRKR_BIN_PATH}")
fi
"${base_env_cmd[@]}" "${base_run_cmd[@]}"

"${REPO_ROOT}/pipelines/sprawl/rebuild_from_scans_v2.sh" \
  --run-id "${RUN_ID}" \
  --targets-file "${TARGETS_FILE}" \
  --mode "${MODE}" \
  --detector-list "${DETECTOR_LIST}"

calibrate_cmd=(
  "${REPO_ROOT}/pipelines/sprawl/calibrate_detectors_v2.sh"
  --run-id "${RUN_ID}"
  --out-dir "runs/tool-sprawl/${RUN_ID}/calibration"
)
[[ -n "${GOLD_LABELS}" ]] && calibrate_cmd+=(--gold-labels "${GOLD_LABELS}")
"${calibrate_cmd[@]}"

if [[ -f "${RUN_DIR}/artifacts/run-manifest.json" ]]; then
  jq -n \
    --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg lane "${LANE}" \
    --arg purpose "${PURPOSE}" \
    --arg targets_file "${TARGETS_FILE}" \
    --arg target_catalog "${TARGETS_CATALOG:-}" \
    --arg campaign_summary "runs/tool-sprawl/${RUN_ID}/agg/campaign-summary-v2.json" \
    --arg appendix "runs/tool-sprawl/${RUN_ID}/appendix/combined-appendix-v2.json" \
    --arg calibration_cov "runs/tool-sprawl/${RUN_ID}/calibration/detector-coverage-summary-v2.json" \
    --arg calibration_eval "runs/tool-sprawl/${RUN_ID}/calibration/gold-label-evaluation-v2.json" \
    --arg claim_values "runs/tool-sprawl/${RUN_ID}/artifacts/claim-values-v2.json" \
    --arg threshold_eval "runs/tool-sprawl/${RUN_ID}/artifacts/threshold-evaluation-v2.json" \
    --arg source_manifest "runs/tool-sprawl/${RUN_ID}/artifacts/run-manifest.json" \
    --arg validation_mode "$(if [[ "${PUBLISH_VALIDATE}" -eq 1 ]]; then printf '%s' "strict"; else printf '%s' "relaxed"; fi)" \
    --slurpfile base "${RUN_DIR}/artifacts/run-manifest.json" '
    ($base[0] // {}) as $b |
    {
      schema_version: "v2",
      report_id: "ai-tool-sprawl-v2-2026",
      run_id: ($b.run_id // null),
      created_at: $generated_at,
      status: "completed",
      lane: $lane,
      validation_mode: $validation_mode,
      cohort_purpose: $purpose,
      source_manifest: $source_manifest,
      reproducibility: ($b.reproducibility // {}),
      operational_guardrails: ($b.operational_guardrails // {}),
      inputs: {
        targets_file: $targets_file,
        target_catalog: (if $target_catalog == "" then null else $target_catalog end)
      },
      artifacts: {
        campaign_summary: $campaign_summary,
        appendix: $appendix,
        calibration_summary: $calibration_cov,
        calibration_evaluation: $calibration_eval,
        claim_values: $claim_values,
        threshold_evaluation: $threshold_eval
      }
    }
  ' > "${RUN_DIR}/artifacts/run-manifest-v2.json"
fi

validate_cmd=(
  "${REPO_ROOT}/pipelines/sprawl/validate_v2.sh"
  --run-id "${RUN_ID}"
  --lane "${LANE}"
)
if [[ "${PUBLISH_VALIDATE}" -eq 1 ]]; then
  validate_cmd+=(--strict)
fi
"${validate_cmd[@]}"

echo "[sprawl-run-v2] completed run ${RUN_ID}"
echo "[sprawl-run-v2] v2 manifest: ${RUN_DIR}/artifacts/run-manifest-v2.json"
echo "[sprawl-run-v2] campaign summary: ${RUN_DIR}/agg/campaign-summary-v2.json"
