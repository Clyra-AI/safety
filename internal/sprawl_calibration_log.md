# Sprawl Detector Calibration Log

## 2026-03-03 AI-native pre-pass

- Run ID: `sprawl-ai50-prepass-20260303T203500Z`
- Cohort source: `internal/repos.md` (`total=50`, `ai_native=50`)
- Execution mode: `baseline-only`, `scan-source=clone`, `--no-synthetic-fallback`
- Validation: `pipelines/sprawl/validate.sh --run-id sprawl-ai50-prepass-20260303T203500Z` (pass, non-strict)

Observed campaign metrics (`runs/tool-sprawl/sprawl-ai50-prepass-20260303T203500Z/agg/campaign-summary.json`):

- organizations scanned: `50`
- non-source tools detected: `34`
- raw tools detected: `363`
- source-repo tools: `329`
- source-repo share: `90.63%`
- unapproved/approved ratio (headline scope): `1.43`
- avg unknown tools per org (headline scope): `0`

Interpretation:

- Pipeline stability is acceptable for calibration.
- Headline-scope signal remains weak for flagship publication claims.
- Detector tuning should prioritize non-`source_repo` extraction coverage before scaling to publication cohort.
