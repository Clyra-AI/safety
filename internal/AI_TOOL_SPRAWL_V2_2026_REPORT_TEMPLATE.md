# Clyra AI Safety Initiative
# Report Template: "The State of AI Tool and Agent Sprawl, 2026"

Document status: Draft template  
Target length: 20-25 pages including appendix tables  
Primary audience: CISOs, AppSec, platform engineering, GRC leaders, analysts  
Methodology engine: Wrkr OSS deterministic scan outputs plus CAISI campaign aggregation

## 0) Publication Controls

- Report ID: `ai-tool-sprawl-v2-2026`
- Planned publish date: `TBD`
- Campaign run ID: `TBD`
- Mandatory hero metrics:
  - `Not-baseline-approved to baseline-approved tool ratio`
  - `% organizations with declared agents`
- Secondary headline metrics:
  - `Average declared agents per organization`
  - `% organizations with deployed agents`
  - `% declared agents with incomplete bindings`
  - `% organizations with write-capable agents`
  - `% organizations with exec-capable agents`
  - `% organizations with agent-linked attack paths`
  - `% organizations without verifiable evidence`
  - `% organizations with Article 50 transparency gap proxy`
- Canonical claims ledger: `claims/ai-tool-sprawl-v2-2026/claims.json`

## 0.1) Headline Integrity Block (Required)

Populate for every headline used in manuscript text.

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

## 1) Core Thesis and Messaging Stack

Core thesis: AI is entering software delivery faster than organizations can produce verifiable approval and control evidence.

Primary message: v2 measures AI adoption signal, delivery-surface exposure, and evidence posture in the same deterministic denominator.

Secondary message: agent binding completeness, deployment evidence, and privilege posture are separate dimensions and must not be collapsed into a single risk label.

Relevance rule for campaign derivatives: public AI-tool signal + delivery surface + trust pressure -> report relevance.

## 2) Required Evidence Inputs

- per-target `wrkr scan --json` artifacts
- v2 campaign summary artifact
- v2 appendix exports
- calibration artifacts for tool and agent surfaces
- claims ledger and threshold evaluation artifacts

## 3) End-State Report Structure

1. Headline findings
2. Why this matters for software delivery and AppSec
3. Tool and agent adoption signal
4. Delivery surface exposure
5. Governance and evidence gaps
6. Regulatory readiness
7. Case studies
8. Methodology
9. Recommendations and limitations
10. Appendix

## Mandatory Methodological Disclosures

### Limitations

`TBD`

### Threats to Validity

`TBD`

### Residual Risk

`TBD`

### Reproducibility Notes

`TBD`
