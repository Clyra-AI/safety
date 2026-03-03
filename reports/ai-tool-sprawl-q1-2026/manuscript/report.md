# The State of AI Tool Sprawl, Q1 2026
## Manuscript Scaffold (Pre-Data Lock)

Status: drafting (data collection in progress)  
Report ID: `ai-tool-sprawl-q1-2026`

This file is the canonical manuscript source for the Q1 2026 sprawl report.
Headline values remain unpublished until campaign data lock and strict validation complete.

## Scope and Evidence Rules

- Only deterministic campaign outputs may be used for headline claims.
- Enriched context may be included only with explicit provenance (`source`, `as_of`).
- All report claims must map to `claims/ai-tool-sprawl-q1-2026/claims.json`.
- No publication until `pipelines/sprawl/validate.sh --strict` passes.

## 1) Headlines

- Hero metric placeholder: `sprawl_unapproved_to_approved_ratio`
- Supporting metric placeholder: `sprawl_avg_unknown_tools_per_org`
- Regulatory exposure placeholder: `sprawl_article50_gap_prevalence_pct`

## 2) Methodology

- Sampling frame and organization inclusion criteria
- Scan execution window (UTC)
- Deterministic vs enrichment split
- Data quality filters and exclusions

## 3) Tool Inventory

- Total organizations scanned
- Aggregate discovered tool count
- Approved/unapproved/unknown classification table

## 4) Privilege Map

- Permission-surface distribution by tool type
- Destructive-capable tooling prevalence
- Production-write exposure (only if production-target policy configured)

## 5) Approval Gap

- Unapproved-to-approved ratio (org-level and aggregate)
- Approval-gate coverage by organization
- Prompt-only control prevalence

## 6) Regulatory Exposure

- Article 50 transparency proxy results
- Article 15 robustness/cybersecurity mapping (if used)
- Gap prevalence by segment

## 7) Case Studies

- 2-4 anonymized case slices from deterministic outputs
- Each case must include artifact path and query reference

## 8) Benchmarks

- Quartile benchmarks across scanned organizations
- Comparative baseline methodology notes

## 9) Recommendations

- Discovery and inventory controls (Wrkr)
- Tool-boundary enforcement recommendation (Gait reference-only)
- Evidence trail requirements for governance readiness

## 10) Appendix

- Data dictionary
- Schema versions
- Claim map and threshold evaluation summary
- Reproducibility commands and manifest hashes
