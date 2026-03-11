# AI Tool Sprawl V2 2026 Pre-Registration

Status: locked  
Version: `v1`

This file governs the initial v2 full-scale collection and post-run publish validation workflow.

## Study Identity

- Report ID: `ai-tool-sprawl-v2-2026`
- Working title: `The State of AI Tool and Agent Sprawl, 2026`
- Target list source: `pipelines/sprawl/generate_targets_v2.sh --purpose publication`
- Default cohort weighting: `60% ai_native`, `20% dev_platform`, `20% security_platform`
- Run root: `runs/tool-sprawl/<run_id>/`
- Initial lock created: `2026-03-11`

## Hypotheses

1. The sample will contain a measurable not-baseline-approved to baseline-approved tool gap.
2. A measurable share of organizations will expose declared agents in public repositories.
3. A non-trivial share of declared agents will show incomplete binding evidence.
4. A measurable share of organizations will expose deployed, write-capable, or exec-capable agent posture.
5. Deterministic evidence-tier and transparency gaps will remain measurable even after agents are added to scope.

## Primary and Secondary Endpoints

- Primary endpoints:
  - `sprawl_v2_not_baseline_approved_to_approved_ratio`
  - `sprawl_v2_orgs_with_agents_pct`
- Secondary endpoints:
  - `sprawl_v2_avg_agents_per_org`
  - `sprawl_v2_orgs_with_deployed_agents_pct`
  - `sprawl_v2_agents_missing_bindings_pct`
  - `sprawl_v2_orgs_with_write_capable_agents_pct`
  - `sprawl_v2_orgs_with_exec_capable_agents_pct`
  - `sprawl_v2_orgs_with_agent_attack_paths_pct`
  - `sprawl_v2_orgs_without_verifiable_evidence_pct`
  - `sprawl_v2_article50_gap_prevalence_pct`
  - `sprawl_v2_orgs_scanned`

## Analysis Plan

- Claim ledger: `claims/ai-tool-sprawl-v2-2026/claims.json`
- Query engine: `jq`
- Campaign summary artifact: `runs/tool-sprawl/<run_id>/agg/campaign-summary-v2.json`
- Appendix artifact: `runs/tool-sprawl/<run_id>/appendix/combined-appendix-v2.json`
- Sampling frame: one public `owner/repo` per owner with deterministic exclusions for obvious tutorial, template, docs, prompt-pack, and mirror repos
- Full collection run: `pipelines/sprawl/run_v2.sh --lane full --purpose publication`
- Strict publish validation occurs after claim values are populated from the immutable run and gold-label calibration evaluation is complete

## Stop/Go Policy

- no full-scale collection run unless definitions, protocol, and this preregistration remain version-locked
- no publication release until claim values are populated from the immutable run
- no publication release until strict validation and calibration gates pass

## Change Control

- any change to hypotheses, endpoints, sampling rules, thresholds, or release sequence requires:
  - version bump in this file
  - update to definitions/protocol
  - explicit invalidation of prior locked assumptions

## Lock Record

- Locked by: `David Ahmann`
- Locked at (UTC): `2026-03-11T23:26:49Z`
- Notes: `Initial locked preregistration for v2 full-scale collection; claims finalized post-run before strict publish validation.`
