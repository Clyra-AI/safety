# OpenClaw 2026 Data Dictionary

## Files

- `ungoverned-24h.json`: derived summary for ungoverned lane (`openclaw-live-24h-20260228T143341Z`).
- `governed-24h.json`: derived summary for governed lane (`openclaw-live-24h-20260228T143341Z`).
- `wrkr-scan-output.json`: pre-test Wrkr discovery summary with pointer to full scan artifact.
- `scenario-summary-24h.json`: per-scenario governed vs ungoverned outcomes.
- `anecdotes-24h.json`: incident examples extracted from run events.

## Notes

- These files are machine-generated exports from the canonical run.
- Field names and metric IDs are locked by `reports/openclaw-2026/definitions.md`.
- Claim values are derived via deterministic queries defined in `claims/openclaw-2026/claims.json`.
- Canonical release evidence is the promoted run folder under `reports/openclaw-2026/data/runs/<run_id>/`.
- Root-level files in this directory (`ungoverned-24h.json`, `governed-24h.json`, `scenario-summary-24h.json`, `anecdotes-24h.json`, `wrkr-scan-output.json`) are convenience snapshots for readers.

## Canonical promoted run artifacts

Promoted, git-trackable reproducibility sets are stored at:

- `reports/openclaw-2026/data/runs/<run_id>/`

Canonical run in this release:

- `reports/openclaw-2026/data/runs/openclaw-live-24h-20260228T143341Z/`

The full Wrkr scan JSON is retained in the promoted run directory to avoid duplicate large artifacts in root-level data files.

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

For this canonical run, required threshold gate result is `16/16` passed.
