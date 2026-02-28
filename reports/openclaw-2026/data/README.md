# OpenClaw 2026 Data Dictionary

## Files

- `ungoverned-24h.json`: raw/derived summary for ungoverned run.
- `governed-24h.json`: raw/derived summary for governed run.
- `wrkr-scan-output.json`: discovery scan artifact for the environment under test.
- `scenario-summary-24h.json`: per-scenario governed vs ungoverned action outcomes.
- `anecdotes-24h.json`: concrete incident examples extracted from run events.

## Notes

- Replace placeholders with machine-generated outputs only.
- Keep field names stable across revisions.
- These files are publish-ready exports derived from `runs/openclaw/<run_id>/derived/` and `runs/openclaw/<run_id>/artifacts/` artifacts.

## Canonical promoted run artifacts

Promoted, git-trackable reproducibility sets are stored at:

- `reports/openclaw-2026/data/runs/<run_id>/`

Each promoted run directory contains:

- `run-manifest.json`
- `claim-values.json`
- `threshold-evaluation.json`
- `evidence-verification.json`
- `anecdotes.json`
- `scenario-summary.json`
- `wrkr-scan.json`
- `run-tree-manifest.sha256`
- `bundle.sha256`
- `promoted-artifacts.json`
