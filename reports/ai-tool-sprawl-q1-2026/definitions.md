# AI Tool Sprawl Q1 2026 Definitions (Locked for This Cycle)

Status: locked  
Version: `v3`  
Effective date: `2026-02-26`

This file defines canonical classifications and formulas for the Q1 2026 sprawl report.
If changed, bump version and rerun campaign metrics.

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

An organization is marked as having destructive-capable AI tooling when at least one discovered tool instance has permissions/actions that can irreversibly mutate/delete/exfiltrate high-value state and that tooling is reachable in the measured execution surface.

## Approval-gated execution (organization-level)

An organization is marked as approval-gated when destructive-capable actions require non-prompt approval controls before execution (for example policy gate with non-executable default and explicit approval token/workflow).

Prompt instructions alone do not qualify as an approval gate.

## Prompt-only controls (organization-level)

An organization is marked prompt-only when primary/sole control evidence for risky actions is natural-language instructions/prompts without enforceable tool-boundary policy or approval gate.

## Auditable decision artifacts (organization-level)

An organization has auditable decision artifacts when policy decisions/outcomes for risky actions can be traced via verifiable logs/runpacks/artifacts with stable identifiers.

## Transparency gap (EU AI Act Article 50 proxy)

An organization is flagged with transparency gap when campaign evidence indicates inability to provide baseline AI system/tool inventory and traceable usage evidence for discovered tooling.

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
