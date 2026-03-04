# AI Tool Sprawl Q1 2026 Methodology One-Pager

Status: draft scaffold

Use this file for the publication-time one-page methodology brief for journalists and external reviewers.

Required content:

- study objective and campaign scan window
- detector-calibration pre-pass summary (cohort size, non-`source_repo` coverage, label-eval status)
- calibration threshold results:
  - `sprawl_non_source_recall_exists_pct`
  - `sprawl_non_source_precision_exists_pct`
  - labeled-row coverage for destructive tooling / approval-gate absence / unknown classification
- canonical target-list source (`internal/repos.md`)
- deterministic baseline vs enrich separation
- headline scope filter (`tool_type != "source_repo"`) and segmented raw-count disclosure
- exact Wrkr version, commit SHA, and detector list
- runtime selection rule (repo-pinned Wrkr preferred; PATH binary used only when compatible or explicitly overridden)
- policy inputs used (`approved-tools`, `production-targets`, optional segments)
- reproduction command sequence
- artifact map (scans, aggregate, appendix, claims)
- per-target provenance labels (`wrkr-scan-clone` vs `wrkr-scan-repo-fallback`) and fallback criteria
- limitations and known threats to validity
