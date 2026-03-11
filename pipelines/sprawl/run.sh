#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  run.sh [--run-id <id>] [--resume] [--dry-run] [--mode baseline-only|baseline+enrich]
         [--targets-file <path>] [--max-targets <n>] [--max-runtime-sec <n>] [--max-run-disk-mb <n>]
         [--detector-list <csv>] [--approved-tools <path>] [--production-targets <path>] [--segment-metadata <path>]
         [--regulatory-scope <path>] [--egress-allowlist <path>] [--scan-source repo|clone] [--clone-root <path>]
         [--purge-clones-after-scan] [--no-synthetic-fallback]

Creates immutable run layout and executes Wrkr sprawl scans:
  runs/tool-sprawl/<run_id>/{wrkr-state,wrkr-state-enrich,states,states-enrich,scans,agg,appendix,artifacts}
USAGE
}

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUN_ID="${RUN_ID:-}"
RESUME=0
DRY_RUN=0
MODE="baseline-only"
TARGETS_FILE="internal/repos.md"
MAX_TARGETS="500"
MAX_RUNTIME_SEC="1800"
MAX_RUN_DISK_MB="4096"
DETECTOR_LIST="${WRKR_DETECTORS:-default}"
APPROVED_TOOLS_POLICY="pipelines/policies/approved-tools.v1.yaml"
PRODUCTION_TARGETS_POLICY="pipelines/policies/production-targets.v1.yaml"
SEGMENT_METADATA_POLICY="pipelines/policies/campaign-segments.v1.yaml"
REGULATORY_SCOPE_POLICY="pipelines/policies/regulatory-scope.v1.json"
EGRESS_ALLOWLIST="pipelines/policies/sprawl-egress-allowlist.txt"
SCAN_SOURCE="${SCAN_SOURCE:-repo}"
CLONE_ROOT="${CLONE_ROOT:-}"
PURGE_CLONES_AFTER_SCAN=0
ALLOW_SYNTHETIC_FALLBACK=1

WRKR_REPO_PATH="${WRKR_REPO_PATH:-${REPO_ROOT}/third_party/wrkr}"
WRKR_RUNTIME="unavailable"
RUN_START_EPOCH="$(date +%s)"

sha256_cmd() {
  if command -v sha256sum >/dev/null 2>&1; then
    echo "sha256sum"
  elif command -v shasum >/dev/null 2>&1; then
    echo "shasum -a 256"
  else
    echo ""
  fi
}

file_sha256() {
  local file="$1"
  local hasher
  hasher="$(sha256_cmd)"
  if [[ -z "${hasher}" || ! -f "${file}" ]]; then
    echo "unavailable"
    return
  fi
  # shellcheck disable=SC2086
  ${hasher} "${file}" | awk '{print $1}'
}

dir_sha256() {
  local dir="$1"
  local exclude_prefix="${2:-}"
  if [[ ! -d "${dir}" ]]; then
    echo "unavailable"
    return
  fi
  if command -v sha256sum >/dev/null 2>&1; then
    if [[ -n "${exclude_prefix}" ]]; then
      (
        cd "${dir}" &&
        find . -type f ! -path "./${exclude_prefix}" ! -path "./${exclude_prefix}/*" -print0 |
          LC_ALL=C sort -z |
          xargs -0 sha256sum |
          sha256sum | awk '{print $1}'
      )
    else
      (
        cd "${dir}" &&
        find . -type f -print0 |
          LC_ALL=C sort -z |
          xargs -0 sha256sum |
          sha256sum | awk '{print $1}'
      )
    fi
  elif command -v shasum >/dev/null 2>&1; then
    if [[ -n "${exclude_prefix}" ]]; then
      (
        cd "${dir}" &&
        find . -type f ! -path "./${exclude_prefix}" ! -path "./${exclude_prefix}/*" -print0 |
          LC_ALL=C sort -z |
          xargs -0 shasum -a 256 |
          shasum -a 256 | awk '{print $1}'
      )
    else
      (
        cd "${dir}" &&
        find . -type f -print0 |
          LC_ALL=C sort -z |
          xargs -0 shasum -a 256 |
          shasum -a 256 | awk '{print $1}'
      )
    fi
  else
    echo "unavailable"
  fi
}

assert_runtime_budget() {
  local now elapsed
  now="$(date +%s)"
  elapsed=$((now - RUN_START_EPOCH))
  if (( elapsed > MAX_RUNTIME_SEC )); then
    echo "[sprawl-run] runtime cap exceeded (${elapsed}s > ${MAX_RUNTIME_SEC}s)" >&2
    exit 1
  fi
}

check_disk_quota() {
  local run_dir="$1"
  if [[ ! -d "${run_dir}" ]]; then
    return
  fi
  local used_mb
  used_mb="$(du -sm "${run_dir}" | awk '{print $1}')"
  if [[ -n "${used_mb}" && "${used_mb}" =~ ^[0-9]+$ ]] && (( used_mb > MAX_RUN_DISK_MB )); then
    echo "[sprawl-run] disk quota exceeded (${used_mb}MB > ${MAX_RUN_DISK_MB}MB)" >&2
    exit 1
  fi
}

safe_git_sha() {
  local repo="$1"
  if [[ -d "${repo}/.git" ]] && command -v git >/dev/null 2>&1; then
    git -C "${repo}" rev-parse HEAD 2>/dev/null || echo "unavailable"
  else
    echo "unavailable"
  fi
}

safe_git_ref() {
  local repo="$1"
  if [[ -d "${repo}/.git" ]] && command -v git >/dev/null 2>&1; then
    git -C "${repo}" describe --tags --always --dirty 2>/dev/null || echo "unavailable"
  else
    echo "unavailable"
  fi
}

normalize_path_ref() {
  local path="$1"
  if [[ -z "${path}" ]]; then
    printf '%s\n' "${path}"
    return
  fi
  if [[ "${path}" == "${REPO_ROOT}" ]]; then
    printf '.\n'
    return
  fi
  if [[ "${path}" == "${REPO_ROOT}/"* ]]; then
    printf '%s\n' "${path#${REPO_ROOT}/}"
    return
  fi
  if [[ "${path}" == /* ]]; then
    printf 'external:%s\n' "${path##*/}"
    return
  fi
  printf '%s\n' "${path}"
}

normalize_runtime_ref() {
  local runtime="$1"
  if [[ "${runtime}" == go-run:* ]]; then
    printf 'go-run:%s\n' "$(normalize_path_ref "${runtime#go-run:}")"
    return
  fi
  if [[ "${runtime}" == /* ]]; then
    normalize_path_ref "${runtime}"
    return
  fi
  printf '%s\n' "${runtime}"
}

is_valid_json_file() {
  local file="$1"
  [[ -s "${file}" ]] || return 1
  jq -e . "${file}" >/dev/null 2>&1
}

clone_repo_with_retry() {
  local target="$1"
  local source_path="$2"
  local err_path="$3"
  local attempt
  mkdir -p "$(dirname "${source_path}")"
  for attempt in 1 2 3 4 5; do
    if [[ -d "${source_path}/.git" ]]; then
      return 0
    fi
    rm -rf "${source_path}"
    : > "${err_path}"
    if git clone --quiet --depth 1 "https://github.com/${target}.git" "${source_path}" >/dev/null 2>"${err_path}"; then
      if [[ ! -s "${err_path}" ]]; then
        rm -f "${err_path}"
      fi
      return 0
    fi
    sleep $((attempt * 2))
  done
  return 1
}

detect_wrkr_runtime() {
  if [[ -n "${WRKR_BIN:-}" && -x "${WRKR_BIN}" ]]; then
    WRKR_RUNTIME="${WRKR_BIN}"
  elif [[ -f "${WRKR_REPO_PATH}/cmd/wrkr/main.go" ]] && command -v go >/dev/null 2>&1; then
    WRKR_RUNTIME="go-run:${WRKR_REPO_PATH}"
  elif command -v wrkr >/dev/null 2>&1; then
    WRKR_RUNTIME="$(command -v wrkr)"
  fi

  if [[ "${WRKR_RUNTIME}" != "unavailable" ]] && ! run_wrkr scan --help >/dev/null 2>&1; then
    if [[ -f "${WRKR_REPO_PATH}/cmd/wrkr/main.go" ]] && command -v go >/dev/null 2>&1; then
      WRKR_RUNTIME="go-run:${WRKR_REPO_PATH}"
    else
      WRKR_RUNTIME="unavailable"
    fi
  fi
}

run_wrkr() {
  case "${WRKR_RUNTIME}" in
    unavailable)
      return 127
      ;;
    go-run:*)
      (cd "${WRKR_REPO_PATH}" && go run ./cmd/wrkr "$@")
      ;;
    *)
      "${WRKR_RUNTIME}" "$@"
      ;;
  esac
}

capture_wrkr_version() {
  local v
  v="$(run_wrkr --json 2>/dev/null | jq -r '.version // .build.version // .tag // empty' | head -n1 || true)"
  if [[ -n "${v}" ]]; then
    echo "${v}"
    return
  fi
  v="$(run_wrkr version --json 2>/dev/null | jq -r '.version // .tag // empty' | head -n1 || true)"
  if [[ -n "${v}" ]]; then
    echo "${v}"
    return
  fi
  v="$(run_wrkr version 2>/dev/null | head -n1 || true)"
  if [[ -n "${v}" ]]; then
    echo "${v}"
    return
  fi
  echo "unavailable"
}

check_prereg_lock() {
  local prereg="${REPO_ROOT}/reports/ai-tool-sprawl-q1-2026/preregistration.md"
  if [[ ! -f "${prereg}" ]]; then
    echo "[sprawl-run] missing preregistration: ${prereg}" >&2
    exit 1
  fi
  if grep -Eq 'Locked by: `TBD`|Locked at \(UTC\): `TBD`|Notes: `TBD`' "${prereg}"; then
    echo "[sprawl-run] preregistration lock record is not finalized" >&2
    exit 1
  fi
}

check_secret_guardrails() {
  if [[ "${ALLOW_EXTERNAL_SECRETS:-0}" == "1" ]]; then
    return
  fi
  local found_model_keys=0
  local found_cloud_keys=0
  local matched=()
  local var_name value
  while IFS='=' read -r var_name value; do
    [[ -z "${value}" ]] && continue
    if [[ "${var_name}" =~ _API_KEY$ ]]; then
      matched+=("${var_name}")
      found_model_keys=1
      continue
    fi
    if [[ "${var_name}" == "AWS_ACCESS_KEY_ID" || "${var_name}" == "AWS_SECRET_ACCESS_KEY" ]]; then
      matched+=("${var_name}")
      found_cloud_keys=1
    fi
  done < <(env)

  if (( found_model_keys == 1 || found_cloud_keys == 1 )); then
    if (( found_model_keys == 1 )); then
      echo "[sprawl-run] blocked by guardrail: external_model_api_key_present (${matched[*]}). Use ALLOW_EXTERNAL_SECRETS=1 only for explicit lab exceptions." >&2
    else
      echo "[sprawl-run] blocked by guardrail: external_cloud_credential_present (${matched[*]}). Use ALLOW_EXTERNAL_SECRETS=1 only for explicit lab exceptions." >&2
    fi
    exit 1
  fi
}

check_token_guardrails() {
  if [[ -n "${WRKR_GITHUB_TOKEN:-}" && "${WRKR_GITHUB_TOKEN_MODE:-}" != "read-only" ]]; then
    echo "[sprawl-run] WRKR_GITHUB_TOKEN is set but WRKR_GITHUB_TOKEN_MODE is not 'read-only'" >&2
    exit 1
  fi
}

check_egress_allowlist() {
  local list_path="$1"
  local api_base host
  api_base="${WRKR_GITHUB_API_BASE:-https://api.github.com}"
  host="$(printf '%s' "${api_base}" | sed -E 's#^[a-zA-Z]+://##; s#/.*$##')"

  if [[ ! -f "${list_path}" ]]; then
    echo "[sprawl-run] missing egress allowlist file: ${list_path}" >&2
    exit 1
  fi

  if ! grep -E -v '^[[:space:]]*(#|$)' "${list_path}" | awk '{$1=$1;print}' | grep -Fxq "${host}"; then
    echo "[sprawl-run] api host '${host}' is not permitted by egress allowlist ${list_path}" >&2
    exit 1
  fi
}

parse_targets() {
  local file="$1"
  local line
  if [[ ! -f "${file}" ]]; then
    return
  fi
  while IFS= read -r line; do
    line="${line%%#*}"
    line="$(printf '%s' "${line}" | awk '{$1=$1;print}')"
    [[ -z "${line}" ]] && continue
    echo "${line}"
  done < "${file}"
}

slugify() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr '/:' '-' | tr -cs 'a-z0-9._-' '-'
}

synthetic_seed() {
  local target="$1"
  local hash
  if command -v sha256sum >/dev/null 2>&1; then
    hash="$(printf '%s' "${target}" | sha256sum | awk '{print $1}')"
  else
    hash="$(printf '%s' "${target}" | shasum -a 256 | awk '{print $1}')"
  fi
  printf '%s\n' "$((16#${hash:0:8}))"
}

write_synthetic_scan() {
  local target="$1"
  local scan_path="$2"
  local seed tools approved unapproved unknown prod
  seed="$(synthetic_seed "${target}")"

  tools=$((6 + (seed % 12)))
  approved=$((seed % 4))
  if (( approved > tools )); then approved=${tools}; fi
  unapproved=$(((tools - approved) / 2 + (seed % 2)))
  if (( unapproved > tools - approved )); then unapproved=$((tools - approved)); fi
  unknown=$((tools - approved - unapproved))
  prod=$((seed % 3))

  jq -n \
    --arg target "${target}" \
    --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --argjson tools_detected "${tools}" \
    --argjson approved_tools "${approved}" \
    --argjson unapproved_tools "${unapproved}" \
    --argjson unknown_tools "${unknown}" \
    --argjson production_write_tools "${prod}" \
    '{
      schema_version: "v1",
      status: "synthetic-preflight",
      target: $target,
      generated_at: $generated_at,
      inventory: {
        tools_detected: $tools_detected,
        approved_tools: $approved_tools,
        unapproved_tools: $unapproved_tools,
        unknown_tools: $unknown_tools,
        production_write_tools: $production_write_tools
      }
    }' > "${scan_path}"
}

write_failed_scan() {
  local target="$1"
  local scan_path="$2"
  local err_path="$3"
  local phase="$4"
  local stderr_excerpt=""
  if [[ -f "${err_path}" ]]; then
    stderr_excerpt="$(tail -n 40 "${err_path}" 2>/dev/null || true)"
  fi

  jq -n \
    --arg target "${target}" \
    --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg phase "${phase}" \
    --arg stderr_log "${err_path}" \
    --arg stderr_excerpt "${stderr_excerpt}" \
    '{
      schema_version: "v1",
      status: "scan-failed",
      target: $target,
      generated_at: $generated_at,
      failure: {
        phase: $phase,
        stderr_log: $stderr_log,
        stderr_excerpt: $stderr_excerpt
      },
      inventory: {
        tools_detected: 0,
        approved_tools: 0,
        unapproved_tools: 0,
        unknown_tools: 0,
        production_write_tools: 0,
        tools: []
      }
    }' > "${scan_path}"
}

write_state_from_scan() {
  local target="$1"
  local scan_path="$2"
  local state_path="$3"
  local source_label="$4"
  local org repo
  org="${target%%/*}"
  repo="${target#*/}"
  if [[ "${org}" == "${repo}" ]]; then
    repo="unknown"
  fi

  jq -n --slurpfile scan "${scan_path}" \
    --slurpfile regscope "${REPO_ROOT}/${REGULATORY_SCOPE_POLICY}" \
    --arg target "${target}" \
    --arg org "${org}" \
    --arg repo "${repo}" \
    --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg source "${source_label}" \
    --arg scan_path "${scan_path}" \
    '
      ($scan[0] // {}) as $s |
      ($s.inventory.tools // []) as $tools |
      ($tools | map(select((.tool_type // "") != "source_repo"))) as $scoped |
      ($s.profile.failing_rules // []) as $failing_rules |
      ($regscope[0] // {}) as $regscope_policy |
      ($regscope_policy.defaults // {}) as $regscope_defaults |
      ($regscope_policy.orgs // {}) as $regscope_orgs |
      ($regscope_orgs[$org] // {}) as $regscope_org |

      def to_num($v):
        if ($v | type) == "number" then $v
        elif ($v | type) == "string" and ($v | test("^[0-9]+$")) then ($v | tonumber)
        else 0 end;

      def risky:
        ((.permission_surface.write // false) == true)
        or ((.permission_surface.admin // false) == true)
        or (((.permissions // []) | index("proc.exec")) != null);

      def has_fail($rule): (($failing_rules | index($rule)) != null);
      def approval_class: (.approval_classification // "unknown");
      def approval_status_norm: ((.approval_status // "missing") | tostring | ascii_downcase);
      def is_approval_unknown:
        (approval_class != "approved" and approval_class != "unapproved")
        or (approval_class == "unapproved" and (approval_status_norm == "missing" or approval_status_norm == "unknown" or approval_status_norm == "null" or approval_status_norm == ""));
      def is_explicit_unapproved:
        (approval_class == "unapproved") and (is_approval_unknown | not);
      def scope_flag($key; $fallback):
        if (($regscope_org[$key] | type) == "boolean") then $regscope_org[$key]
        elif (($regscope_defaults[$key] | type) == "boolean") then $regscope_defaults[$key]
        else $fallback
        end;
      def median($arr):
        if ($arr | length) == 0 then 0
        else
          ($arr | sort) as $s
          | ($s | length) as $l
          | if ($l % 2) == 1
            then $s[($l / 2 | floor)]
            else (($s[($l / 2) - 1] + $s[($l / 2)]) / 2)
            end
        end;

      ($tools | length) as $tool_array_len |
      (if $tool_array_len > 0
        then $tool_array_len
        else to_num($s.inventory.tools_detected // $s.inventory.total_tools // $s.inventory.summary.total // 0)
       end) as $raw_total |
      (if $tool_array_len > 0
        then ($tools | map(select(approval_class == "approved")) | length)
        else to_num($s.inventory.approved_tools // $s.inventory.approval.approved // $s.inventory.approval_counts.approved // 0)
       end) as $raw_approved |
      (if $tool_array_len > 0
        then ($tools | map(select(is_explicit_unapproved)) | length)
        else to_num($s.inventory.unapproved_tools // $s.inventory.approval.unapproved // $s.inventory.approval_counts.unapproved // 0)
       end) as $raw_explicit_unapproved |
      (if $tool_array_len > 0
        then ($tools | map(select(is_approval_unknown)) | length)
        else to_num($s.inventory.unknown_tools // $s.inventory.approval.unknown // $s.inventory.approval_counts.unknown // 0)
       end) as $raw_approval_unknown |
      (if $tool_array_len > 0
        then ($tools | map(select(approval_class != "approved" and approval_class != "unapproved")) | length)
        else to_num($s.inventory.unknown_tools // $s.inventory.approval.unknown // $s.inventory.approval_counts.unknown // 0)
       end) as $raw_unknown_legacy |
      (if $tool_array_len > 0
        then ($tools | map(select((.tool_type // "") == "source_repo")) | length)
        else 0
       end) as $source_repo_tools |

      (if $tool_array_len > 0 then ($scoped | length) else $raw_total end) as $scoped_total |
      (if $tool_array_len > 0
        then ($scoped | map(select(approval_class == "approved")) | length)
        else $raw_approved
       end) as $scoped_approved |
      (if $tool_array_len > 0
        then ($scoped | map(select(is_explicit_unapproved)) | length)
        else $raw_explicit_unapproved
       end) as $scoped_explicit_unapproved |
      (if $tool_array_len > 0
        then ($scoped | map(select(is_approval_unknown)) | length)
        else $raw_approval_unknown
       end) as $scoped_approval_unknown |
      (if $tool_array_len > 0
        then ($scoped | map(select(approval_class != "approved" and approval_class != "unapproved")) | length)
        else $raw_unknown_legacy
       end) as $scoped_unknown_legacy |

      ($scoped | map(select(risky))) as $risky_scoped |
      (($scoped | map(select((.tool_type // "") == "prompt_channel")) | length) > 0 or has_fail("WRKR-016")) as $prompt_only_controls |
      (has_fail("WRKR-003")) as $fail_wrkr003 |
      (has_fail("WRKR-008")) as $fail_wrkr008 |
      (if ($fail_wrkr003 and $fail_wrkr008) then "none"
       elif ($fail_wrkr003 or $fail_wrkr008) then "basic"
       else "verifiable"
       end) as $evidence_tier |
      (($evidence_tier == "verifiable")) as $audit_artifacts_present |
      (($risky_scoped | length) > 0) as $destructive_tooling |
      (if ($risky_scoped | length) == 0
        then false
        else (($risky_scoped | map(select(approval_class == "approved")) | length) == ($risky_scoped | length))
       end) as $approval_gate_present |
      (($destructive_tooling == true) and ($approval_gate_present == false)) as $approval_gate_absent |
      ((($s.privilege_budget.production_write.configured // false) == true)
        and (($s.privilege_budget.production_write.count // null) != null)
       | if . then to_num($s.privilege_budget.production_write.count) else 0 end) as $production_write_tools |
      ($scoped_approval_unknown == 0) as $control_approval_resolved |
      ($scoped_explicit_unapproved == 0) as $control_no_explicit_unapproved |
      (($evidence_tier == "verifiable")) as $control_evidence_verifiable |
      (($prompt_only_controls | not)) as $control_not_prompt_only |
      (
        [ $control_approval_resolved, $control_no_explicit_unapproved, $control_evidence_verifiable, $control_not_prompt_only ]
        | map(if . then 1 else 0 end)
        | add
      ) as $article50_controls_present_count |
      (4 - $article50_controls_present_count) as $article50_controls_missing_count |
      (if $scoped_total == 0
        then false
        else ($scoped_approval_unknown > 0 or $scoped_explicit_unapproved > 0 or ($evidence_tier != "verifiable"))
       end) as $article50_gap |
      {
      schema_version: "v1",
      generated_at: $generated_at,
      target: $target,
      org: $org,
      repo: $repo,
      source: $source,
      scan_path: $scan_path,
      counts: {
        tools_detected: $scoped_total,
        approved: $scoped_approved,
        explicit_unapproved: $scoped_explicit_unapproved,
        approval_unknown: $scoped_approval_unknown,
        not_baseline_approved: ($scoped_explicit_unapproved + $scoped_approval_unknown),
        unapproved: ($scoped_explicit_unapproved + $scoped_approval_unknown),
        unknown: $scoped_approval_unknown,
        unknown_legacy: $scoped_unknown_legacy,
        production_write_tools: $production_write_tools
      },
      segments: {
        headline_scope: "exclude_source_repo",
        source_repo_tools: $source_repo_tools,
        raw_counts: {
          tools_detected: $raw_total,
          approved: $raw_approved,
          explicit_unapproved: $raw_explicit_unapproved,
          approval_unknown: $raw_approval_unknown,
          not_baseline_approved: ($raw_explicit_unapproved + $raw_approval_unknown),
          unapproved: ($raw_explicit_unapproved + $raw_approval_unknown),
          unknown: $raw_approval_unknown,
          unknown_legacy: $raw_unknown_legacy
        },
        scoped_counts: {
          tools_detected: $scoped_total,
          approved: $scoped_approved,
          explicit_unapproved: $scoped_explicit_unapproved,
          approval_unknown: $scoped_approval_unknown,
          not_baseline_approved: ($scoped_explicit_unapproved + $scoped_approval_unknown),
          unapproved: ($scoped_explicit_unapproved + $scoped_approval_unknown),
          unknown: $scoped_approval_unknown,
          unknown_legacy: $scoped_unknown_legacy
        }
      },
      regulatory_scope: {
        eu_ai_act: scope_flag("eu_ai_act"; true),
        soc2: scope_flag("soc2"; true),
        pci_dss: scope_flag("pci_dss"; false)
      },
      control_posture: {
        destructive_tooling: $destructive_tooling,
        approval_gate_present: $approval_gate_present,
        approval_gate_absent: $approval_gate_absent,
        prompt_only_controls: $prompt_only_controls,
        audit_artifacts_present: $audit_artifacts_present,
        evidence_tier: $evidence_tier,
        evidence_verifiable: ($evidence_tier == "verifiable"),
        article50_gap: $article50_gap,
        article50_controls_present_count: $article50_controls_present_count,
        article50_controls_missing_count: $article50_controls_missing_count,
        article50_control_flags: {
          approval_resolved: $control_approval_resolved,
          no_explicit_unapproved: $control_no_explicit_unapproved,
          evidence_verifiable: $control_evidence_verifiable,
          not_prompt_only: $control_not_prompt_only
        }
      }
    }' > "${state_path}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)
      RUN_ID="${2:-}"
      shift 2
      ;;
    --resume)
      RESUME=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --mode)
      MODE="${2:-}"
      shift 2
      ;;
    --targets-file)
      TARGETS_FILE="${2:-}"
      shift 2
      ;;
    --max-targets)
      MAX_TARGETS="${2:-}"
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
    --purge-clones-after-scan)
      PURGE_CLONES_AFTER_SCAN=1
      shift
      ;;
    --no-synthetic-fallback)
      ALLOW_SYNTHETIC_FALLBACK=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[sprawl-run] unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "${RUN_ID}" ]]; then
  RUN_ID="sprawl-$(date -u +%Y%m%dT%H%M%SZ)"
fi

if [[ "${MODE}" != "baseline-only" && "${MODE}" != "baseline+enrich" ]]; then
  echo "[sprawl-run] --mode must be baseline-only or baseline+enrich" >&2
  exit 1
fi
if [[ "${SCAN_SOURCE}" != "repo" && "${SCAN_SOURCE}" != "clone" ]]; then
  echo "[sprawl-run] --scan-source must be repo or clone" >&2
  exit 1
fi
for n in "${MAX_TARGETS}" "${MAX_RUNTIME_SEC}" "${MAX_RUN_DISK_MB}"; do
  if ! [[ "${n}" =~ ^[0-9]+$ ]]; then
    echo "[sprawl-run] numeric arguments must be integers" >&2
    exit 1
  fi
done

RUN_DIR="${REPO_ROOT}/runs/tool-sprawl/${RUN_ID}"
MANIFEST_PATH="${RUN_DIR}/artifacts/run-manifest.json"
CLAIM_VALUES_PATH="${RUN_DIR}/artifacts/claim-values.json"

if [[ -d "${RUN_DIR}" && "${RESUME}" -eq 0 ]]; then
  echo "[sprawl-run] run directory already exists: ${RUN_DIR}" >&2
  echo "[sprawl-run] choose a new --run-id or use --resume." >&2
  exit 1
fi
if [[ ! -d "${RUN_DIR}" && "${RESUME}" -eq 1 ]]; then
  echo "[sprawl-run] --resume requested but run directory does not exist: ${RUN_DIR}" >&2
  exit 1
fi

MODE_STATE="run"
if [[ "${RESUME}" -eq 1 ]]; then
  MODE_STATE="resume"
fi

detect_wrkr_runtime

TARGETS_FILE_PATH="${TARGETS_FILE}"
if [[ "${TARGETS_FILE_PATH}" != /* ]]; then
  TARGETS_FILE_PATH="${REPO_ROOT}/${TARGETS_FILE_PATH}"
fi

targets=()
while IFS= read -r target; do
  targets+=("${target}")
done < <(parse_targets "${TARGETS_FILE_PATH}")

if [[ "${#targets[@]}" -eq 0 && "${ALLOW_SYNTHETIC_FALLBACK}" -eq 1 ]]; then
  targets=(
    "lab-org/alpha-agent"
    "lab-org/beta-workflows"
    "lab-org/gamma-tools"
  )
fi

if [[ "${#targets[@]}" -eq 0 ]]; then
  echo "[sprawl-run] no targets found in ${TARGETS_FILE}" >&2
  exit 1
fi

if (( ${#targets[@]} > MAX_TARGETS )); then
  echo "[sprawl-run] target count (${#targets[@]}) exceeds --max-targets (${MAX_TARGETS})" >&2
  exit 1
fi

if [[ "${DRY_RUN}" -eq 1 ]]; then
  clone_root_display="${CLONE_ROOT:-runs/tool-sprawl/${RUN_ID}/sources}"
  echo "[sprawl-run] dry-run mode"
  echo "[sprawl-run] run_id=${RUN_ID} mode=${MODE_STATE} campaign_mode=${MODE}"
  echo "[sprawl-run] run_dir=${RUN_DIR}"
  echo "[sprawl-run] targets_file=${TARGETS_FILE} targets=${#targets[@]}"
  echo "[sprawl-run] scan_source=${SCAN_SOURCE} clone_root=${clone_root_display}"
  echo "[sprawl-run] purge_clones_after_scan=${PURGE_CLONES_AFTER_SCAN}"
  echo "[sprawl-run] wrkr_runtime=${WRKR_RUNTIME}"
  echo "[sprawl-run] guardrails: max_runtime_sec=${MAX_RUNTIME_SEC} max_run_disk_mb=${MAX_RUN_DISK_MB} egress_allowlist=${EGRESS_ALLOWLIST}"
  echo "[sprawl-run] actions:"
  echo "  - check prereg lock + operational guardrails"
  echo "  - ensure directories: wrkr-state, wrkr-state-enrich, states, states-enrich, scans, agg, appendix, artifacts"
  echo "  - run wrkr scan per target (fallback synthetic if unavailable)"
  echo "  - build campaign aggregate, appendix exports, and claim-values artifact"
  echo "[sprawl-run] no files written"
  exit 0
fi

check_prereg_lock
check_secret_guardrails
check_token_guardrails
check_egress_allowlist "${REPO_ROOT}/${EGRESS_ALLOWLIST}"

for policy in "${APPROVED_TOOLS_POLICY}" "${PRODUCTION_TARGETS_POLICY}" "${SEGMENT_METADATA_POLICY}" "${REGULATORY_SCOPE_POLICY}"; do
  if [[ ! -f "${REPO_ROOT}/${policy}" ]]; then
    echo "[sprawl-run] missing policy file: ${policy}" >&2
    exit 1
  fi
done

mkdir -p "${RUN_DIR}/wrkr-state" "${RUN_DIR}/wrkr-state-enrich" "${RUN_DIR}/states" "${RUN_DIR}/states-enrich" "${RUN_DIR}/scans" "${RUN_DIR}/agg" "${RUN_DIR}/appendix" "${RUN_DIR}/artifacts"
if [[ "${SCAN_SOURCE}" == "clone" ]]; then
  if [[ -z "${CLONE_ROOT}" ]]; then
    CLONE_ROOT="${RUN_DIR}/sources"
  elif [[ "${CLONE_ROOT}" != /* ]]; then
    CLONE_ROOT="${REPO_ROOT}/${CLONE_ROOT}"
  fi
  mkdir -p "${CLONE_ROOT}"
fi

assert_runtime_budget
check_disk_quota "${RUN_DIR}"

for target in "${targets[@]}"; do
  assert_runtime_budget

  slug="$(slugify "${target}")"
  scan_path="${RUN_DIR}/scans/${slug}.scan.json"
  scan_err_path="${RUN_DIR}/scans/${slug}.scan.stderr.log"
  wrkr_state_path="${RUN_DIR}/wrkr-state/${slug}.json"
  state_path="${RUN_DIR}/states/${slug}.json"
  scan_source_for_target="${SCAN_SOURCE}"
  needs_baseline_scan=1
  if [[ "${RESUME}" -eq 1 ]] && is_valid_json_file "${scan_path}" && is_valid_json_file "${state_path}"; then
    needs_baseline_scan=0
  fi

  needs_enrich_scan=0
  if [[ "${MODE}" == "baseline+enrich" ]]; then
    enrich_scan_path="${RUN_DIR}/scans/${slug}.scan.enrich.json"
    enrich_state_path="${RUN_DIR}/states-enrich/${slug}.json"
    needs_enrich_scan=1
    if [[ "${RESUME}" -eq 1 ]] && is_valid_json_file "${enrich_scan_path}" && is_valid_json_file "${enrich_state_path}"; then
      needs_enrich_scan=0
    fi
  fi

  source_path=""
  if [[ "${SCAN_SOURCE}" == "clone" && ( "${needs_baseline_scan}" -eq 1 || "${needs_enrich_scan}" -eq 1 ) ]]; then
    source_path="${CLONE_ROOT}/${slug}"
    clone_err_path="${RUN_DIR}/scans/${slug}.clone.stderr.log"
    if ! clone_repo_with_retry "${target}" "${source_path}" "${clone_err_path}"; then
      echo "[sprawl-run] clone failed for ${target}; falling back to --repo scan mode for this target" >&2
      echo "[sprawl-run] clone stderr log: ${clone_err_path}" >&2
      if [[ -s "${clone_err_path}" ]]; then
        echo "[sprawl-run] last clone stderr lines:" >&2
        tail -n 20 "${clone_err_path}" >&2
      fi
      scan_source_for_target="repo"
    fi
  elif [[ "${SCAN_SOURCE}" == "clone" ]]; then
    source_path="${CLONE_ROOT}/${slug}"
  fi

  scan_ok=1
  if [[ "${needs_baseline_scan}" -eq 1 ]]; then
    scan_ok=0
  fi
  if [[ "${WRKR_RUNTIME}" != "unavailable" && "${needs_baseline_scan}" -eq 1 ]]; then
    wrkr_args=(scan --state "${wrkr_state_path}" --approved-tools "${REPO_ROOT}/${APPROVED_TOOLS_POLICY}" --production-targets "${REPO_ROOT}/${PRODUCTION_TARGETS_POLICY}" --json)
    if [[ "${scan_source_for_target}" == "clone" ]]; then
      wrkr_args+=(--path "${source_path}")
    else
      wrkr_args+=(--repo "${target}")
      if [[ -n "${WRKR_GITHUB_API_BASE:-}" ]]; then
        wrkr_args+=(--github-api "${WRKR_GITHUB_API_BASE}")
      fi
      if [[ -n "${WRKR_GITHUB_TOKEN:-}" ]]; then
        wrkr_args+=(--github-token "${WRKR_GITHUB_TOKEN}")
      fi
    fi

    for attempt in 1 2 3; do
      : > "${scan_err_path}"
      if run_wrkr "${wrkr_args[@]}" > "${scan_path}" 2>"${scan_err_path}" && is_valid_json_file "${scan_path}"; then
        if [[ ! -s "${scan_err_path}" ]]; then
          rm -f "${scan_err_path}"
        fi
        scan_ok=1
        break
      fi
      rm -f "${scan_path}" "${wrkr_state_path}"
      sleep $((attempt * 2))
    done
  fi

  if [[ "${scan_ok}" -eq 0 && "${needs_baseline_scan}" -eq 1 ]]; then
    if [[ "${ALLOW_SYNTHETIC_FALLBACK}" -eq 0 ]]; then
      echo "[sprawl-run] wrkr scan failed for ${target}; writing scan-failed artifact and continuing (synthetic fallback disabled)" >&2
      echo "[sprawl-run] stderr log: ${scan_err_path}" >&2
      if [[ -s "${scan_err_path}" ]]; then
        echo "[sprawl-run] last wrkr stderr lines:" >&2
        tail -n 40 "${scan_err_path}" >&2
      fi
      write_failed_scan "${target}" "${scan_path}" "${scan_err_path}" "baseline"
      if [[ "${scan_source_for_target}" == "clone" ]]; then
        write_state_from_scan "${target}" "${scan_path}" "${state_path}" "wrkr-scan-failed-clone"
      else
        write_state_from_scan "${target}" "${scan_path}" "${state_path}" "wrkr-scan-failed-repo"
      fi
    fi
    if [[ "${ALLOW_SYNTHETIC_FALLBACK}" -eq 1 ]]; then
      write_synthetic_scan "${target}" "${scan_path}"
      write_state_from_scan "${target}" "${scan_path}" "${state_path}" "synthetic-preflight"
    fi
  elif [[ "${needs_baseline_scan}" -eq 1 ]]; then
    if [[ "${scan_source_for_target}" == "clone" ]]; then
      write_state_from_scan "${target}" "${scan_path}" "${state_path}" "wrkr-scan-clone"
    else
      write_state_from_scan "${target}" "${scan_path}" "${state_path}" "wrkr-scan-repo-fallback"
    fi
  fi

  if [[ "${MODE}" == "baseline+enrich" ]]; then
    enrich_scan_path="${RUN_DIR}/scans/${slug}.scan.enrich.json"
    enrich_scan_err_path="${RUN_DIR}/scans/${slug}.scan.enrich.stderr.log"
    wrkr_enrich_state_path="${RUN_DIR}/wrkr-state-enrich/${slug}.json"
    enrich_state_path="${RUN_DIR}/states-enrich/${slug}.json"
    enrich_ok=1
    if [[ "${needs_enrich_scan}" -eq 1 ]]; then
      enrich_ok=0
    fi

    if [[ "${WRKR_RUNTIME}" != "unavailable" && "${needs_enrich_scan}" -eq 1 ]]; then
      wrkr_enrich_args=(scan --state "${wrkr_enrich_state_path}" --approved-tools "${REPO_ROOT}/${APPROVED_TOOLS_POLICY}" --production-targets "${REPO_ROOT}/${PRODUCTION_TARGETS_POLICY}" --enrich --json)
      if [[ "${scan_source_for_target}" == "clone" ]]; then
        wrkr_enrich_args+=(--path "${source_path}")
      else
        wrkr_enrich_args+=(--repo "${target}")
        if [[ -n "${WRKR_GITHUB_API_BASE:-}" ]]; then
          wrkr_enrich_args+=(--github-api "${WRKR_GITHUB_API_BASE}")
        fi
        if [[ -n "${WRKR_GITHUB_TOKEN:-}" ]]; then
          wrkr_enrich_args+=(--github-token "${WRKR_GITHUB_TOKEN}")
        fi
      fi
      for attempt in 1 2 3; do
        : > "${enrich_scan_err_path}"
        if run_wrkr "${wrkr_enrich_args[@]}" > "${enrich_scan_path}" 2>"${enrich_scan_err_path}" && is_valid_json_file "${enrich_scan_path}"; then
          if [[ ! -s "${enrich_scan_err_path}" ]]; then
            rm -f "${enrich_scan_err_path}"
          fi
          enrich_ok=1
          break
        fi
        rm -f "${enrich_scan_path}" "${wrkr_enrich_state_path}"
        sleep $((attempt * 2))
      done
    fi

    if [[ "${enrich_ok}" -eq 0 && "${needs_enrich_scan}" -eq 1 ]]; then
      if [[ "${ALLOW_SYNTHETIC_FALLBACK}" -eq 0 ]]; then
        echo "[sprawl-run] wrkr enrich scan failed for ${target}; writing scan-failed artifact and continuing (synthetic fallback disabled)" >&2
        echo "[sprawl-run] stderr log: ${enrich_scan_err_path}" >&2
        if [[ -s "${enrich_scan_err_path}" ]]; then
          echo "[sprawl-run] last wrkr stderr lines:" >&2
          tail -n 40 "${enrich_scan_err_path}" >&2
        fi
        write_failed_scan "${target}" "${enrich_scan_path}" "${enrich_scan_err_path}" "enrich"
        if [[ "${scan_source_for_target}" == "clone" ]]; then
          write_state_from_scan "${target}" "${enrich_scan_path}" "${enrich_state_path}" "wrkr-enrich-failed-clone"
        else
          write_state_from_scan "${target}" "${enrich_scan_path}" "${enrich_state_path}" "wrkr-enrich-failed-repo"
        fi
      fi
      if [[ "${ALLOW_SYNTHETIC_FALLBACK}" -eq 1 ]]; then
        write_synthetic_scan "${target}" "${enrich_scan_path}"
        write_state_from_scan "${target}" "${enrich_scan_path}" "${enrich_state_path}" "synthetic-enrich"
      fi
    elif [[ "${needs_enrich_scan}" -eq 1 ]]; then
      if [[ "${scan_source_for_target}" == "clone" ]]; then
        write_state_from_scan "${target}" "${enrich_scan_path}" "${enrich_state_path}" "wrkr-enrich-clone"
      else
        write_state_from_scan "${target}" "${enrich_scan_path}" "${enrich_state_path}" "wrkr-enrich-repo-fallback"
      fi
    fi
  fi

  if [[ "${needs_baseline_scan}" -eq 1 || "${needs_enrich_scan}" -eq 1 ]]; then
    check_disk_quota "${RUN_DIR}"
  fi

  if [[ "${PURGE_CLONES_AFTER_SCAN}" -eq 1 && -n "${source_path}" && -d "${source_path}" ]]; then
    rm -rf "${source_path}"
  fi
done

assert_runtime_budget

state_inputs=()
for target in "${targets[@]}"; do
  slug="$(slugify "${target}")"
  state_file="${RUN_DIR}/states/${slug}.json"
  if [[ ! -f "${state_file}" ]]; then
    echo "[sprawl-run] missing expected state file for target ${target}: ${state_file}" >&2
    exit 1
  fi
  state_inputs+=("${state_file}")
done
if [[ "${#state_inputs[@]}" -eq 0 ]]; then
  echo "[sprawl-run] no state files generated" >&2
  exit 1
fi

jq -s \
  --arg run_id "${RUN_ID}" \
  --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg mode "${MODE}" \
  --arg detector_list "${DETECTOR_LIST}" '
  def pct(n; d): if d == 0 then 0 else ((n * 10000 / d) | round) / 100 end;
  def ratio(n; d): if d == 0 then 0 else ((n * 100 / d) | round) / 100 end;
  def median($arr):
    if ($arr | length) == 0 then 0
    else
      ($arr | sort) as $s
      | ($s | length) as $l
      | if ($l % 2) == 1
        then $s[($l / 2 | floor)]
        else (($s[($l / 2) - 1] + $s[$l / 2]) / 2)
        end
    end;
  {
    schema_version: "v1",
    report_id: "ai-tool-sprawl-q1-2026",
    run_id: $run_id,
    generated_at: $generated_at,
    campaign: {
      scans: (map(.target)),
      metrics: {
        orgs_scanned: length,
        avg_approval_unknown_tools_per_org: (
          ratio((map(.counts.approval_unknown // .counts.unknown // 0) | add); length)
        ),
        avg_unknown_tools_per_org: (
          ratio((map(.counts.approval_unknown // .counts.unknown // 0) | add); length)
        ),
        explicit_unapproved_to_approved_ratio: ratio((map(.counts.explicit_unapproved // 0) | add); (map(.counts.approved // 0) | add)),
        not_baseline_approved_to_approved_ratio: ratio((map(.counts.not_baseline_approved // .counts.unapproved // 0) | add); (map(.counts.approved // 0) | add)),
        unapproved_to_approved_ratio: ratio((map(.counts.not_baseline_approved // .counts.unapproved // 0) | add); (map(.counts.approved // 0) | add)),
        article50_gap_prevalence_pct: pct((map(select(.control_posture.article50_gap == true)) | length); length),
        article50_controls_missing_median: median((map(.control_posture.article50_controls_missing_count // 4))),
        orgs_with_destructive_tooling_pct: pct((map(select(.control_posture.destructive_tooling == true)) | length); length),
        orgs_without_approval_gate_pct: pct((map(select(.control_posture.approval_gate_absent == true)) | length); length),
        orgs_prompt_only_controls_pct: pct((map(select(.control_posture.prompt_only_controls == true)) | length); length),
        orgs_without_audit_artifacts_pct: pct((map(select(.control_posture.audit_artifacts_present == false)) | length); length),
        orgs_without_verifiable_evidence_pct: pct((map(select(.control_posture.evidence_verifiable != true)) | length); length)
      },
      totals: {
        tools_detected: (map(.counts.tools_detected // 0) | add),
        approved_tools: (map(.counts.approved // 0) | add),
        explicit_unapproved_tools: (map(.counts.explicit_unapproved // 0) | add),
        approval_unknown_tools: (map(.counts.approval_unknown // .counts.unknown // 0) | add),
        not_baseline_approved_tools: (map(.counts.not_baseline_approved // .counts.unapproved // 0) | add),
        unapproved_tools: (map(.counts.not_baseline_approved // .counts.unapproved // 0) | add),
        unknown_tools: (map(.counts.approval_unknown // .counts.unknown // 0) | add),
        unknown_tools_legacy: (map(.counts.unknown_legacy // 0) | add),
        production_write_tools: (map(.counts.production_write_tools // 0) | add)
      },
      segmented_totals: {
        headline_scope: "exclude_source_repo",
        source_repo_tools: (map(.segments.source_repo_tools // 0) | add),
        tools_detected_raw: (map(.segments.raw_counts.tools_detected // .counts.tools_detected // 0) | add),
        approved_tools_raw: (map(.segments.raw_counts.approved // .counts.approved // 0) | add),
        explicit_unapproved_tools_raw: (map(.segments.raw_counts.explicit_unapproved // 0) | add),
        approval_unknown_tools_raw: (map(.segments.raw_counts.approval_unknown // .segments.raw_counts.unknown // .counts.unknown // 0) | add),
        not_baseline_approved_tools_raw: (map(.segments.raw_counts.not_baseline_approved // .segments.raw_counts.unapproved // .counts.unapproved // 0) | add),
        unapproved_tools_raw: (map(.segments.raw_counts.not_baseline_approved // .segments.raw_counts.unapproved // .counts.unapproved // 0) | add),
        unknown_tools_raw: (map(.segments.raw_counts.approval_unknown // .segments.raw_counts.unknown // .counts.unknown // 0) | add),
        unknown_tools_raw_legacy: (map(.segments.raw_counts.unknown_legacy // 0) | add)
      }
    },
    methodology: {
      mode: $mode,
      detector_list: $detector_list
    }
  }
' "${state_inputs[@]}" > "${RUN_DIR}/agg/campaign-summary.json"

jq -n \
  --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg run_id "${RUN_ID}" \
  --arg summary_path "runs/tool-sprawl/${RUN_ID}/agg/campaign-summary.json" \
  '{
    schema_version: "v1",
    generated_at: $generated_at,
    run_id: $run_id,
    summary_path: $summary_path,
    status: "ok"
  }' > "${RUN_DIR}/agg/campaign-envelope.json"

orgs_scanned="$(jq -r '.campaign.metrics.orgs_scanned' "${RUN_DIR}/agg/campaign-summary.json")"
ratio_not_baseline="$(jq -r '.campaign.metrics.not_baseline_approved_to_approved_ratio' "${RUN_DIR}/agg/campaign-summary.json")"
ratio_explicit="$(jq -r '.campaign.metrics.explicit_unapproved_to_approved_ratio' "${RUN_DIR}/agg/campaign-summary.json")"
avg_unknown="$(jq -r '.campaign.metrics.avg_approval_unknown_tools_per_org' "${RUN_DIR}/agg/campaign-summary.json")"
article50_gap="$(jq -r '.campaign.metrics.article50_gap_prevalence_pct' "${RUN_DIR}/agg/campaign-summary.json")"
article50_controls_missing_median="$(jq -r '.campaign.metrics.article50_controls_missing_median' "${RUN_DIR}/agg/campaign-summary.json")"
without_verifiable_evidence="$(jq -r '.campaign.metrics.orgs_without_verifiable_evidence_pct' "${RUN_DIR}/agg/campaign-summary.json")"

cat > "${RUN_DIR}/agg/campaign-public.md" <<EOF_PUBLIC
# AI Tool Sprawl Campaign Summary

Run ID: ${RUN_ID}

- Organizations scanned: ${orgs_scanned}
- Not-baseline-approved to baseline-approved ratio (non-source scope): ${ratio_not_baseline}
- Explicit-unapproved to baseline-approved ratio (non-source scope): ${ratio_explicit}
- Average approval-unknown tools per org (non-source scope): ${avg_unknown}
- Article 50 gap prevalence (%): ${article50_gap}
- Article 50 controls missing median (0-4): ${article50_controls_missing_median}
- Organizations without verifiable evidence tier (%): ${without_verifiable_evidence}
EOF_PUBLIC

jq -s '
  {
    export_version: "1",
    schema_version: "v1",
    inventory_rows: map({
      org: .org,
      repo: .repo,
      tools_detected: (.counts.tools_detected // 0),
      approved_tools: (.counts.approved // 0),
      explicit_unapproved_tools: (.counts.explicit_unapproved // 0),
      approval_unknown_tools: (.counts.approval_unknown // .counts.unknown // 0),
      not_baseline_approved_tools: (.counts.not_baseline_approved // .counts.unapproved // 0),
      unapproved_tools: (.counts.not_baseline_approved // .counts.unapproved // 0),
      unknown_tools: (.counts.approval_unknown // .counts.unknown // 0),
      unknown_tools_legacy: (.counts.unknown_legacy // 0),
      production_write_tools: (.counts.production_write_tools // 0),
      source_repo_tools: (.segments.source_repo_tools // 0),
      tools_detected_raw: (.segments.raw_counts.tools_detected // .counts.tools_detected // 0),
      approved_tools_raw: (.segments.raw_counts.approved // .counts.approved // 0),
      explicit_unapproved_tools_raw: (.segments.raw_counts.explicit_unapproved // 0),
      approval_unknown_tools_raw: (.segments.raw_counts.approval_unknown // .segments.raw_counts.unknown // .counts.unknown // 0),
      not_baseline_approved_tools_raw: (.segments.raw_counts.not_baseline_approved // .segments.raw_counts.unapproved // .counts.unapproved // 0),
      unapproved_tools_raw: (.segments.raw_counts.not_baseline_approved // .segments.raw_counts.unapproved // .counts.unapproved // 0),
      unknown_tools_raw: (.segments.raw_counts.approval_unknown // .segments.raw_counts.unknown // .counts.unknown // 0),
      unknown_tools_raw_legacy: (.segments.raw_counts.unknown_legacy // 0)
    }),
    privilege_rows: map({
      org: .org,
      tool_id: (.target + ":tooling"),
      privilege_tier: (if .control_posture.destructive_tooling then "HIGH" else "MEDIUM" end),
      write_targets: (.counts.production_write_tools // 0),
      credential_access: (if .control_posture.audit_artifacts_present then "tracked" else "unknown" end),
      infrastructure_scope: "repo",
      risk_tier: (if .control_posture.destructive_tooling then "CRITICAL" else "HIGH" end)
    }),
    approval_gap_rows: map({
      org: .org,
      approval_classification: (if .control_posture.approval_gate_present then "gated" else "ungated" end),
      tool_id: (.target + ":tooling"),
      prompt_only_controls: .control_posture.prompt_only_controls,
      explicit_unapproved_tools: (.counts.explicit_unapproved // 0),
      approval_unknown_tools: (.counts.approval_unknown // .counts.unknown // 0),
      not_baseline_approved_tools: (.counts.not_baseline_approved // .counts.unapproved // 0)
    }),
    regulatory_rows: (
      map(
        (.counts.not_baseline_approved // .counts.unapproved // 0) as $not_baseline_approved |
        (.counts.explicit_unapproved // 0) as $explicit_unapproved |
        (.counts.approval_unknown // .counts.unknown // 0) as $approval_unknown |
        (.regulatory_scope // {eu_ai_act: true, soc2: true, pci_dss: false}) as $scope |
        [
          (if ($scope.eu_ai_act // true) then {
            org: .org,
            regulation: "EU AI Act",
            control_id: "Article 50 Proxy",
            tool_id: (.target + ":tooling"),
            gap_status: (if .control_posture.article50_gap then "gap" else "covered" end),
            controls_missing_count: (.control_posture.article50_controls_missing_count // 0),
            evidence_ref: .scan_path
          } else empty end),
          (if ($scope.soc2 // true) then {
            org: .org,
            regulation: "SOC 2",
            control_id: "CC6.1",
            tool_id: (.target + ":tooling"),
            gap_status: (if ($not_baseline_approved > 0 or (.control_posture.approval_gate_absent == true)) then "gap" else "covered" end),
            controls_missing_count: (if ($not_baseline_approved > 0 or (.control_posture.approval_gate_absent == true)) then 1 else 0 end),
            evidence_ref: .scan_path
          }, {
            org: .org,
            regulation: "SOC 2",
            control_id: "CC7.1",
            tool_id: (.target + ":tooling"),
            gap_status: (if (.control_posture.evidence_verifiable != true) then "gap" else "covered" end),
            controls_missing_count: (if (.control_posture.evidence_verifiable != true) then 1 else 0 end),
            evidence_ref: .scan_path
          }, {
            org: .org,
            regulation: "SOC 2",
            control_id: "CC8.1",
            tool_id: (.target + ":tooling"),
            gap_status: (if ($explicit_unapproved > 0 or (.control_posture.prompt_only_controls == true)) then "gap" else "covered" end),
            controls_missing_count: (if ($explicit_unapproved > 0 or (.control_posture.prompt_only_controls == true)) then 1 else 0 end),
            evidence_ref: .scan_path
          } else empty end),
          (if ($scope.pci_dss // false) then {
            org: .org,
            regulation: "PCI DSS 4.0.1",
            control_id: "6.3",
            tool_id: (.target + ":tooling"),
            gap_status: (if (.control_posture.destructive_tooling == true) then "gap" else "covered" end),
            controls_missing_count: (if (.control_posture.destructive_tooling == true) then 1 else 0 end),
            evidence_ref: .scan_path
          }, {
            org: .org,
            regulation: "PCI DSS 4.0.1",
            control_id: "6.5",
            tool_id: (.target + ":tooling"),
            gap_status: (if ($explicit_unapproved > 0 or (.control_posture.approval_gate_absent == true)) then "gap" else "covered" end),
            controls_missing_count: (if ($explicit_unapproved > 0 or (.control_posture.approval_gate_absent == true)) then 1 else 0 end),
            evidence_ref: .scan_path
          }, {
            org: .org,
            regulation: "PCI DSS 4.0.1",
            control_id: "7.2",
            tool_id: (.target + ":tooling"),
            gap_status: (if ($not_baseline_approved > 0) then "gap" else "covered" end),
            controls_missing_count: (if ($not_baseline_approved > 0) then 1 else 0 end),
            evidence_ref: .scan_path
          }, {
            org: .org,
            regulation: "PCI DSS 4.0.1",
            control_id: "12.8",
            tool_id: (.target + ":tooling"),
            gap_status: (if ($approval_unknown > 0) then "gap" else "covered" end),
            controls_missing_count: (if ($approval_unknown > 0) then 1 else 0 end),
            evidence_ref: .scan_path
          } else empty end)
        ]
      ) | add
    ),
    prompt_channel_rows: map({
      org: .org,
      repo: .repo,
      location: ".",
      pattern_family: (if .control_posture.prompt_only_controls then "prompt_only" else "policy_backed" end)
    }),
    attack_path_rows: map({
      org: .org,
      path_id: (.target + ":default"),
      path_score: (if .control_posture.destructive_tooling then 8.5 else 3.0 end)
    }),
    evidence_rows: map({
      org: .org,
      evidence_tier: (.control_posture.evidence_tier // "none"),
      evidence_verifiable: (.control_posture.evidence_verifiable // false),
      audit_artifacts_present: (.control_posture.audit_artifacts_present // false)
    }),
    mcp_enrich_rows: []
  }
' "${state_inputs[@]}" > "${RUN_DIR}/appendix/combined-appendix.json"

jq -r '(["org","tools_detected","approved_tools","explicit_unapproved_tools","approval_unknown_tools","not_baseline_approved_tools","unknown_tools","unknown_tools_legacy","production_write_tools","source_repo_tools","tools_detected_raw","approved_tools_raw","explicit_unapproved_tools_raw","approval_unknown_tools_raw","not_baseline_approved_tools_raw","unknown_tools_raw","unknown_tools_raw_legacy"] | @csv),
  (.inventory_rows[] | [.org, .tools_detected, .approved_tools, .explicit_unapproved_tools, .approval_unknown_tools, .not_baseline_approved_tools, .unknown_tools, .unknown_tools_legacy, .production_write_tools, .source_repo_tools, .tools_detected_raw, .approved_tools_raw, .explicit_unapproved_tools_raw, .approval_unknown_tools_raw, .not_baseline_approved_tools_raw, .unknown_tools_raw, .unknown_tools_raw_legacy] | @csv)
' "${RUN_DIR}/appendix/combined-appendix.json" > "${RUN_DIR}/appendix/aggregated-findings.csv"

jq -r '(["org","repo","tool_type","tool_id","tool_name","detector","confidence","location"] | @csv),
  (.inventory_rows[] | [.org, .repo, "ai_tool", (.org + ":tooling"), "ai_tooling", "deterministic", "0.9", "."] | @csv)
' "${RUN_DIR}/appendix/combined-appendix.json" > "${RUN_DIR}/appendix/tool-inventory.csv"

jq -r '(["org","tool_id","privilege_tier","write_targets","credential_access","infrastructure_scope","risk_tier"] | @csv),
  (.privilege_rows[] | [.org, .tool_id, .privilege_tier, .write_targets, .credential_access, .infrastructure_scope, .risk_tier] | @csv)
' "${RUN_DIR}/appendix/combined-appendix.json" > "${RUN_DIR}/appendix/privilege-map.csv"

jq -r '(["org","regulation","control_id","tool_id","gap_status","controls_missing_count","evidence_ref"] | @csv),
  (.regulatory_rows[] | [.org, .regulation, .control_id, .tool_id, .gap_status, .controls_missing_count, .evidence_ref] | @csv)
' "${RUN_DIR}/appendix/combined-appendix.json" > "${RUN_DIR}/appendix/regulatory-gap-matrix.csv"

"${REPO_ROOT}/pipelines/common/metric_coverage_gate.sh" \
  --report-id "ai-tool-sprawl-q1-2026" \
  --claims "${REPO_ROOT}/claims/ai-tool-sprawl-q1-2026/claims.json" \
  --thresholds "${REPO_ROOT}/pipelines/config/publish-thresholds.json" \
  --strict

"${REPO_ROOT}/pipelines/common/derive_claim_values.sh" \
  --repo-root "${REPO_ROOT}" \
  --claims "claims/ai-tool-sprawl-q1-2026/claims.json" \
  --run-id "${RUN_ID}" \
  --output "${CLAIM_VALUES_PATH}" \
  --strict

assert_runtime_budget
check_disk_quota "${RUN_DIR}"

REPO_SHA="$(safe_git_sha "${REPO_ROOT}")"
REPO_REF="$(safe_git_ref "${REPO_ROOT}")"
WRKR_SHA="$(safe_git_sha "${WRKR_REPO_PATH}")"
WRKR_REF="$(safe_git_ref "${WRKR_REPO_PATH}")"
WRKR_VERSION="$(capture_wrkr_version)"
WRKR_TREE_DIGEST="$(dir_sha256 "${WRKR_REPO_PATH}" ".git")"
WRKR_RUNTIME_REF="$(normalize_runtime_ref "${WRKR_RUNTIME}")"
CLONE_ROOT_REF="$(normalize_path_ref "${CLONE_ROOT}")"

APPROVED_DIGEST="$(file_sha256 "${REPO_ROOT}/${APPROVED_TOOLS_POLICY}")"
PRODUCTION_DIGEST="$(file_sha256 "${REPO_ROOT}/${PRODUCTION_TARGETS_POLICY}")"
SEGMENT_DIGEST="$(file_sha256 "${REPO_ROOT}/${SEGMENT_METADATA_POLICY}")"
REG_SCOPE_DIGEST="$(file_sha256 "${REPO_ROOT}/${REGULATORY_SCOPE_POLICY}")"
TARGETS_DIGEST="$(file_sha256 "${TARGETS_FILE_PATH}")"
EGRESS_ALLOWLIST_DIGEST="$(file_sha256 "${REPO_ROOT}/${EGRESS_ALLOWLIST}")"

jq -n \
  --arg schema_version "v2" \
  --arg report_id "ai-tool-sprawl-q1-2026" \
  --arg run_id "${RUN_ID}" \
  --arg created_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg status "completed" \
  --arg mode_state "${MODE_STATE}" \
  --arg campaign_mode "${MODE}" \
  --arg repo_sha "${REPO_SHA}" \
  --arg repo_ref "${REPO_REF}" \
  --arg wrkr_runtime "${WRKR_RUNTIME_REF}" \
  --arg wrkr_version "${WRKR_VERSION}" \
  --arg wrkr_sha "${WRKR_SHA}" \
  --arg wrkr_ref "${WRKR_REF}" \
  --arg wrkr_tree_sha256 "${WRKR_TREE_DIGEST}" \
  --arg scan_source "${SCAN_SOURCE}" \
  --arg clone_root "${CLONE_ROOT_REF}" \
  --arg detector_list "${DETECTOR_LIST}" \
  --arg targets_file "${TARGETS_FILE}" \
  --arg targets_file_sha256 "${TARGETS_DIGEST}" \
  --arg approved_policy "${APPROVED_TOOLS_POLICY}" \
  --arg approved_policy_sha256 "${APPROVED_DIGEST}" \
  --arg production_policy "${PRODUCTION_TARGETS_POLICY}" \
  --arg production_policy_sha256 "${PRODUCTION_DIGEST}" \
  --arg segment_policy "${SEGMENT_METADATA_POLICY}" \
  --arg segment_policy_sha256 "${SEGMENT_DIGEST}" \
  --arg regulatory_scope_policy "${REGULATORY_SCOPE_POLICY}" \
  --arg regulatory_scope_policy_sha256 "${REG_SCOPE_DIGEST}" \
  --arg egress_allowlist "${EGRESS_ALLOWLIST}" \
  --arg egress_allowlist_sha256 "${EGRESS_ALLOWLIST_DIGEST}" \
  --argjson max_runtime_sec "${MAX_RUNTIME_SEC}" \
  --argjson max_run_disk_mb "${MAX_RUN_DISK_MB}" \
  --argjson target_count "${#targets[@]}" \
  --argjson purge_clones_after_scan "${PURGE_CLONES_AFTER_SCAN}" \
  --arg claims_values "runs/tool-sprawl/${RUN_ID}/artifacts/claim-values.json" \
  --arg campaign_summary "runs/tool-sprawl/${RUN_ID}/agg/campaign-summary.json" \
  --arg appendix_path "runs/tool-sprawl/${RUN_ID}/appendix/combined-appendix.json" \
  '{
    schema_version: $schema_version,
    report_id: $report_id,
    run_id: $run_id,
    created_at: $created_at,
    status: $status,
    mode: $mode_state,
    campaign_mode: $campaign_mode,
    reproducibility: {
      repository: {
        commit_sha: $repo_sha,
        ref: $repo_ref
      },
      wrkr: {
        runtime: $wrkr_runtime,
        version: $wrkr_version,
        commit_sha: $wrkr_sha,
        ref: $wrkr_ref,
        tree_sha256: $wrkr_tree_sha256,
        detector_list: $detector_list,
        scan_source: $scan_source,
        clone_root: $clone_root
      },
      inputs: {
        targets_file: $targets_file,
        targets_file_sha256: $targets_file_sha256,
        approved_policy: $approved_policy,
        approved_policy_sha256: $approved_policy_sha256,
        production_policy: $production_policy,
        production_policy_sha256: $production_policy_sha256,
        segment_policy: $segment_policy,
        segment_policy_sha256: $segment_policy_sha256,
        regulatory_scope_policy: $regulatory_scope_policy,
        regulatory_scope_policy_sha256: $regulatory_scope_policy_sha256
      }
    },
    operational_guardrails: {
      egress_allowlist_path: $egress_allowlist,
      egress_allowlist_sha256: $egress_allowlist_sha256,
      no_production_creds_enforced: true,
      read_only_token_required: true,
      max_runtime_sec: $max_runtime_sec,
      max_run_disk_mb: $max_run_disk_mb,
      max_targets: $target_count,
      purge_clones_after_scan: ($purge_clones_after_scan == 1)
    },
    artifacts: {
      campaign_summary: $campaign_summary,
      appendix: $appendix_path,
      claim_values: $claims_values
    }
  }' > "${MANIFEST_PATH}"

hash_args=(
  --input "${RUN_DIR}"
  --output "${RUN_DIR}/artifacts/manifest.sha256"
)
if [[ "${SCAN_SOURCE}" == "clone" ]]; then
  hash_args+=(--exclude-prefix "sources/")
fi
"${REPO_ROOT}/pipelines/common/hash_manifest.sh" "${hash_args[@]}"

echo "[sprawl-run] completed run ${RUN_ID}"
echo "[sprawl-run] manifest: ${MANIFEST_PATH}"
echo "[sprawl-run] claim-values: ${CLAIM_VALUES_PATH}"
