# Detector Calibration (AI Tool Sprawl V2)

This directory defines the publication calibration contract for v2 tool-plus-agent claims.

The goal is not to prove every repo is risky. The goal is to prove that the detector surfaces used in headline claims are measured against a hand-reviewed gold-label set before publication.

## Publication rule

Do not publish v2 headline claims until all of the following exist for the publication run:

- `runs/tool-sprawl/<run_id>/calibration/observed-by-target-v2.csv`
- `runs/tool-sprawl/<run_id>/calibration/observed-agents-v2.csv`
- `runs/tool-sprawl/<run_id>/calibration/gold-labels-v2.template.json`
- `runs/tool-sprawl/<run_id>/calibration/gold-label-validation-v2.json`
- `runs/tool-sprawl/<run_id>/calibration/gold-label-evaluation-v2.json`
- `runs/tool-sprawl/<run_id>/calibration/detector-coverage-summary-v2.json`

## Reviewer workflow

1. Generate calibration scaffolding from the immutable run:

   `bash pipelines/sprawl/calibrate_detectors_v2.sh --run-id <run_id>`

2. Copy `gold-labels-v2.template.json` to a reviewer-owned file and fill only hand-reviewed expectations.

3. Each reviewed row must include:

- `target`
- at least one `expected_*` field
- `reviewer`
- optional `notes`

4. Re-run calibration with the completed labels:

   `bash pipelines/sprawl/calibrate_detectors_v2.sh --run-id <run_id> --gold-labels <path>`

5. For publication gates, run it in strict mode:

   `bash pipelines/sprawl/calibrate_detectors_v2.sh --run-id <run_id> --gold-labels <path> --strict`

Strict mode fails if any gold-label row:

- is missing `target`
- duplicates another target
- does not match a run target
- is missing `reviewer`
- has no populated `expected_*` fields

## Labeled dimensions

- non-source tool presence and count
- declared agent presence and count
- deployed-agent presence and count
- incomplete-binding agent presence and count
- write-capable agent presence
- exec-capable agent presence
- agent-linked attack-path presence

## Gold-label boundary

Gold labels must come from manual review of target repositories and their public artifacts.
Do not backfill labels from the detector output itself.
Do not treat unlabeled rows as negatives.

## Publication gates

The hard thresholds live in `pipelines/config/calibration-thresholds.json`.
`validate_v2.sh --lane full --strict` treats the required thresholds as binding and the recommended thresholds as advisory.
