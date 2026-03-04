# Clyra AI Safety Initiative
# Report Template: "The State of AI Tool Sprawl, Q1 2026"

Document status: Draft template  
Target length: 20-25 pages including appendix tables  
Primary audience: CISOs, AppSec, GRC leaders, analysts, trade/business press  
Methodology engine: Wrkr OSS deterministic campaign pipeline

## 0) Publication Controls

- Report ID: `ai-tool-sprawl-q1-2026`
- Planned publish date: `TBD`
- Campaign run ID: `TBD` (immutable once set)
- Mandatory hero metric:
  - `Not-baseline-approved to baseline-approved ratio`
- Secondary headline metrics:
  - `Explicit-unapproved to baseline-approved ratio`
  - `Average approval-unknown tools per organization`
  - `% organizations with Article 50 transparency gap proxy`
  - `Median Article 50 controls missing per organization (0-4)`
  - `% organizations with destructive tooling`
  - `% organizations without approval gate for destructive tooling`
  - `% organizations without verifiable evidence tier`
- Canonical claims ledger: `claims/ai-tool-sprawl-q1-2026/claims.json`

## 0.1) Headline Integrity Block (Required)

Populate for every headline used in manuscript text.

| Claim ID | Headline number | Denominator | Run ID | Artifact path | Query |
|---|---:|---|---|---|---|
| `sprawl_not_baseline_approved_to_approved_ratio` | TBD | `aggregate approved tools` | `TBD` | `runs/tool-sprawl/<run_id>/agg/campaign-summary.json` | `jq '.campaign.metrics.not_baseline_approved_to_approved_ratio'` |
| `sprawl_explicit_unapproved_to_approved_ratio` | TBD | `aggregate approved tools` | `TBD` | `runs/tool-sprawl/<run_id>/agg/campaign-summary.json` | `jq '.campaign.metrics.explicit_unapproved_to_approved_ratio'` |
| `sprawl_avg_approval_unknown_tools_per_org` | TBD | `organizations scanned` | `TBD` | `runs/tool-sprawl/<run_id>/agg/campaign-summary.json` | `jq '.campaign.metrics.avg_approval_unknown_tools_per_org'` |
| `sprawl_article50_gap_prevalence_pct` | TBD | `organizations scanned` | `TBD` | `runs/tool-sprawl/<run_id>/agg/campaign-summary.json` | `jq '.campaign.metrics.article50_gap_prevalence_pct'` |
| `sprawl_article50_controls_missing_median` | TBD | `organizations scanned` | `TBD` | `runs/tool-sprawl/<run_id>/agg/campaign-summary.json` | `jq '.campaign.metrics.article50_controls_missing_median'` |
| `sprawl_orgs_with_destructive_tooling_pct` | TBD | `organizations scanned` | `TBD` | `runs/tool-sprawl/<run_id>/agg/campaign-summary.json` | `jq '.campaign.metrics.orgs_with_destructive_tooling_pct'` |
| `sprawl_orgs_without_approval_gate_pct` | TBD | `organizations scanned` | `TBD` | `runs/tool-sprawl/<run_id>/agg/campaign-summary.json` | `jq '.campaign.metrics.orgs_without_approval_gate_pct'` |
| `sprawl_orgs_without_verifiable_evidence_pct` | TBD | `organizations scanned` | `TBD` | `runs/tool-sprawl/<run_id>/agg/campaign-summary.json` | `jq '.campaign.metrics.orgs_without_verifiable_evidence_pct'` |

## 1) Core Thesis and Messaging Stack

Core thesis: AI governance gaps are measurable now, not hypothetical future risk.

Primary message: `TBD headline number` is the observed not-baseline-approved tool burden across the sample.

Secondary message: approval-unknown and explicit-unapproved tooling are distinct risk classes and must be reported separately.

Tertiary message: EU AI Act transparency claims in this report are deterministic control proxies, not legal determinations.

## 2) Scope and Non-Negotiables

- Structure follows the canonical 10-section report structure.
- Headline metrics must come from deterministic campaign artifacts.
- Any enrich-derived claims must include explicit `as_of` provenance.
- No production-write percentages unless production-target policy is configured.
- Gait appears only as a recommendation reference (no deep analysis section).

## 3) Required Evidence Inputs

- `runs/tool-sprawl/<run_id>/agg/campaign-summary.json`
- `runs/tool-sprawl/<run_id>/agg/campaign-public.md`
- `runs/tool-sprawl/<run_id>/appendix/combined-appendix.json`
- CSV exports under `runs/tool-sprawl/<run_id>/appendix/`
- calibration artifacts under `runs/tool-sprawl/<run_id>/calibration/`
- claims ledger + threshold evaluation artifacts

If a section claim cannot be tied to an artifact and query, delete the claim.

## 4) End-State Report Structure (10 Sections)

## Section 1: Headline findings

Show 3-5 artifact-backed numbers first.

## Section 2: Methodology

State sample, scan window, Wrkr version/commit, calibration coverage, and deterministic pipeline.

## Section 3: Tool inventory

Break down discovered tools and segmented counts:

- baseline-approved
- explicit-unapproved
- approval-unknown
- source-repo excluded totals vs raw totals.

## Section 4: Privilege and access map

Translate inventory into destructive tooling and approval-gate posture.

## Section 5: Approval and governance gap

Present both ratios:

- not-baseline-approved / baseline-approved
- explicit-unapproved / baseline-approved

Include approval-unknown burden as separate line, not merged wording.

## Section 6: Regulatory exposure

Use deterministic proxy language only with explicit control IDs:

- EU AI Act: `Article 50` proxy + controls-missing median
- SOC 2: `CC6.1`, `CC7.1`, `CC8.1` proxy rows
- PCI DSS 4.0.1 (PCI-scoped orgs only): `6.3`, `6.5`, `7.2`, `12.8` proxy rows

Include explicit legal disclaimer: these are control proxies, not legal determinations or audit opinions.

## Section 7: Case studies

2-5 anonymized cases with artifact/query links.

## Section 8: Benchmarks

Quartiles/segments and methodological comparators.

## Section 9: Recommendations

Concrete operational actions (discovery, gating, evidence continuity, governance workflows).

## Section 10: Appendix

Data dictionary, schema versions, claim map, threshold evaluation summary, reproducibility commands.

## Mandatory Methodological Disclosures (Fixed Headings)

### Limitations

`TBD`

### Threats to Validity

`TBD`

### Residual Risk

`TBD`

### Reproducibility Notes

`TBD`

## 5) Asset Package Checklist

- Report PDF (`reports/ai-tool-sprawl-q1-2026/report.pdf`)
- Executive summary PDF (`reports/ai-tool-sprawl-q1-2026/executive-summary.pdf`)
- Methodology one-pager (`reports/ai-tool-sprawl-q1-2026/methodology-one-pager.md` or PDF equivalent)
- Full anonymized dataset (CSV/JSON)
- 5-7 social stat graphics
- EU AI Act readiness checklist (one page)

## 6) Quality Gate Before Publish

- Hero number is strong enough to anchor coverage.
- All headline claims pass artifact + query validation.
- Anonymization checks pass.
- Deterministic rerun check passes for baseline aggregate.
- Calibration required thresholds pass with labeled coverage.
- Any enrich claims include source + `as_of` timestamp.
