# AI Tool Sprawl Q1 2026 Study Protocol

Status: execution protocol  
Version: `v7`  
Objective: produce a reproducible multi-organization AI tool governance baseline.

## 1) Campaign Design

- Canonical campaign mode: deterministic baseline scan.
- Supplemental enrich mode: separate run with explicit provenance (`as_of`, `source`), never merged into baseline headline claims.
- Calibration pre-pass: AI-native 50-target cohort before publication-scale campaign.
- Publication campaign target: `500` organizations (minimum publish threshold hard gate).
- Intermediate benchmark campaign: `101` organizations for operational readiness checks only.
- Runtime pinning: prefer repo-pinned Wrkr runtime (`go run` from `WRKR_REPO_PATH`) over ambient PATH binary unless explicit `WRKR_BIN` override is supplied.

## 2) Sampling Rules

- Define inclusion list before scan run.
- For detector calibration, use a fixed AI-native cohort list and do not mix publication cohort edits.
- Exclusion rules (archived, inaccessible, non-code mirrors) are documented in methodology.
- No mid-campaign sampling edits without new run ID.

## 3) Required Inputs

- organization/repository target list (`internal/repos.md`)
- approved-tool policy list (`pipelines/policies/approved-tools.v1.yaml`)
- production-target policy (`pipelines/policies/production-targets.v1.yaml`) required for production-write claims
- optional segment metadata (`pipelines/policies/campaign-segments.v1.yaml`)
- regulatory applicability scope (`pipelines/policies/regulatory-scope.v1.json`)
- regulatory mapping reference (`pipelines/policies/regulatory-mappings.v1.yaml`)

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
  - destructive tooling prevalence
  - approval-gate absence prevalence
  - prompt-only control prevalence
  - evidence-tier prevalence
  - Article 50 proxy score prevalence (`controls_missing_count`)
- regulatory matrix rows for enabled frameworks:
  - EU AI Act Article 50 proxy
  - SOC 2 (`CC6.1`, `CC7.1`, `CC8.1`) deterministic proxies
  - PCI DSS 4.0.1 (`6.3`, `6.5`, `7.2`, `12.8`) deterministic proxies when PCI scope is enabled

## 5) Reproducibility Contract

Third-party reproduction must be possible from:

- run command sequence
- pinned Wrkr version
- input lists and policy files
- generated campaign and appendix artifacts
- deterministic scope filter (`tool_type != "source_repo"`) used for headline metrics
- claim and threshold gates
- detector calibration pass summary for non-`source_repo` extraction and posture classification quality before publication campaign
- resume semantics that skip only already-valid JSON scan/state pairs (invalid/zero-byte artifacts are recomputed)
- clone-mode resilience: if Git clone repeatedly fails, runner falls back to deterministic `--repo` scan and records fallback provenance in state.

## 6) Publication Guardrails

Publish only when:

- claim gate passes
- threshold gate passes
- anonymization check passes
- deterministic rerun check passes for baseline aggregate
- detector calibration artifacts are present and reviewed
- required calibration thresholds pass:
  - `sprawl_non_source_recall_exists_pct >= 60.0`
  - `sprawl_non_source_precision_exists_pct >= 60.0`
  - `sprawl_destructive_tooling_labeled_rows >= 25`
  - `sprawl_approval_gate_absence_labeled_rows >= 25`
  - `sprawl_unknown_exists_labeled_rows >= 25`
  - `sprawl_unknown_exists_recall_exists_pct >= 60.0`
- enrich claims (if any) include provenance and are labeled time-sensitive
- production-write claims are published only when production targets are intentionally populated and validated
- all regulatory language is explicitly scoped as deterministic control proxy unless legal review says otherwise.

## 7) Threats to Validity (Must Be Reported)

- sample selection bias
- public-repo visibility limits
- detector coverage boundaries
- approval-status ambiguity (`explicit_unapproved` vs `approval_unknown`)
- temporal drift between scan and publication

Each threat requires mitigation and residual-risk text.

## Version Notes

- `v6`: aligns protocol to split approval metrics, Article 50 proxy scoring, evidence-tier posture, and metric-specific calibration coverage gates.
- `v7`: adds policy-driven SOC 2 and PCI DSS proxy mappings and regulatory applicability scope controls.
