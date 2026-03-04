# The State of AI Tool Sprawl, Q1 2026
## Manuscript Scaffold (Pre-Data Lock)

Status: drafting (data collection in progress)  
Report ID: `ai-tool-sprawl-q1-2026`

This file is the canonical manuscript source for the Q1 2026 sprawl report.
Headline values remain unpublished until campaign data lock and strict validation complete.

## Scope and Evidence Rules

- Only deterministic campaign outputs may be used for headline claims.
- Headline metrics exclude `tool_type == "source_repo"`; raw counts are published in segmented tables.
- Enriched context may be included only with explicit provenance (`source`, `as_of`).
- Regulatory language is control-proxy language unless legal review explicitly approves stronger wording.
- All report claims must map to `claims/ai-tool-sprawl-q1-2026/claims.json`.
- No publication until `pipelines/sprawl/validate.sh --run-id <id> --strict` passes.

## 1) Headlines

- Hero metric placeholder: `sprawl_not_baseline_approved_to_approved_ratio`
- Supporting ratio placeholder: `sprawl_explicit_unapproved_to_approved_ratio`
- Approval-unknown burden placeholder: `sprawl_avg_approval_unknown_tools_per_org`
- Regulatory exposure placeholder: `sprawl_article50_gap_prevalence_pct`
- Evidence posture placeholder: `sprawl_orgs_without_verifiable_evidence_pct`

## 2) Methodology

- Sampling frame and organization inclusion criteria
- Scan execution window (UTC)
- Deterministic vs enrichment split
- Data quality filters and exclusions
- Calibration labeling coverage for destructive tooling, approval-gate absence, and unknown classification

## 3) Tool Inventory

- Total organizations scanned
- Aggregate discovered tool count
- Baseline-approved / explicit-unapproved / approval-unknown classification table
- Segmented raw vs headline-scope totals

## 4) Privilege Map

- Permission-surface distribution by tool type
- Destructive tooling prevalence
- Production-write exposure (only if production-target policy configured)

## 5) Approval and Governance Gap

- Not-baseline-approved to baseline-approved ratio (aggregate and by segment)
- Explicit-unapproved ratio and approval-unknown burden
- Approval-gate absence prevalence for destructive tooling

## 6) Regulatory Transparency Proxy

- Article 50 proxy prevalence
- Controls missing median (0-4)
- Explicit proxy disclosure: not a legal determination

## 7) Case Studies

- 2-4 anonymized case slices from deterministic outputs
- Each case must include artifact path and query reference

## 8) Benchmarks

- Quartile benchmarks across scanned organizations
- Comparative baseline methodology notes

## 9) Recommendations

- Discovery and inventory controls (Wrkr)
- Tool-boundary enforcement recommendation (Gait reference-only)
- Evidence-tier and approval workflow requirements for governance readiness

## 10) Appendix

- Data dictionary
- Schema versions
- Claim map and threshold evaluation summary
- Reproducibility commands and manifest hashes
