# AI Tool Sprawl Q1 2026 Study Protocol

Status: execution protocol  
Version: `v2`  
Objective: produce a reproducible multi-organization AI tool sprawl measurement baseline.

## 1) Campaign Design

- Canonical campaign mode: deterministic baseline scan.
- Supplemental enrich mode: separate run with explicit provenance (`as_of`, `source`), never merged into baseline headline claims.
- Sample target: `TBD` organizations (minimum publish threshold may apply).

## 2) Sampling Rules

- Define inclusion list before scan run.
- Exclusion rules (archived, inaccessible, non-code mirrors) documented in methodology.
- No mid-campaign sampling edits without new run ID.

## 3) Required Inputs

- organization/repository target list (`internal/repos.md`)
- approved-tool policy list (`pipelines/policies/approved-tools.v1.yaml`)
- production-target policy (`pipelines/policies/production-targets.v1.yaml`) required for production-write claims
- optional segment metadata (`pipelines/policies/campaign-segments.v1.yaml`)

## 4) Required Outputs

- per-target scan JSON artifacts
- campaign aggregate artifact
- appendix matrix exports (JSON/CSV)
- anonymized case-study inputs
- claims ledger values and query mapping
- organization-level control posture derivations:
  - destructive-capable tooling prevalence
  - approval-gate absence prevalence
  - prompt-only control prevalence
  - missing audit-artifact prevalence

## 5) Reproducibility Contract

Third-party reproduction must be possible from:

- run command sequence
- pinned Wrkr version
- input lists and policy files
- generated campaign and appendix artifacts
- claim and threshold gates

## 6) Publication Guardrails

Publish only when:

- claim gate passes
- threshold gate passes
- anonymization check passes
- deterministic rerun check passes for baseline aggregate
- enrich claims (if any) include provenance and are labeled time-sensitive
- production-write claims are published only when production targets are intentionally populated and validated
- control-posture prevalence claims are mapped to deterministic derivations in aggregate artifacts

## 7) Threats to Validity (Must Be Reported)

- sample selection bias
- public-repo visibility limits
- detector coverage boundaries
- classification ambiguity for unknown approval status
- temporal drift between scan and publication

Each threat requires a mitigation and residual risk note.
