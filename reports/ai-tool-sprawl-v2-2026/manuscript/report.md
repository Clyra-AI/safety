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
- show the delivery-surface AI signal
- show one evidence or transparency metric
- only use privilege posture as a headline if the final cohort supports it cleanly

## 2) Why This Matters for Software Delivery and AppSec

Draft section goal:

- connect public AI-tool signals to code, CI, and operational delivery surface
- explain why regulated or trust-sensitive teams care about evidence, approval, and write-path visibility
- keep the framing centered on verifiable governance questions, not generic AI hype

## 3) Tool and Agent Adoption Signal

Draft section goal:

- carry forward tool inventory continuity from v1
- show declared-agent prevalence and framework mix
- separate raw detections from headline-scope counts cleanly

## 4) Delivery Surface Exposure

Draft section goal:

- show where agents and AI tooling appear in software-delivery contexts
- focus on code, CI, workflow, and orchestration surfaces before privilege claims
- treat deployment and binding completeness as exposure qualifiers, not proof of runtime activity

## 5) Governance and Evidence Gaps

Draft section goal:

- lead with approval visibility, evidence tier, and verifiable proof gaps
- use agent binding incompleteness as a governance-readiness finding
- keep privilege and attack-path metrics in support unless the final data makes them stronger than the evidence story

## 6) Regulatory Readiness

Draft section goal:

- keep EU AI Act, SOC 2, and PCI DSS as deterministic readiness proxies
- frame these as evidence-of-control coverage questions, not legal conclusions
- keep appendix-only mappings out of headline text

## 7) Case Studies

Draft section goal:

- use anonymized software-delivery examples only after artifact review
- prioritize examples that illustrate adoption signal plus governance opacity
- avoid narrow toy-repo anecdotes unless they expose a generalizable pattern

## 8) Methodology

Required facts:

- sample frame
- Wrkr commit
- Proof framework set
- calibration coverage
- deterministic baseline boundary
- publication weighting rationale

## 9) Recommendations

Focus on:

- discovery normalization across code and CI surface
- machine-readable approval and evidence capture
- agent binding completeness before runtime expansion
- least privilege where delivery-connected agents exist
- proof-backed evidence continuity for audit and leadership review

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
