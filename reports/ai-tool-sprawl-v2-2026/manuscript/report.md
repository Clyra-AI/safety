# The State of AI Tool and Agent Sprawl, 2026
## Draft V2 Backbone

- Report ID: `ai-tool-sprawl-v2-2026`
- Version: `v2-draft`
- Run ID: `TBD`
- Campaign design: `deterministic baseline`, tool plus agent scope
- Status: `execution-ready; manuscript draft`

## Executive Summary

This manuscript is a v2 scaffold.
It expands the sprawl study from tool-only posture to tool plus agent posture while preserving the locked Q1 2026 baseline as a separate report.

No headline values are frozen in this draft.
Every final claim must map to an immutable artifact, deterministic query, and locked preregistration record.

## Headline Integrity Block

Populate from `claims/ai-tool-sprawl-v2-2026/claims.json` after the locked full-scale run is complete.

| Claim ID | Headline number | Denominator | Run ID | Artifact path | Query |
|---|---:|---|---|---|---|
| `sprawl_v2_not_baseline_approved_to_approved_ratio` | TBD | `aggregate approved tools` | `TBD` | `runs/tool-sprawl/<run_id>/agg/campaign-summary-v2.json` | `jq '.campaign.metrics.not_baseline_approved_to_approved_ratio'` |
| `sprawl_v2_orgs_with_agents_pct` | TBD | `organizations scanned` | `TBD` | `runs/tool-sprawl/<run_id>/agg/campaign-summary-v2.json` | `jq '.campaign.metrics.orgs_with_agents_pct'` |
| `sprawl_v2_avg_agents_per_org` | TBD | `organizations scanned` | `TBD` | `runs/tool-sprawl/<run_id>/agg/campaign-summary-v2.json` | `jq '.campaign.metrics.avg_agents_per_org'` |
| `sprawl_v2_orgs_with_deployed_agents_pct` | TBD | `organizations scanned` | `TBD` | `runs/tool-sprawl/<run_id>/agg/campaign-summary-v2.json` | `jq '.campaign.metrics.orgs_with_deployed_agents_pct'` |
| `sprawl_v2_agents_missing_bindings_pct` | TBD | `declared agents` | `TBD` | `runs/tool-sprawl/<run_id>/agg/campaign-summary-v2.json` | `jq '.campaign.metrics.agents_missing_bindings_pct'` |
| `sprawl_v2_orgs_with_write_capable_agents_pct` | TBD | `organizations scanned` | `TBD` | `runs/tool-sprawl/<run_id>/agg/campaign-summary-v2.json` | `jq '.campaign.metrics.orgs_with_write_capable_agents_pct'` |
| `sprawl_v2_orgs_with_exec_capable_agents_pct` | TBD | `organizations scanned` | `TBD` | `runs/tool-sprawl/<run_id>/agg/campaign-summary-v2.json` | `jq '.campaign.metrics.orgs_with_exec_capable_agents_pct'` |
| `sprawl_v2_orgs_with_agent_attack_paths_pct` | TBD | `organizations scanned` | `TBD` | `runs/tool-sprawl/<run_id>/agg/campaign-summary-v2.json` | `jq '.campaign.metrics.orgs_with_agent_attack_paths_pct'` |

## 1) Headline Findings

Draft section goal:

- show the continuity tool metric
- show agent prevalence
- show one deployment or privilege metric
- show one evidence or transparency metric

## 2) Methodology

Required facts:

- sample frame
- Wrkr commit
- Proof framework set
- calibration coverage
- deterministic baseline boundary

## 3) Tool Inventory

Carry forward v1 continuity metrics:

- baseline-approved tools
- explicit-unapproved tools
- approval-unknown tools
- non-source vs raw totals

## 4) Agent Inventory

Additive v2 section:

- declared agents
- framework mix
- deployed agents
- binding-complete vs binding-incomplete agents

## 5) Privilege and Attack Path Posture

Additive v2 section:

- write-capable agents
- exec-capable agents
- credential-access agents
- agent-linked attack-path prevalence

## 6) Approval and Evidence Posture

This section combines:

- tool approval visibility
- agent approval classification
- evidence tier
- verifiable evidence prevalence

## 7) Regulatory Exposure

Headline-eligible framework families:

- EU AI Act
- SOC 2
- PCI DSS 4.0.1

Appendix-only mappings stay out of headline text unless promoted by protocol update.

## 8) Case Studies

Use anonymized tool plus agent case studies only after artifact review.

## 9) Recommendations

Focus on:

- discovery normalization
- agent binding completeness
- approval evidence
- least privilege
- proof-backed evidence continuity

## 10) Appendix

Include:

- schema and claim map
- export dictionary
- calibration summary
- reproducibility commands

## Limitations

- This scaffold is not tied to a locked run.
- Public repositories understate internal runtime deployment and credential posture.
- Binding inference is declaration-based and does not prove runtime activity.

## Threats to Validity

- detector coverage varies by framework and config convention
- some agent surfaces may be declared but not deployed
- some deployed agents may be absent from public repositories entirely

## Residual Risk

- internal environments may show materially higher privilege and deployment risk than public-repo posture
- publish-eligible regulatory coverage remains narrower than the full framework catalog in `proof`

## Reproducibility Notes

- raw per-target v2 input comes from out-of-box `wrkr scan --json`
- proof-backed framework definitions come from bundled `proof` framework files
- campaign aggregation, appendix exports, and claim derivation for v2 are implemented in `pipelines/sprawl/run_v2.sh` and `pipelines/sprawl/rebuild_from_scans_v2.sh`
- publication still requires a locked v2 preregistration record and completed gold-label calibration review
