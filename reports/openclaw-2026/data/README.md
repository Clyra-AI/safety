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
