# AI Tool Sprawl Q1 2026 Definitions (Locked for This Cycle)

Status: locked  
Version: `v4`  
Effective date: `2026-03-03`

This file defines canonical classifications and formulas for the Q1 2026 sprawl report.
If changed, bump version and rerun campaign metrics.

## Headline scope filter

Headline metrics exclude tools where `tool_type == "source_repo"`.

- `source_repo` detections are retained in segmented totals for transparency.
- Headline claims are computed from the non-`source_repo` subset only.

## Core Classifications

## Baseline-approved tool

A discovered AI tool classified as baseline-approved only when deterministically matched to the approved-tool policy/list used for the campaign.

## Explicit-unapproved tool

A discovered AI tool classified as explicit-unapproved when:

- approval classification is `unapproved`, and
- approval evidence is present (not missing/unknown/null).

## Approval-unknown tool

A discovered AI tool classified as approval-unknown when:

- approval evidence is incomplete/ambiguous, or
- approval policy coverage cannot deterministically resolve status.

## Not-baseline-approved tool

Union set used for publication claims:

- `not_baseline_approved = explicit_unapproved + approval_unknown`.

## Production-write exposure

A tool contributes to production-write exposure only when:

- production-target policy is configured and valid, and
- detected write-capable permission intersects configured production targets.

If policy is not configured, production-write claims are omitted.

## Control Posture Derivations (Organization-Level)

## Destructive tooling

Deterministic proxy used in this report cycle:

- `true` when at least one non-`source_repo` tool has write/admin permission surface or `proc.exec`.
- `false` otherwise.

## Approval gate present / absent

Deterministic proxy used in this report cycle:

- evaluate only risky non-`source_repo` tools.
- `approval_gate_present = true` when every risky tool is baseline-approved.
- `approval_gate_present = false` when no risky tools exist or any risky tool is not baseline-approved.
- `approval_gate_absent = destructive_tooling == true and approval_gate_present == false`.

## Prompt-only controls

Deterministic proxy used in this report cycle:

- `true` when prompt-channel tooling is detected (`tool_type == "prompt_channel"`) or policy rule `WRKR-016` fails.
- `false` otherwise.

## Evidence tier

Deterministic proxy used in this report cycle:

- `verifiable` when neither `WRKR-003` nor `WRKR-008` fails.
- `basic` when exactly one of `WRKR-003` or `WRKR-008` fails.
- `none` when both `WRKR-003` and `WRKR-008` fail.

Derived booleans:

- `audit_artifacts_present = evidence_tier == "verifiable"`
- `evidence_verifiable = evidence_tier == "verifiable"`

## EU AI Act Article 50 transparency proxy

Four deterministic control flags are calculated per organization:

1. `approval_resolved`: approval-unknown count is zero.
2. `no_explicit_unapproved`: explicit-unapproved count is zero.
3. `evidence_verifiable`: evidence tier is verifiable.
4. `not_prompt_only`: prompt-only controls flag is false.

Derived controls score:

- `article50_controls_present_count` (0-4)
- `article50_controls_missing_count = 4 - article50_controls_present_count`

Gap proxy definition:

- `article50_gap = true` when scoped tool count > 0 and any of:
  - approval-unknown count > 0
  - explicit-unapproved count > 0
  - evidence tier is not verifiable
- otherwise `false`.

This is a deterministic control proxy, not a legal determination.

## Headline Metrics

Primary:

- `sprawl_not_baseline_approved_to_approved_ratio`

Supporting:

- `sprawl_explicit_unapproved_to_approved_ratio`
- `sprawl_avg_approval_unknown_tools_per_org`
- `sprawl_article50_gap_prevalence_pct`
- `sprawl_article50_controls_missing_median`
- `sprawl_orgs_scanned`
- `sprawl_orgs_with_destructive_tooling_pct`
- `sprawl_orgs_without_approval_gate_pct`
- `sprawl_orgs_without_verifiable_evidence_pct`

## Scope Definitions

- Organization scan unit: one target entry from campaign list.
- Included repositories: deterministic acquisition scope as recorded in methodology.
- Excluded entities: private/non-resolvable targets outside defined acquisition policy.

## Change Control

- No in-cycle redefinition without version bump and rerun.
- Any metric logic change requires claims and threshold updates.
