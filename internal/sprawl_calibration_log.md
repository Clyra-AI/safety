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

## 2026-03-03 Gold-label evaluation (AI-50)

- Gold labels file: `reports/ai-tool-sprawl-q1-2026/calibration/gold-labels.filled.json`
- Calibration command:
  - `pipelines/sprawl/calibrate_detectors.sh --run-id sprawl-ai50-prepass-20260303T203500Z --gold-labels reports/ai-tool-sprawl-q1-2026/calibration/gold-labels.filled.json --strict`
- Evaluation artifact:
  - `runs/tool-sprawl/sprawl-ai50-prepass-20260303T203500Z/calibration/gold-label-evaluation.json`

Binary existence metrics:

- true positive: `12`
- false negative: `38`
- false positive: `0`
- recall_exists: `24%`
- precision_exists: `100%`

Count coverage metrics:

- expected_non_source_total: `50`
- observed_non_source_total: `34`
- observed_to_expected_ratio: `68%`

Conclusion:

- Current detector behavior is conservative/high-precision but low-recall for this AI-native cohort.
- Next required step is detector tuning to improve non-`source_repo` recall before publication-scale campaign.

## 2026-03-03 Hardening Sprint (Wrkr tuning)

Wrkr detector tuning applied:

- recursive dependency manifest coverage (not root-only)
- expanded AI dependency keyword coverage
- deterministic fallback `ai_project_signal` when dependency signals are absent (repo name / README signal)

Wrkr implementation branch:

- repo: `github.com/Clyra-AI/wrkr`
- branch: `codex/dependency-recall-sprint`
- commit: `77f547a75494b735da5cba500e3c82f3731e24cf`

## 2026-03-03 Tuned run 1

- Run ID: `sprawl-ai50-tuned1-20260303T210043Z`
- Recall result: `36%` (`18 TP`, `32 FN`, `0 FP`)
- Precision result: `100%`
- Status: improved but below publish calibration floor.

## 2026-03-03 Tuned run 2

- Run ID: `sprawl-ai50-tuned2-20260303T210425Z`
- Recall result: `60%` (`30 TP`, `20 FN`, `0 FP`)
- Precision result: `100%`
- Status: meets required calibration floor.

## 2026-03-03 Tuned clean verification run

- Run ID: `sprawl-ai50-tuned3-clean-20260303T210808Z`
- Wrkr runtime commit in run-manifest: `77f547a75494b735da5cba500e3c82f3731e24cf`
- Recall result: `60%` (`30 TP`, `20 FN`, `0 FP`)
- Precision result: `100%`

Calibration guardrail outcome:

- required floor met: `sprawl_non_source_recall_exists_pct >= 60.0` (pass)
- recommended floor missed: `>=75.0` (advisory)
