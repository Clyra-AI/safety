# AI Tool Sprawl Q1 2026 Definitions (Locked for This Cycle)

Status: locked  
Version: `v3`  
Effective date: `2026-02-26`

This file defines canonical classifications and formulas for the Q1 2026 sprawl report.
If changed, bump version and rerun campaign metrics.

## Headline scope filter

Headline metrics exclude tools where `tool_type == "source_repo"`.

- `source_repo` detections are retained in segmented totals for transparency.
- Headline claims are computed from the non-`source_repo` subset only.

## Core Classifications

## Approved tool

A discovered AI tool classified as `approved` only when deterministically matched to the approved-tool policy/list used for the campaign.

## Unapproved tool

A discovered AI tool classified as `unapproved` when:

- it is not matched to approved list policy, and
- sufficient identity evidence exists to classify tool instance.

## Unknown tool

A discovered AI tool classified as `unknown` when:

- identity evidence is incomplete/ambiguous for approval classification, or
- approval policy coverage cannot deterministically resolve status.

## Production-write exposure

A tool contributes to production-write exposure only when:

- production-target policy is configured and valid, and
- detected write-capable permission intersects configured production targets.

If policy is not configured, production-write claims are omitted.

## Destructive-capable tooling (organization-level)

Deterministic proxy used in this report cycle:

- `true` when at least one non-`source_repo` tool has write/admin permission surface or `proc.exec` permission.
- `false` otherwise.

## Approval-gated execution (organization-level)

Deterministic proxy used in this report cycle:

- Evaluate only non-`source_repo` risky tools (same risky definition as above).
- `approval_gate_present = true` when every risky tool is approval-classified as `approved`.
- `approval_gate_present = false` when no risky tools exist or any risky tool is not `approved`.

Prompt instructions alone do not qualify as an approval gate.

## Prompt-only controls (organization-level)

Deterministic proxy used in this report cycle:

- `true` when prompt-channel tooling is detected (`tool_type == "prompt_channel"`) or policy rule `WRKR-016` fails.
- `false` otherwise.

## Auditable decision artifacts (organization-level)

Deterministic proxy used in this report cycle:

- `true` when policy rules `WRKR-003` and `WRKR-008` are not failing.
- `false` when either fails.

## Transparency gap (EU AI Act Article 50 proxy)

Deterministic proxy used in this report cycle:

- Evaluate non-`source_repo` scope only.
- `true` when at least one scoped tool exists and any of:
  - scoped unknown-tool count > 0
  - scoped unapproved-tool count > 0
  - auditable decision artifacts proxy is `false`
- `false` otherwise.

## Headline Metrics

## Hero metric

`sprawl_unapproved_to_approved_ratio`

Definition:

- aggregate unapproved tool count divided by aggregate approved tool count.
- if denominator is zero, metric is marked undefined and report must not publish ratio claim.

## Supporting metric

`sprawl_avg_unknown_tools_per_org`

Definition:

- aggregate unknown tool count divided by scanned organization count.

## Supporting metric

`sprawl_article50_gap_prevalence_pct`

Definition:

- percentage of scanned organizations flagged with Article 50 transparency gap proxy.

## Supporting metric

`sprawl_orgs_with_destructive_tooling_pct`

Definition:

- percentage of scanned organizations with at least one destructive-capable AI tool in observed scope.

## Supporting metric

`sprawl_orgs_without_approval_gate_pct`

Definition:

- percentage of scanned organizations with destructive-capable tooling and no enforceable approval gate.

## Supporting metric

`sprawl_orgs_prompt_only_controls_pct`

Definition:

- percentage of scanned organizations where control evidence is prompt-only for risky actions.

## Supporting metric

`sprawl_orgs_without_audit_artifacts_pct`

Definition:

- percentage of scanned organizations lacking auditable decision artifacts for risky actions.

## Scope Definitions

- Organization scan unit: one org entry from campaign list.
- Included repositories: deterministic acquisition scope as recorded in methodology.
- Excluded entities: private/non-resolvable targets outside defined acquisition policy.

## Change Control

- No in-cycle redefinition without version bump and rerun.
- Any metric logic change requires claims and threshold updates.
