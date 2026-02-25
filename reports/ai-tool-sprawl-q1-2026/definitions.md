# AI Tool Sprawl Q1 2026 Definitions (Locked for This Cycle)

Status: draft lock candidate  
Version: `v2`  
Effective date: `2026-02-25`

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

## Scope Definitions

- Organization scan unit: one org entry from campaign list.
- Included repositories: deterministic acquisition scope as recorded in methodology.
- Excluded entities: private/non-resolvable targets outside defined acquisition policy.

## Change Control

- No in-cycle redefinition without version bump and rerun.
- Any metric logic change requires claims and threshold updates.
