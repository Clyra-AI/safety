# Detector Calibration (AI Tool Sprawl)

This directory defines the calibration contract for non-`source_repo` detector quality before publication-scale campaigns.

## Why this exists

The sprawl report headline scope excludes `tool_type == "source_repo"`. If detector output is dominated by `source_repo`, headline metrics can be methodologically correct but analytically weak.

Calibration aligns detector behavior to report intent by measuring:

- non-`source_repo` extraction coverage
- target-level non-`source_repo` detection rate
- optional precision/recall against manually labeled gold targets

Required calibration floor for sprawl publication gate:

- `sprawl_non_source_recall_exists_pct >= 60.0`

## Canonical workflow

1. Run the AI-native calibration cohort (typically 50 repos):
   - `pipelines/sprawl/run.sh --run-id <id> --mode baseline-only --targets-file internal/repos.md --max-targets 50 --scan-source clone --no-synthetic-fallback`
2. Generate calibration artifacts:
   - `pipelines/sprawl/calibrate_detectors.sh --run-id <id> --strict`
3. Fill manual labels from `gold-labels.template.json` and save as `gold-labels.filled.json`.
4. Evaluate labeled calibration quality:
   - `pipelines/sprawl/calibrate_detectors.sh --run-id <id> --gold-labels reports/ai-tool-sprawl-q1-2026/calibration/gold-labels.filled.json --strict`
5. Tune Wrkr detector rules and repeat until non-`source_repo` signal quality is acceptable.

## Outputs produced per run

- `runs/tool-sprawl/<run_id>/calibration/observed-by-target.csv`
- `runs/tool-sprawl/<run_id>/calibration/observed-non-source-tools.csv`
- `runs/tool-sprawl/<run_id>/calibration/gold-labels.template.json`
- `runs/tool-sprawl/<run_id>/calibration/detector-coverage-summary.json`
- `runs/tool-sprawl/<run_id>/calibration/gold-label-evaluation.json` (only when labels provided)

## Label schema

Each gold-label entry is a JSON object:

- `target`: `owner/repo`
- `expected_non_source_exists`: `true|false|null`
- `expected_non_source_count`: integer or `null`
- `reviewer`: optional reviewer ID/name
- `notes`: optional rationale

Use `null` values for unlabeled rows.
