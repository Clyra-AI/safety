# AI Tool Sprawl Q1 2026 Study Protocol

Status: execution protocol  
Version: `v4`  
Objective: produce a reproducible multi-organization AI tool sprawl measurement baseline.

## 1) Campaign Design

- Canonical campaign mode: deterministic baseline scan.
- Supplemental enrich mode: separate run with explicit provenance (`as_of`, `source`), never merged into baseline headline claims.
- Calibration pre-pass: AI-native 50-target cohort before publication-scale campaign.
- Publication campaign target: `TBD` organizations (minimum publish threshold may apply).
- Runtime pinning: prefer repo-pinned Wrkr runtime (`go run` from `WRKR_REPO_PATH`) over ambient PATH binary unless an explicit `WRKR_BIN` override is supplied.

## 2) Sampling Rules

- Define inclusion list before scan run.
- For detector calibration, use a fixed AI-native cohort list and do not mix in publication cohort edits.
- Exclusion rules (archived, inaccessible, non-code mirrors) documented in methodology.
- No mid-campaign sampling edits without new run ID.

## 3) Required Inputs

- organization/repository target list (`internal/repos.md`)
- approved-tool policy list (`pipelines/policies/approved-tools.v1.yaml`)
- production-target policy (`pipelines/policies/production-targets.v1.yaml`) required for production-write claims
- optional segment metadata (`pipelines/policies/campaign-segments.v1.yaml`)

## 4) Required Outputs

- per-target scan JSON artifacts
- per-target stderr logs for clone and scan failures (when present)
- per-target derived state JSON with segmented counts:
  - headline scope (non-`source_repo`)
  - raw scope (includes `source_repo`)
- per-target provenance source label (`wrkr-scan-clone` or `wrkr-scan-repo-fallback`)
- campaign aggregate artifact
- appendix matrix exports (JSON/CSV)
- anonymized case-study inputs
- detector calibration artifact set for pre-pass runs:
  - `calibration/observed-by-target.csv`
  - `calibration/observed-non-source-tools.csv`
  - `calibration/gold-labels.template.json`
  - `calibration/detector-coverage-summary.json`
  - `calibration/gold-label-evaluation.json` (if manual labels provided)
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
- deterministic scope filter (`tool_type != "source_repo"`) used for headline metrics
- claim and threshold gates
- detector calibration pass summary for non-`source_repo` extraction quality before publication campaign
- resume semantics that skip only already-valid JSON scan/state pairs (invalid/zero-byte artifacts are recomputed)
- clone-mode resilience: if Git clone repeatedly fails (for example GitHub transient 5xx), runner falls back to deterministic `--repo` scan for that target and records fallback provenance in state

## 6) Publication Guardrails

Publish only when:

- claim gate passes
- threshold gate passes
- anonymization check passes
- deterministic rerun check passes for baseline aggregate
- detector calibration artifacts are present and reviewed for non-`source_repo` extraction quality
- required calibration threshold passes: `sprawl_non_source_recall_exists_pct >= 60.0`
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
