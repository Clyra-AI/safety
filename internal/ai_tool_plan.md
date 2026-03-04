# AI Tool Sprawl Research Plan (Q1 2026)

Status: execution plan  
Report ID: `ai-tool-sprawl-q1-2026`  
Primary metric: not-baseline-approved to baseline-approved AI tool ratio

## Objective

Run a reproducible multi-target Wrkr campaign, generate aggregate and appendix artifacts, compute claim values, and produce a publish-ready pack.

## Locked Defaults (Current)

- Canonical claim lane: deterministic baseline scan outputs.
- Supplemental lane: enrich-enabled outputs (time-sensitive, explicitly labeled with `as_of`).
- Target list file: `internal/repos.md`
- Calibration artifact path: `runs/tool-sprawl/<run_id>/calibration/`
- Preregistration file: `reports/ai-tool-sprawl-q1-2026/preregistration.md`
- Approved-tools policy: `pipelines/policies/approved-tools.v1.yaml`
- Production-targets policy: `pipelines/policies/production-targets.v1.yaml`
- Segment metadata (optional): `pipelines/policies/campaign-segments.v1.yaml`
- Publish threshold policy: `pipelines/config/publish-thresholds.json`
- Calibration threshold policy: `pipelines/config/calibration-thresholds.json`
- Default production-claim posture: do not publish production-write prevalence until production targets are intentionally populated.

## Required headline thresholds

- `sprawl_not_baseline_approved_to_approved_ratio >= 2.5`
- `sprawl_avg_approval_unknown_tools_per_org >= 1.5`
- `sprawl_orgs_scanned >= 500`
- `sprawl_article50_gap_prevalence_pct >= 15.0`
- `sprawl_orgs_without_verifiable_evidence_pct >= 20.0`
- `sprawl_orgs_with_destructive_tooling_pct >= 15.0`
- `sprawl_orgs_without_approval_gate_pct >= 10.0`

## Recommended headline-strength thresholds

- `sprawl_not_baseline_approved_to_approved_ratio >= 4.0`
- `sprawl_explicit_unapproved_to_approved_ratio >= 2.0`
- `sprawl_avg_approval_unknown_tools_per_org >= 3.0`
- `sprawl_article50_gap_prevalence_pct >= 30.0`
- `sprawl_article50_controls_missing_median >= 1.5`
- `sprawl_orgs_with_destructive_tooling_pct >= 30.0`
- `sprawl_orgs_without_approval_gate_pct >= 20.0`
- `sprawl_orgs_without_verifiable_evidence_pct >= 30.0`

## Input Assumptions

- Target list lives in `internal/repos.md` (one `owner/repo` per line).
- Recommended calibration generation path:
  - `pipelines/sprawl/generate_targets.sh --total 50 --ai-weight 100 --dev-weight 0 --sec-weight 0 --output internal/repos.md --catalog internal/repos_candidates.csv`
- Recommended publication generation path:
  - `pipelines/sprawl/generate_targets.sh --total 500 --pages 5 --per-page 100 --output internal/repos.md --catalog internal/repos_candidates.csv`

## Step-by-Step Execution

## 0) Detector Calibration (Mandatory Pre-Pass)

1. Run fixed AI-native pre-pass cohort:
   - `pipelines/sprawl/run.sh --run-id sprawl-ai50-<timestamp> --mode baseline-only --targets-file internal/repos.md --max-targets 50 --scan-source clone --no-synthetic-fallback`
2. Generate calibration artifacts:
   - `pipelines/sprawl/calibrate_detectors.sh --run-id sprawl-ai50-<timestamp> --strict`
3. Fill manual labels from generated template:
   - `runs/tool-sprawl/sprawl-ai50-<timestamp>/calibration/gold-labels.template.json`
4. Evaluate labeled quality:
   - `pipelines/sprawl/calibrate_detectors.sh --run-id sprawl-ai50-<timestamp> --gold-labels <path-to-filled-labels.json> --strict`
5. Required labeled dimensions:
   - `expected_non_source_exists` / `expected_non_source_count`
   - `expected_destructive_tooling`
   - `expected_approval_gate_absent`
   - `expected_unknown_exists` / `expected_unknown_count`
6. Exit criterion for publication-campaign eligibility:
   - all required calibration thresholds pass.

## 1) Preflight

1. Ensure toolchain is available: `wrkr`, `jq`, `bash`, `curl` (and `gh` if using authenticated target generation).
2. Confirm preregistration lock fields are set.
3. Confirm required policy/config inputs exist.
4. Confirm report controls are present (`definitions`, `protocol`, `claims`, thresholds).

## 2) Create Immutable Run

1. Preflight: `pipelines/sprawl/run.sh --run-id sprawl-<timestamp> --dry-run`
2. Generate run scaffold and execute:
   - `pipelines/sprawl/run.sh --run-id sprawl-<timestamp> --max-targets 500 --scan-source clone --no-synthetic-fallback --max-runtime-sec 172800 --max-run-disk-mb 65536`
3. Resume with same run ID if interrupted:
   - `pipelines/sprawl/run.sh --run-id sprawl-<timestamp> --resume ...`

## 3) Validate and Derive

1. Readiness gate:
   - `pipelines/sprawl/validate.sh --run-id <run_id>`
2. Strict gate (publish readiness):
   - `pipelines/sprawl/validate.sh --run-id <run_id> --strict`
3. If claims ledger still has `TBD`, keep run non-publishable until values are frozen and revalidated.

## 4) Assemble Publish Pack

1. Build package:
   - `pipelines/sprawl/publish_pack.sh --run-id <run_id>`
2. Confirm package includes:
   - claim values
   - threshold evaluation
   - campaign summary
   - appendix exports
   - hash manifest

## 5) Manuscript Fill and Freeze

1. Fill manuscript only from validated artifact values.
2. Include deterministic proxy disclosure for regulatory claims.
3. Freeze run ID and publish date.

## 6) 500-Run Reliability Controls

1. Use authenticated GitHub query generation for target acquisition (`gh auth status`).
2. Freeze `internal/repos.md` before run; no mid-campaign target edits.
3. Use clone-based scans (`--scan-source clone`) with synthetic fallback disabled.
4. Use read-only token posture for repo fallback scans:
   - set `WRKR_GITHUB_TOKEN`
   - set `WRKR_GITHUB_TOKEN_MODE=read-only`
5. Clear external model/cloud secret environment variables (`*_API_KEY`, cloud write creds) before run.
6. Keep runtime/disk caps at or above:
   - `--max-runtime-sec 172800`
   - `--max-run-disk-mb 65536`
