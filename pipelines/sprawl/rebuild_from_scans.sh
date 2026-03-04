#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  rebuild_from_scans.sh --run-id <id> [--targets-file <path>] [--mode baseline-only|baseline+enrich] [--detector-list <csv>]

Rebuilds derived state, campaign summary, appendix exports, claim-values, threshold evaluation,
and manifest hash from existing scan artifacts under runs/tool-sprawl/<run_id>/scans.
USAGE
}

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUN_ID=""
TARGETS_FILE="internal/repos.md"
MODE="baseline-only"
DETECTOR_LIST="default"

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
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[sprawl-rebuild] unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "${RUN_ID}" ]]; then
  echo "[sprawl-rebuild] --run-id is required" >&2
  exit 1
fi

RUN_DIR="${REPO_ROOT}/runs/tool-sprawl/${RUN_ID}"
if [[ ! -d "${RUN_DIR}" ]]; then
  echo "[sprawl-rebuild] run directory not found: ${RUN_DIR}" >&2
  exit 1
fi

TARGETS_FILE_PATH="${TARGETS_FILE}"
if [[ "${TARGETS_FILE_PATH}" != /* ]]; then
  TARGETS_FILE_PATH="${REPO_ROOT}/${TARGETS_FILE_PATH}"
fi
if [[ ! -f "${TARGETS_FILE_PATH}" ]]; then
  echo "[sprawl-rebuild] targets file not found: ${TARGETS_FILE_PATH}" >&2
  exit 1
fi

parse_targets() {
  local file="$1"
  local line
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

mkdir -p "${RUN_DIR}/states" "${RUN_DIR}/agg" "${RUN_DIR}/appendix" "${RUN_DIR}/artifacts"

state_inputs=()
while IFS= read -r target; do
  slug="$(slugify "${target}")"
  scan_path="${RUN_DIR}/scans/${slug}.scan.json"
  state_path="${RUN_DIR}/states/${slug}.json"
  if [[ ! -f "${scan_path}" ]]; then
    echo "[sprawl-rebuild] missing scan for target ${target}: ${scan_path}" >&2
    exit 1
  fi

  org="${target%%/*}"
  repo="${target#*/}"
  if [[ "${org}" == "${repo}" ]]; then
    repo="unknown"
  fi

  jq -n --slurpfile scan "${scan_path}" \
    --arg target "${target}" \
    --arg org "${org}" \
    --arg repo "${repo}" \
    --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg source "wrkr-scan" \
    --arg scan_path "${scan_path}" \
    '
      ($scan[0] // {}) as $s |
      ($s.inventory.tools // []) as $tools |
      ($tools | map(select((.tool_type // "") != "source_repo"))) as $scoped |
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
      }
    ' > "${state_path}"

  state_inputs+=("${state_path}")
done < <(parse_targets "${TARGETS_FILE_PATH}")

if [[ "${#state_inputs[@]}" -eq 0 ]]; then
  echo "[sprawl-rebuild] no targets resolved" >&2
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
          if length == 0 then 0 else ((map(.counts.approval_unknown // .counts.unknown // 0) | add) * 10000 / length | round) / 100 end
        ),
        avg_unknown_tools_per_org: (
          if length == 0 then 0 else ((map(.counts.approval_unknown // .counts.unknown // 0) | add) * 10000 / length | round) / 100 end
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
    regulatory_rows: map({
      org: .org,
      regulation: "EU AI Act",
      control_id: "Article 50 Proxy",
      tool_id: (.target + ":tooling"),
      gap_status: (if .control_posture.article50_gap then "gap" else "covered" end),
      controls_missing_count: (.control_posture.article50_controls_missing_count // 0),
      evidence_ref: .scan_path
    }),
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

"${REPO_ROOT}/pipelines/common/derive_claim_values.sh" \
  --repo-root "${REPO_ROOT}" \
  --claims "claims/ai-tool-sprawl-q1-2026/claims.json" \
  --run-id "${RUN_ID}" \
  --output "${RUN_DIR}/artifacts/claim-values.json" \
  --strict

"${REPO_ROOT}/pipelines/common/evaluate_claim_values.sh" \
  --report-id "ai-tool-sprawl-q1-2026" \
  --claim-values "${RUN_DIR}/artifacts/claim-values.json" \
  --thresholds "${REPO_ROOT}/pipelines/config/publish-thresholds.json" \
  --repo-root "${REPO_ROOT}" \
  --output "${RUN_DIR}/artifacts/threshold-evaluation.json"

if [[ -f "${RUN_DIR}/artifacts/run-manifest.json" ]]; then
  tmp_manifest="$(mktemp)"
  jq --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
    .mode = "rebuild"
    | .status = "completed"
    | .created_at = $now
  ' "${RUN_DIR}/artifacts/run-manifest.json" > "${tmp_manifest}"
  mv "${tmp_manifest}" "${RUN_DIR}/artifacts/run-manifest.json"
fi

hash_args=(
  --input "${RUN_DIR}"
  --output "${RUN_DIR}/artifacts/manifest.sha256"
)
if [[ -f "${RUN_DIR}/artifacts/run-manifest.json" ]]; then
  scan_source="$(jq -r '.reproducibility.wrkr.scan_source // empty' "${RUN_DIR}/artifacts/run-manifest.json" 2>/dev/null || true)"
  if [[ "${scan_source}" == "clone" ]]; then
    hash_args+=(--exclude-prefix "sources/")
  fi
fi
"${REPO_ROOT}/pipelines/common/hash_manifest.sh" "${hash_args[@]}"

echo "[sprawl-rebuild] rebuilt run ${RUN_ID}"
