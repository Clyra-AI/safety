# Methodology - AI Tool Sprawl Q1 2026

## Scope and sample

This report uses a deterministic, public-repository campaign design.

- Current v1 manuscript scope: `1000` organizations (one `owner/repo` target per list entry).
- Calibration scope: fixed AI-native cohort (`50` targets) for detector quality checks.
- Intermediate benchmark scope: `101` targets for readiness checks before the publication cohort.
- Headline metrics use non-`source_repo` scope only; raw totals are published separately in segmented tables.

Claims in `claims/ai-tool-sprawl-q1-2026/claims.json` are frozen from canonical run `sprawl-ai1000-clean-pci-20260305T130344Z`.

Definitions lock: `definitions.md`  
Execution protocol: `study-protocol.md`

## Wrkr campaign pipeline

Follow the deterministic campaign runbook and guardrails:

1. build immutable run scaffold with `pipelines/sprawl/run.sh`
2. execute baseline scan in clone mode with synthetic fallback disabled
3. derive per-target state and campaign aggregates from scan artifacts
4. generate appendix exports and claim values with deterministic `jq` queries
5. run validation gates before manuscript finalization.

Regulatory rows are produced from deterministic proxy logic with policy-driven scope:

- `pipelines/policies/regulatory-scope.v1.json` controls framework applicability per org
- `pipelines/policies/regulatory-mappings.v1.yaml` documents control-ID mappings
- EU AI Act rows are enabled by default
- SOC 2 rows are enabled by default
- PCI DSS rows are enabled by default and can be disabled per org via scope policy.

## Calibration contract

Calibration is mandatory before publication-scale runs.

- run fixed AI-native cohort
- generate calibration artifacts with `pipelines/sprawl/calibrate_detectors.sh`
- fill labeled gold file for:
  - non-source detection
  - destructive tooling posture
  - approval-gate absence
  - approval-unknown presence
- evaluate labeled quality and enforce threshold gates.

Required calibration thresholds:

- `sprawl_non_source_recall_exists_pct >= 60.0`
- `sprawl_non_source_precision_exists_pct >= 60.0`
- `sprawl_destructive_tooling_labeled_rows >= 25`
- `sprawl_approval_gate_absence_labeled_rows >= 25`
- `sprawl_unknown_exists_labeled_rows >= 25`
- `sprawl_unknown_exists_recall_exists_pct >= 60.0`

## Deterministic reproducibility contract

For this report, "deterministic" means the same target list, repository commit SHAs, Wrkr version, detector set, policy inputs, and command sequence produce the same aggregate outputs.

Run metadata must include:

- Wrkr runtime mode and version/commit
- detector list
- targets file digest
- policy file digests
- UTC timestamps and run ID
- artifact hash manifest.

## External context boundary

- External threat-intel statistics may frame urgency but do not contribute to measured sprawl claim values.
- Any such statistic must be explicitly labeled context-only in manuscript text.
- Every context statistic must be entered in `citations/threat-context-sources.md` with source URL, publication date, and `Use=context-only`.

## Claim validation

See `/claims/ai-tool-sprawl-q1-2026/claims.json`.
