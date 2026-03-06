# AI Tool Sprawl Q1 2026 Pre-Registration

Status: locked with amendment record  
Version: `v7`

## Study Identity

- Report ID: `ai-tool-sprawl-q1-2026`
- Calibration run cohort: `internal/repos.md` (AI-native 50 pre-pass)
- Calibration reference run ID: `sprawl-ai50-prepass-20260303T203500Z`
- Calibration tuned reference run ID: `sprawl-ai50-clean-pci-20260305T125702Z`
- Canonical publication-campaign run ID: `sprawl-ai1000-clean-pci-20260305T130344Z`
- Planned publication window: `2026-04-01 to 2026-04-30 (target)`
- Target list source: `internal/repos-1000-clean.md`

## Locked Hypotheses

1. The sample will contain a measurable not-baseline-approved to baseline-approved AI tool gap.
2. A non-trivial fraction of organizations will show deterministic transparency-control proxy gaps.
3. Deterministic baseline and enrich outputs will diverge and must remain explicitly separated in reporting.
4. A measurable share of organizations will expose destructive tooling without enforceable approval gates.
5. A measurable share of organizations will lack verifiable evidence-tier controls.

## Primary and Secondary Endpoints

- Primary endpoint:
  - `sprawl_not_baseline_approved_to_approved_ratio`
  - Denominator: aggregate baseline-approved tool count
- Secondary endpoints:
  - `sprawl_explicit_unapproved_to_approved_ratio`
  - `sprawl_avg_approval_unknown_tools_per_org`
  - `sprawl_article50_gap_prevalence_pct`
  - `sprawl_article50_controls_missing_median`
  - `sprawl_orgs_scanned`
  - `sprawl_orgs_with_destructive_tooling_pct`
  - `sprawl_orgs_without_approval_gate_pct`
  - `sprawl_orgs_without_verifiable_evidence_pct`

## Sampling and Exclusion Plan

- Scan frame: repositories/organizations listed in `internal/repos.md`
- Inclusion unit: one entry per `owner/repo`
- Exclusions:
  - inaccessible targets at scan time
  - malformed targets outside `owner/repo` format
  - enrich-only data from headline baseline claims

## Analysis Plan (Deterministic)

- Claim ledger: `claims/ai-tool-sprawl-q1-2026/claims.json`
- Query engine: `jq`
- Threshold policy: `pipelines/config/publish-thresholds.json`
- Calibration policy: `pipelines/config/calibration-thresholds.json`
- Validation commands:
  - `pipelines/sprawl/validate.sh`
  - `pipelines/sprawl/validate.sh --run-id <id> --strict`

## Stop/Go Decision Policy

- Hard gate:
  - required thresholds must pass
  - strict claim/citation/threshold gates must pass
- Calibration gate:
  - detector coverage summary must be generated for selected cohort
  - labeled evaluation must include non-zero coverage for destructive tooling, approval-gate absence, and unknown classification
  - required calibration thresholds in `calibration-thresholds.json` must pass
- Advisory gate:
  - recommended headline-strength thresholds should pass
- If hard gate passes and advisory misses:
  - hold unless publication timing requires release with explicit caveat.

## Change Control

- Any change to hypotheses, endpoints, sampling rules, or thresholds requires:
  - version bump in this file
  - change log entry below
  - rerun or explicit invalidation of prior run claims

## Change Log

- `v1`: initial preregistration scaffold.
- `v2`: adds destructive-capability and control-posture prevalence endpoints/hypotheses.
- `v3`: lock record finalized; preflight execution contract locked pending canonical target list in internal/repos.md.
- `v4`: adds mandatory detector-calibration stage and records AI-native 50 calibration reference run.
- `v5`: adds explicit calibration threshold (`>=60%` recall_exists) and records tuned clean calibration run ID.
- `v6`: replaces unapproved/unknown headline terms with split endpoint model (`not_baseline_approved`, `explicit_unapproved`, `approval_unknown`) and adds evidence-tier endpoint.
- `v7`: records the canonical 1000-target publication cohort and the clean PCI-enabled calibration run used before manuscript drafting.

## Lock Record

- Locked by: `David Ahmann`
- Locked at (UTC): `2026-03-03T22:00:00Z`
- Notes: `Lock applies to baseline+enrich mechanics, split approval endpoint definitions, calibration gates, publish thresholds, and a documented amendment from the initial 500-target publication cohort to the canonical 1000-target run.`
