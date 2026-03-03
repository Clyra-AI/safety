# Methodology - AI Tool Sprawl Q1 2026

## Scope and sample

TBD.

Definitions lock: `definitions.md`  
Execution protocol: `study-protocol.md`

## Wrkr campaign pipeline

Follow the deterministic campaign runbook and guardrails.

Detector calibration is a required pre-pass before publication-scale runs:

- run a fixed AI-native cohort
- generate calibration artifacts with `pipelines/sprawl/calibrate_detectors.sh`
- review non-`source_repo` extraction quality and optional gold-label scoring
- enforce calibration floor: `sprawl_non_source_recall_exists_pct >= 60.0`

## Deterministic reproducibility contract

For this report, "deterministic" means the same target list, repository commit SHAs, Wrkr version, detector set, policy inputs, and command sequence produce the same aggregate outputs.

## External context boundary

- External threat-intel statistics may frame urgency but do not contribute to measured sprawl claim values.
- Any such statistic must be explicitly labeled context-only in manuscript text.
- Every context statistic must be entered in `citations/threat-context-sources.md` with source URL, publication date, and `Use=context-only`.

## Claim validation

See `/claims/ai-tool-sprawl-q1-2026/claims.json`.
