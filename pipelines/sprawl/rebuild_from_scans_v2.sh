#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  rebuild_from_scans_v2.sh --run-id <id> [--targets-file <path>] [--mode baseline-only|baseline+enrich]
                           [--detector-list <csv>] [--claims-file <path>] [--thresholds-file <path>]

Rebuilds v2 campaign artifacts from completed sprawl scan JSON:
  - agg/campaign-summary-v2.json
  - agg/campaign-envelope-v2.json
  - agg/campaign-public-v2.md
  - states-v2/*.json
  - appendix/combined-appendix-v2.json
  - appendix/tool-inventory.csv
  - appendix/agent-inventory.csv
  - appendix/agent-privilege-map.csv
  - appendix/attack-paths.csv
  - appendix/framework-rollups.csv
  - appendix/regulatory-gap-matrix-v2.csv
  - appendix/org-summary-v2.csv
USAGE
}

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUN_ID=""
TARGETS_FILE="internal/repos-v2-publication.md"
MODE="baseline-only"
DETECTOR_LIST="${WRKR_DETECTORS:-default}"
CLAIMS_FILE="claims/ai-tool-sprawl-v2-2026/claims.json"
THRESHOLDS_FILE="pipelines/config/publish-thresholds.json"
REGULATORY_SCOPE_POLICY="pipelines/policies/regulatory-scope.v1.json"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)
      RUN_ID="${2:-}"
      shift 2
      ;;
    --targets-file)
      TARGETS_FILE="${2:-}"
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
    --claims-file)
      CLAIMS_FILE="${2:-}"
      shift 2
      ;;
    --thresholds-file)
      THRESHOLDS_FILE="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[sprawl-rebuild-v2] unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "${RUN_ID}" ]]; then
  echo "[sprawl-rebuild-v2] --run-id is required" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "[sprawl-rebuild-v2] jq is required" >&2
  exit 1
fi

RUN_DIR="${REPO_ROOT}/runs/tool-sprawl/${RUN_ID}"
SCANS_DIR="${RUN_DIR}/scans"
LEGACY_STATES_DIR="${RUN_DIR}/states"
V2_STATES_DIR="${RUN_DIR}/states-v2"
AGG_DIR="${RUN_DIR}/agg"
APPENDIX_DIR="${RUN_DIR}/appendix"
ARTIFACTS_DIR="${RUN_DIR}/artifacts"

if [[ ! -d "${SCANS_DIR}" ]]; then
  echo "[sprawl-rebuild-v2] scans dir not found: ${SCANS_DIR}" >&2
  exit 1
fi

TARGETS_FILE_PATH="${TARGETS_FILE}"
if [[ "${TARGETS_FILE_PATH}" != /* ]]; then
  TARGETS_FILE_PATH="${REPO_ROOT}/${TARGETS_FILE_PATH}"
fi
if [[ ! -f "${TARGETS_FILE_PATH}" ]]; then
  echo "[sprawl-rebuild-v2] targets file not found: ${TARGETS_FILE_PATH}" >&2
  exit 1
fi

CLAIMS_FILE_PATH="${CLAIMS_FILE}"
if [[ "${CLAIMS_FILE_PATH}" != /* ]]; then
  CLAIMS_FILE_PATH="${REPO_ROOT}/${CLAIMS_FILE_PATH}"
fi
THRESHOLDS_FILE_PATH="${THRESHOLDS_FILE}"
if [[ "${THRESHOLDS_FILE_PATH}" != /* ]]; then
  THRESHOLDS_FILE_PATH="${REPO_ROOT}/${THRESHOLDS_FILE_PATH}"
fi
REG_SCOPE_PATH="${REPO_ROOT}/${REGULATORY_SCOPE_POLICY}"

mkdir -p "${V2_STATES_DIR}" "${AGG_DIR}" "${APPENDIX_DIR}" "${ARTIFACTS_DIR}"

parse_targets() {
  local file="$1"
  local line
  while IFS= read -r line; do
    line="${line%%#*}"
    line="$(printf '%s' "${line}" | awk '{$1=$1;print}')"
    [[ -z "${line}" ]] && continue
    printf '%s\n' "${line}"
  done < "${file}"
}

slugify() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr '/:' '-' | tr -cs 'a-z0-9._-' '-'
}

state_inputs=()
targets=()
while IFS= read -r target; do
  targets+=("${target}")
done < <(parse_targets "${TARGETS_FILE_PATH}")

if [[ "${#targets[@]}" -eq 0 ]]; then
  echo "[sprawl-rebuild-v2] no targets resolved from ${TARGETS_FILE_PATH}" >&2
  exit 1
fi

for target in "${targets[@]}"; do
  slug="$(slugify "${target}")"
  scan_path="${SCANS_DIR}/${slug}.scan.json"
  state_path="${V2_STATES_DIR}/${slug}.json"
  if [[ ! -f "${scan_path}" ]]; then
    echo "[sprawl-rebuild-v2] missing scan artifact for ${target}: ${scan_path}" >&2
    exit 1
  fi

  jq -n \
    --slurpfile scan "${scan_path}" \
    --slurpfile regscope "${REG_SCOPE_PATH}" \
    --arg target "${target}" \
    --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg scan_path "runs/tool-sprawl/${RUN_ID}/scans/${slug}.scan.json" \
    '
      ($scan[0] // {}) as $s |
      ($regscope[0] // {}) as $regscope_policy |
      ($regscope_policy.defaults // {}) as $regscope_defaults |
      ($regscope_policy.orgs // {}) as $regscope_orgs |
      ($target | split("/")) as $parts |
      ($parts[0] // "unknown") as $org |
      ($parts[1] // "unknown") as $repo |
      ($regscope_orgs[$org] // {}) as $regscope_org |
      ((if (($s.inventory.tools // []) | type) == "array" then ($s.inventory.tools // []) else [] end)) as $tools |
      ((if (($s.inventory.agents // []) | type) == "array" then ($s.inventory.agents // []) else [] end)) as $agents |
      ((if (($s.agent_privilege_map // []) | type) == "array" then ($s.agent_privilege_map // []) else [] end)) as $agent_map |
      ((if (($s.attack_paths // []) | type) == "array" then ($s.attack_paths // []) else [] end)) as $attack_paths |
      ((if (($s.compliance_summary.frameworks // []) | type) == "array" then ($s.compliance_summary.frameworks // []) else [] end)) as $frameworks |
      ($tools | map(select((.tool_type // "") != "source_repo"))) as $scoped_tools |
      ($s.profile.failing_rules // []) as $failing_rules |

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
      def unique_agent_count($rows; $pred):
        ($rows | map(select($pred) | (.agent_id // "")) | map(select(length > 0)) | unique | length);
      def unique_strings($items):
        $items | map(select(type == "string" and length > 0)) | unique | sort;
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
        else (if (($s.inventory.tools // null) | type) == "number" then ($s.inventory.tools // 0) else to_num($s.inventory.tools_detected // $s.inventory.total_tools // $s.inventory.summary.total // 0) end)
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
      (if $tool_array_len > 0 then ($scoped_tools | length) else $raw_total end) as $scoped_total |
      (if $tool_array_len > 0
        then ($scoped_tools | map(select(approval_class == "approved")) | length)
        else $raw_approved
       end) as $scoped_approved |
      (if $tool_array_len > 0
        then ($scoped_tools | map(select(is_explicit_unapproved)) | length)
        else $raw_explicit_unapproved
       end) as $scoped_explicit_unapproved |
      (if $tool_array_len > 0
        then ($scoped_tools | map(select(is_approval_unknown)) | length)
        else $raw_approval_unknown
       end) as $scoped_approval_unknown |
      (if $tool_array_len > 0
        then ($scoped_tools | map(select(approval_class != "approved" and approval_class != "unapproved")) | length)
        else $raw_unknown_legacy
       end) as $scoped_unknown_legacy |
      ($scoped_tools | map(select(risky))) as $risky_scoped |
      (($scoped_tools | map(select((.tool_type // "") == "prompt_channel")) | length) > 0 or has_fail("WRKR-016")) as $prompt_only_controls |
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
      ([ $control_approval_resolved, $control_no_explicit_unapproved, $control_evidence_verifiable, $control_not_prompt_only ]
        | map(if . then 1 else 0 end) | add) as $article50_controls_present_count |
      (4 - $article50_controls_present_count) as $article50_controls_missing_count |
      (if $scoped_total == 0
        then false
        else ($scoped_approval_unknown > 0 or $scoped_explicit_unapproved > 0 or ($evidence_tier != "verifiable"))
       end) as $article50_gap |
      (if (($s.inventory.agents // null) | type) == "number" then ($s.inventory.agents // 0) else ($agents | length) end) as $declared_agents |
      ($agents | map(select((.deployment_status // "") == "deployed")) | length) as $deployed_agents |
      ($agents | map(select(((.missing_bindings // []) | length) > 0)) | length) as $binding_incomplete_agents |
      ($declared_agents - $binding_incomplete_agents) as $binding_complete_agents |
      (unique_agent_count($agent_map; (.write_capable // false) == true)) as $write_capable_agents |
      (unique_agent_count($agent_map; (.exec_capable // false) == true)) as $exec_capable_agents |
      (unique_agent_count($agent_map; (.credential_access // false) == true)) as $credential_access_agents |
      (unique_agent_count($agent_map; (.production_write // false) == true)) as $production_write_agents |
      ($attack_paths | map(select(((.edge_rationale // []) | map(select(type == "string" and test("^agent_to_"))) | length) > 0)) | length) as $agent_linked_attack_paths |
      ($frameworks
        | map({
            framework_id: (.framework_id // .framework // ""),
            title: (.title // .framework // ""),
            mapped_finding_count: (.mapped_finding_count // 0),
            control_count: (.control_count // ((.controls // []) | length)),
            covered_count: (.covered_count // 0),
            coverage_percent: (.coverage_percent // 0)
          })
        | map(select(.framework_id == "eu-ai-act" or .framework_id == "soc2" or .framework_id == "pci-dss"))
       ) as $headline_frameworks |
      {
        schema_version: "v2",
        generated_at: $generated_at,
        target: $target,
        org: $org,
        repo: $repo,
        scan_status: ($s.status // "unknown"),
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
          production_write_tools: $production_write_tools,
          declared_agents: $declared_agents,
          deployed_agents: $deployed_agents,
          binding_complete_agents: $binding_complete_agents,
          binding_incomplete_agents: $binding_incomplete_agents,
          write_capable_agents: $write_capable_agents,
          exec_capable_agents: $exec_capable_agents,
          credential_access_agents: $credential_access_agents,
          production_write_agents: $production_write_agents,
          agent_linked_attack_paths: $agent_linked_attack_paths
        },
        flags: {
          org_has_agents: ($declared_agents > 0),
          org_has_deployed_agents: ($deployed_agents > 0),
          org_has_agents_missing_bindings: ($binding_incomplete_agents > 0),
          org_has_write_capable_agents: ($write_capable_agents > 0),
          org_has_exec_capable_agents: ($exec_capable_agents > 0),
          org_has_credential_access_agents: ($credential_access_agents > 0),
          org_has_production_write_agents: ($production_write_agents > 0),
          org_has_agent_linked_attack_paths: ($agent_linked_attack_paths > 0)
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
          article50_controls_missing_count: $article50_controls_missing_count
        },
        inventory_summary: {
          agent_frameworks: unique_strings($agents | map(.framework // "")),
          headline_frameworks: $headline_frameworks
        }
      }
    ' > "${state_path}"

  state_inputs+=("${state_path}")
done

jq -s \
  --arg run_id "${RUN_ID}" \
  --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg mode "${MODE}" \
  --arg detector_list "${DETECTOR_LIST}" '
  def pct(n; d): if d == 0 then 0 else ((n * 10000 / d) | round) / 100 end;
  def ratio(n; d): if d == 0 then 0 else ((n * 100 / d) | round) / 100 end;
  def avg(n; d): if d == 0 then 0 else ((n * 100 / d) | round) / 100 end;
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
    schema_version: "v2",
    report_id: "ai-tool-sprawl-v2-2026",
    run_id: $run_id,
    generated_at: $generated_at,
    campaign: {
      scans: (map(.target)),
      metrics: {
        orgs_scanned: length,
        avg_approval_unknown_tools_per_org: avg((map(.counts.approval_unknown // 0) | add); length),
        explicit_unapproved_to_approved_ratio: ratio((map(.counts.explicit_unapproved // 0) | add); (map(.counts.approved // 0) | add)),
        not_baseline_approved_to_approved_ratio: ratio((map(.counts.not_baseline_approved // 0) | add); (map(.counts.approved // 0) | add)),
        article50_gap_prevalence_pct: pct((map(select(.control_posture.article50_gap == true)) | length); length),
        article50_controls_missing_median: median((map(.control_posture.article50_controls_missing_count // 4))),
        orgs_without_verifiable_evidence_pct: pct((map(select(.control_posture.evidence_verifiable != true)) | length); length),
        orgs_with_destructive_tooling_pct: pct((map(select(.control_posture.destructive_tooling == true)) | length); length),
        orgs_without_approval_gate_pct: pct((map(select(.control_posture.approval_gate_absent == true)) | length); length),
        orgs_with_agents_pct: pct((map(select(.flags.org_has_agents == true)) | length); length),
        avg_agents_per_org: avg((map(.counts.declared_agents // 0) | add); length),
        orgs_with_deployed_agents_pct: pct((map(select(.flags.org_has_deployed_agents == true)) | length); length),
        orgs_with_agents_missing_bindings_pct: pct((map(select(.flags.org_has_agents_missing_bindings == true)) | length); length),
        agents_missing_bindings_pct: pct((map(.counts.binding_incomplete_agents // 0) | add); (map(.counts.declared_agents // 0) | add)),
        orgs_with_write_capable_agents_pct: pct((map(select(.flags.org_has_write_capable_agents == true)) | length); length),
        orgs_with_exec_capable_agents_pct: pct((map(select(.flags.org_has_exec_capable_agents == true)) | length); length),
        orgs_with_credential_access_agents_pct: pct((map(select(.flags.org_has_credential_access_agents == true)) | length); length),
        orgs_with_production_write_agents_pct: pct((map(select(.flags.org_has_production_write_agents == true)) | length); length),
        orgs_with_agent_attack_paths_pct: pct((map(select(.flags.org_has_agent_linked_attack_paths == true)) | length); length)
      },
      totals: {
        tools_detected: (map(.counts.tools_detected // 0) | add),
        approved_tools: (map(.counts.approved // 0) | add),
        explicit_unapproved_tools: (map(.counts.explicit_unapproved // 0) | add),
        approval_unknown_tools: (map(.counts.approval_unknown // 0) | add),
        not_baseline_approved_tools: (map(.counts.not_baseline_approved // 0) | add),
        production_write_tools: (map(.counts.production_write_tools // 0) | add),
        declared_agents: (map(.counts.declared_agents // 0) | add),
        deployed_agents: (map(.counts.deployed_agents // 0) | add),
        binding_complete_agents: (map(.counts.binding_complete_agents // 0) | add),
        binding_incomplete_agents: (map(.counts.binding_incomplete_agents // 0) | add),
        write_capable_agents: (map(.counts.write_capable_agents // 0) | add),
        exec_capable_agents: (map(.counts.exec_capable_agents // 0) | add),
        credential_access_agents: (map(.counts.credential_access_agents // 0) | add),
        production_write_agents: (map(.counts.production_write_agents // 0) | add),
        agent_linked_attack_paths: (map(.counts.agent_linked_attack_paths // 0) | add)
      },
      segmented_totals: {
        headline_scope: "exclude_source_repo",
        source_repo_tools: (map(.segments.source_repo_tools // 0) | add),
        tools_detected_raw: (map(.segments.raw_counts.tools_detected // .counts.tools_detected // 0) | add),
        approved_tools_raw: (map(.segments.raw_counts.approved // .counts.approved // 0) | add),
        explicit_unapproved_tools_raw: (map(.segments.raw_counts.explicit_unapproved // 0) | add),
        approval_unknown_tools_raw: (map(.segments.raw_counts.approval_unknown // 0) | add),
        not_baseline_approved_tools_raw: (map(.segments.raw_counts.not_baseline_approved // 0) | add),
        unknown_tools_raw_legacy: (map(.segments.raw_counts.unknown_legacy // 0) | add)
      }
    },
    methodology: {
      mode: $mode,
      detector_list: $detector_list,
      target_unit: "one public owner/repo per row",
      headline_scope: "exclude_source_repo for tool metrics"
    }
  }
' "${state_inputs[@]}" > "${AGG_DIR}/campaign-summary-v2.json"

jq -n \
  --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg run_id "${RUN_ID}" \
  --arg summary_path "runs/tool-sprawl/${RUN_ID}/agg/campaign-summary-v2.json" \
  '{
    schema_version: "v2",
    generated_at: $generated_at,
    run_id: $run_id,
    summary_path: $summary_path,
    status: "ok"
  }' > "${AGG_DIR}/campaign-envelope-v2.json"

orgs_scanned="$(jq -r '.campaign.metrics.orgs_scanned' "${AGG_DIR}/campaign-summary-v2.json")"
ratio_not_baseline="$(jq -r '.campaign.metrics.not_baseline_approved_to_approved_ratio' "${AGG_DIR}/campaign-summary-v2.json")"
orgs_with_agents="$(jq -r '.campaign.metrics.orgs_with_agents_pct' "${AGG_DIR}/campaign-summary-v2.json")"
avg_agents="$(jq -r '.campaign.metrics.avg_agents_per_org' "${AGG_DIR}/campaign-summary-v2.json")"
orgs_with_deployed="$(jq -r '.campaign.metrics.orgs_with_deployed_agents_pct' "${AGG_DIR}/campaign-summary-v2.json")"
orgs_with_write_agents="$(jq -r '.campaign.metrics.orgs_with_write_capable_agents_pct' "${AGG_DIR}/campaign-summary-v2.json")"
orgs_with_attack_paths="$(jq -r '.campaign.metrics.orgs_with_agent_attack_paths_pct' "${AGG_DIR}/campaign-summary-v2.json")"
without_verifiable_evidence="$(jq -r '.campaign.metrics.orgs_without_verifiable_evidence_pct' "${AGG_DIR}/campaign-summary-v2.json")"

cat > "${AGG_DIR}/campaign-public-v2.md" <<EOF_PUBLIC
# AI Tool and Agent Sprawl Campaign Summary

Run ID: ${RUN_ID}

- Organizations scanned: ${orgs_scanned}
- Not-baseline-approved to baseline-approved tool ratio (non-source scope): ${ratio_not_baseline}
- Organizations with declared agents (%): ${orgs_with_agents}
- Average declared agents per organization: ${avg_agents}
- Organizations with deployed agents (%): ${orgs_with_deployed}
- Organizations with write-capable agents (%): ${orgs_with_write_agents}
- Organizations with agent-linked attack paths (%): ${orgs_with_attack_paths}
- Organizations without verifiable evidence tier (%): ${without_verifiable_evidence}
EOF_PUBLIC

tmp_states_json="$(mktemp)"
tmp_scans_json="$(mktemp)"
trap 'rm -f "${tmp_states_json}" "${tmp_scans_json}"' EXIT

jq -s '.' "${state_inputs[@]}" > "${tmp_states_json}"
find "${SCANS_DIR}" -type f -name '*.scan.json' | sort | while IFS= read -r scan; do
  jq -c '.' "${scan}"
done | jq -s '.' > "${tmp_scans_json}"

jq -n \
  --arg run_id "${RUN_ID}" \
  --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --slurpfile states "${tmp_states_json}" \
  --slurpfile scans "${tmp_scans_json}" '
  (($states[0] // []) as $state_rows |
  ($scans[0] // []) as $scan_rows |

  def join_pipe($xs):
    ($xs // [])
    | map(
        if type == "string" then .
        elif type == "number" or type == "boolean" then tostring
        else @json
        end
      )
    | join("|");

  def scan_target($scan):
    if (($scan.target // null) | type) == "string" then ($scan.target // "unknown")
    elif (($scan.target // null) | type) == "object" then ($scan.target.value // "unknown")
    else "unknown"
    end;

  def org_from_target($target):
    (($target | split("/"))[0] // "unknown");

  def repo_from_target($target):
    (($target | split("/"))[1] // "unknown");

  def slug($target):
    ($target | ascii_downcase | gsub("[/:]"; "-") | gsub("[^a-z0-9._-]+"; "-"));

  def state_for($target):
    ($state_rows | map(select(.target == $target)) | .[0]);

  def tool_rows:
    [ $scan_rows[] as $scan
      | (scan_target($scan)) as $target
      | ($scan.inventory.tools // []) as $raw_tools
      | if ($raw_tools | type) == "array" then $raw_tools else [] end
      | .[]?
      | {
          target: $target,
          org: org_from_target($target),
          repo: repo_from_target($target),
          headline_in_scope: (((.tool_type // "") != "source_repo")),
          tool_id: (.tool_id // ""),
          agent_id: (.agent_id // ""),
          tool_type: (.tool_type // ""),
          tool_category: (.tool_category // ""),
          approval_classification: (.approval_classification // ""),
          approval_status: (.approval_status // ""),
          permission_tier: (.permission_tier // ""),
          risk_tier: (.risk_tier // ""),
          adoption_pattern: (.adoption_pattern // ""),
          endpoint_class: (.endpoint_class // ""),
          data_class: (.data_class // ""),
          autonomy_level: (.autonomy_level // ""),
          risk_score: (.risk_score // 0),
          confidence_score: (.confidence_score // 0),
          lifecycle_state: (.lifecycle_state // ""),
          repos: (.repos // []),
          permissions: (.permissions // []),
          location_count: ((.locations // []) | length),
          locations: (.locations // []),
          regulatory_mapping: (.regulatory_mapping // [])
        }
    ];

  def agent_rows:
    [ $scan_rows[] as $scan
      | (scan_target($scan)) as $target
      | ($scan.inventory.agents // []) as $raw_agents
      | if ($raw_agents | type) == "array" then $raw_agents else [] end
      | .[]?
      | {
          target: $target,
          org: org_from_target($target),
          repo: (.repo // repo_from_target($target)),
          agent_id: (.agent_id // ""),
          agent_instance_id: (.agent_instance_id // ""),
          framework: (.framework // ""),
          location: (.location // ""),
          location_range: (.location_range // null),
          bound_tools: (.bound_tools // []),
          bound_data_sources: (.bound_data_sources // []),
          bound_auth_surfaces: (.bound_auth_surfaces // []),
          binding_evidence_keys: (.binding_evidence_keys // []),
          missing_bindings: (.missing_bindings // []),
          binding_complete: (((.missing_bindings // []) | length) == 0),
          deployment_status: (.deployment_status // ""),
          deployment_artifacts: (.deployment_artifacts // []),
          deployment_evidence_keys: (.deployment_evidence_keys // [])
        }
    ];

  def agent_privilege_rows:
    [ $scan_rows[] as $scan
      | (scan_target($scan)) as $target
      | ($scan.agent_privilege_map // []) as $raw_map
      | if ($raw_map | type) == "array" then $raw_map else [] end
      | .[]?
      | {
          target: $target,
          org: (.org // org_from_target($target)),
          repos: (.repos // []),
          agent_id: (.agent_id // ""),
          tool_id: (.tool_id // ""),
          tool_type: (.tool_type // ""),
          framework: (.framework // ""),
          approval_classification: (.approval_classification // ""),
          permissions: (.permissions // []),
          endpoint_class: (.endpoint_class // ""),
          data_class: (.data_class // ""),
          autonomy_level: (.autonomy_level // ""),
          risk_score: (.risk_score // 0),
          bound_tools: (.bound_tools // []),
          bound_data_sources: (.bound_data_sources // []),
          bound_auth_surfaces: (.bound_auth_surfaces // []),
          binding_evidence_keys: (.binding_evidence_keys // []),
          missing_bindings: (.missing_bindings // []),
          deployment_status: (.deployment_status // ""),
          deployment_artifacts: (.deployment_artifacts // []),
          deployment_evidence_keys: (.deployment_evidence_keys // []),
          write_capable: (.write_capable // false),
          credential_access: (.credential_access // false),
          exec_capable: (.exec_capable // false),
          production_write: (.production_write // false),
          matched_production_targets: (.matched_production_targets // [])
        }
    ];

  def attack_path_rows:
    [ $scan_rows[] as $scan
      | (scan_target($scan)) as $target
      | ($scan.attack_paths // []) as $raw_paths
      | if ($raw_paths | type) == "array" then $raw_paths else [] end
      | .[]?
      | {
          target: $target,
          org: (.org // org_from_target($target)),
          repo: (.repo // repo_from_target($target)),
          path_id: (.path_id // ""),
          path_score: (.path_score // 0),
          entry_node_id: (.entry_node_id // ""),
          pivot_node_id: (.pivot_node_id // ""),
          target_node_id: (.target_node_id // ""),
          entry_exposure: (.entry_exposure // 0),
          pivot_privilege: (.pivot_privilege // 0),
          target_impact: (.target_impact // 0),
          edge_rationale: (.edge_rationale // []),
          explain: (.explain // []),
          source_findings: (.source_findings // []),
          generation_model: (.generation_model // ""),
          agent_linked: (((.edge_rationale // []) | map(select(type == "string" and test("^agent_to_"))) | length) > 0)
        }
    ];

  def framework_rollup_rows:
    [ $scan_rows[] as $scan
      | (scan_target($scan)) as $target
      | ($scan.compliance_summary.frameworks // []) as $raw_frameworks
      | if ($raw_frameworks | type) == "array" then $raw_frameworks else [] end
      | .[]? as $framework
      | (($framework.controls // []) as $controls
         | if ($controls | type) == "array" then $controls else [] end) as $control_rows
      | if ($control_rows | length) == 0 then
          {
            target: $target,
            org: org_from_target($target),
            repo: repo_from_target($target),
            row_type: "framework",
            framework_id: ($framework.framework_id // $framework.framework // ""),
            framework_title: ($framework.title // $framework.framework // ""),
            framework_version: ($framework.version // ""),
            control_count: ($framework.control_count // 0),
            covered_count: ($framework.covered_count // 0),
            coverage_percent: ($framework.coverage_percent // 0),
            mapped_finding_count: ($framework.mapped_finding_count // 0),
            control_id: "",
            control_title: "",
            control_kind: "",
            control_status: "",
            mapped_rule_ids: [],
            finding_count: 0,
            headline_eligible: ((($framework.framework_id // $framework.framework // "") == "eu-ai-act") or (($framework.framework_id // $framework.framework // "") == "soc2") or (($framework.framework_id // $framework.framework // "") == "pci-dss"))
          }
        else
          $control_rows[]
          | {
              target: $target,
              org: org_from_target($target),
              repo: repo_from_target($target),
              row_type: "control",
              framework_id: ($framework.framework_id // $framework.framework // ""),
              framework_title: ($framework.title // $framework.framework // ""),
              framework_version: ($framework.version // ""),
              control_count: ($framework.control_count // ($control_rows | length)),
              covered_count: ($framework.covered_count // 0),
              coverage_percent: ($framework.coverage_percent // 0),
              mapped_finding_count: ($framework.mapped_finding_count // 0),
              control_id: (.control_id // ""),
              control_title: (.title // ""),
              control_kind: (.control_kind // ""),
              control_status: (.status // ""),
              mapped_rule_ids: (.mapped_rule_ids // []),
              finding_count: (.finding_count // 0),
              headline_eligible: ((($framework.framework_id // $framework.framework // "") == "eu-ai-act") or (($framework.framework_id // $framework.framework // "") == "soc2") or (($framework.framework_id // $framework.framework // "") == "pci-dss"))
            }
        end
    ];

  def regulatory_mapping_rows:
    [ tool_rows[] as $tool
      | ($tool.regulatory_mapping // [])[]?
      | {
          target: $tool.target,
          org: $tool.org,
          repo: $tool.repo,
          tool_id: $tool.tool_id,
          tool_type: $tool.tool_type,
          headline_in_scope: $tool.headline_in_scope,
          regulation: (.regulation // ""),
          control_id: (.control_id // ""),
          status: (.status // ""),
          rationale: (.rationale // ""),
          headline_eligible: (((.regulation // "") == "EU AI Act") or ((.regulation // "") == "SOC 2") or ((.regulation // "") == "PCI DSS 4.0.1"))
        }
    ];

  {
    schema_version: "v2",
    export_version: "2",
    generated_at: $generated_at,
    run_id: $run_id,
    org_rows: $state_rows,
    tool_rows: tool_rows,
    agent_rows: agent_rows,
    agent_privilege_rows: agent_privilege_rows,
    attack_path_rows: attack_path_rows,
    framework_rollup_rows: framework_rollup_rows,
    regulatory_mapping_rows: regulatory_mapping_rows
  })
' > "${APPENDIX_DIR}/combined-appendix-v2.json"

jq -r '
  (["org","repo","target","headline_in_scope","tool_id","agent_id","tool_type","tool_category","approval_classification","approval_status","permission_tier","risk_tier","adoption_pattern","endpoint_class","data_class","autonomy_level","risk_score","confidence_score","lifecycle_state","repos","permissions","location_count","locations_json"] | @csv),
  (.tool_rows[] | [
    .org, .repo, .target, (.headline_in_scope | tostring), .tool_id, .agent_id, .tool_type, .tool_category,
    .approval_classification, .approval_status, .permission_tier, .risk_tier, .adoption_pattern,
    .endpoint_class, .data_class, .autonomy_level, (.risk_score | tostring), (.confidence_score | tostring),
    .lifecycle_state, ((.repos // []) | join("|")), ((.permissions // []) | join("|")),
    (.location_count | tostring), ((.locations // []) | @json)
  ] | @csv)
' "${APPENDIX_DIR}/combined-appendix-v2.json" > "${APPENDIX_DIR}/tool-inventory.csv"

jq -r '
  (["org","repo","target","agent_id","agent_instance_id","framework","location","location_range_json","bound_tools","bound_data_sources","bound_auth_surfaces","binding_evidence_keys","missing_bindings","binding_complete","deployment_status","deployment_artifacts","deployment_evidence_keys"] | @csv),
  (.agent_rows[] | [
    .org, .repo, .target, .agent_id, .agent_instance_id, .framework, .location, (.location_range | @json),
    ((.bound_tools // []) | join("|")), ((.bound_data_sources // []) | join("|")), ((.bound_auth_surfaces // []) | join("|")),
    ((.binding_evidence_keys // []) | join("|")), ((.missing_bindings // []) | join("|")), (.binding_complete | tostring),
    .deployment_status, ((.deployment_artifacts // []) | join("|")), ((.deployment_evidence_keys // []) | join("|"))
  ] | @csv)
' "${APPENDIX_DIR}/combined-appendix-v2.json" > "${APPENDIX_DIR}/agent-inventory.csv"

jq -r '
  (["org","target","agent_id","tool_id","tool_type","framework","approval_classification","write_capable","credential_access","exec_capable","production_write","matched_production_targets","repos","permissions","bound_tools","bound_data_sources","bound_auth_surfaces","missing_bindings","deployment_status","deployment_artifacts","risk_score"] | @csv),
  (.agent_privilege_rows[] | [
    .org, .target, .agent_id, .tool_id, .tool_type, .framework, .approval_classification,
    (.write_capable | tostring), (.credential_access | tostring), (.exec_capable | tostring), (.production_write | tostring),
    ((.matched_production_targets // []) | join("|")), ((.repos // []) | join("|")), ((.permissions // []) | join("|")),
    ((.bound_tools // []) | join("|")), ((.bound_data_sources // []) | join("|")), ((.bound_auth_surfaces // []) | join("|")),
    ((.missing_bindings // []) | join("|")), .deployment_status, ((.deployment_artifacts // []) | join("|")), (.risk_score | tostring)
  ] | @csv)
' "${APPENDIX_DIR}/combined-appendix-v2.json" > "${APPENDIX_DIR}/agent-privilege-map.csv"

jq -r '
  (["org","repo","target","path_id","path_score","entry_node_id","pivot_node_id","target_node_id","entry_exposure","pivot_privilege","target_impact","agent_linked","edge_rationale","explain","source_findings","generation_model"] | @csv),
  (.attack_path_rows[] | [
    .org, .repo, .target, .path_id, (.path_score | tostring), .entry_node_id, .pivot_node_id, .target_node_id,
    (.entry_exposure | tostring), (.pivot_privilege | tostring), (.target_impact | tostring), (.agent_linked | tostring),
    ((.edge_rationale // []) | join("|")), ((.explain // []) | join("|")), ((.source_findings // []) | join("|")), .generation_model
  ] | @csv)
' "${APPENDIX_DIR}/combined-appendix-v2.json" > "${APPENDIX_DIR}/attack-paths.csv"

jq -r '
  (["org","repo","target","row_type","framework_id","framework_title","framework_version","headline_eligible","control_count","covered_count","coverage_percent","mapped_finding_count","control_id","control_title","control_kind","control_status","mapped_rule_ids","finding_count"] | @csv),
  (.framework_rollup_rows[] | [
    .org, .repo, .target, .row_type, .framework_id, .framework_title, .framework_version, (.headline_eligible | tostring),
    (.control_count | tostring), (.covered_count | tostring), (.coverage_percent | tostring), (.mapped_finding_count | tostring),
    .control_id, .control_title, .control_kind, .control_status, ((.mapped_rule_ids // []) | join("|")), (.finding_count | tostring)
  ] | @csv)
' "${APPENDIX_DIR}/combined-appendix-v2.json" > "${APPENDIX_DIR}/framework-rollups.csv"

jq -r '
  (["org","repo","target","tool_id","tool_type","headline_in_scope","regulation","control_id","status","rationale","headline_eligible"] | @csv),
  (.regulatory_mapping_rows[] | [
    .org, .repo, .target, .tool_id, .tool_type, (.headline_in_scope | tostring), .regulation, .control_id, .status, .rationale, (.headline_eligible | tostring)
  ] | @csv)
' "${APPENDIX_DIR}/combined-appendix-v2.json" > "${APPENDIX_DIR}/regulatory-gap-matrix-v2.csv"

jq -r '
  (["org","repo","target","tools_detected","approved","explicit_unapproved","approval_unknown","not_baseline_approved","declared_agents","deployed_agents","binding_incomplete_agents","write_capable_agents","exec_capable_agents","credential_access_agents","production_write_agents","agent_linked_attack_paths","article50_gap","evidence_tier","evidence_verifiable"] | @csv),
  (.org_rows[] | [
    .org, .repo, .target,
    (.counts.tools_detected | tostring), (.counts.approved | tostring), (.counts.explicit_unapproved | tostring),
    (.counts.approval_unknown | tostring), (.counts.not_baseline_approved | tostring),
    (.counts.declared_agents | tostring), (.counts.deployed_agents | tostring), (.counts.binding_incomplete_agents | tostring),
    (.counts.write_capable_agents | tostring), (.counts.exec_capable_agents | tostring), (.counts.credential_access_agents | tostring),
    (.counts.production_write_agents | tostring), (.counts.agent_linked_attack_paths | tostring),
    (.control_posture.article50_gap | tostring), .control_posture.evidence_tier, (.control_posture.evidence_verifiable | tostring)
  ] | @csv)
' "${APPENDIX_DIR}/combined-appendix-v2.json" > "${APPENDIX_DIR}/org-summary-v2.csv"

"${REPO_ROOT}/pipelines/common/metric_coverage_gate.sh" \
  --report-id "ai-tool-sprawl-v2-2026" \
  --claims "${CLAIMS_FILE_PATH}" \
  --thresholds "${THRESHOLDS_FILE_PATH}" \
  --strict

"${REPO_ROOT}/pipelines/common/derive_claim_values.sh" \
  --repo-root "${REPO_ROOT}" \
  --claims "${CLAIMS_FILE_PATH}" \
  --run-id "${RUN_ID}" \
  --output "${ARTIFACTS_DIR}/claim-values-v2.json" \
  --strict

"${REPO_ROOT}/pipelines/common/evaluate_claim_values.sh" \
  --report-id "ai-tool-sprawl-v2-2026" \
  --claim-values "${ARTIFACTS_DIR}/claim-values-v2.json" \
  --thresholds "${THRESHOLDS_FILE_PATH}" \
  --repo-root "${REPO_ROOT}" \
  --output "${ARTIFACTS_DIR}/threshold-evaluation-v2.json"

echo "[sprawl-rebuild-v2] rebuilt run ${RUN_ID}"
echo "[sprawl-rebuild-v2] campaign summary: ${AGG_DIR}/campaign-summary-v2.json"
