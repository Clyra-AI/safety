# AI Tool Sprawl Research Plan (Q1 2026)

Status: execution plan  
Report ID: `ai-tool-sprawl-q1-2026`  
Primary metric: unapproved-to-approved AI tool ratio

## Objective

Run a reproducible multi-target Wrkr campaign, generate aggregate and appendix artifacts, compute claim values, and produce a publish-ready pack.

## Locked Defaults (Current)

- Canonical claim lane: baseline deterministic scan outputs.
- Supplemental lane: enrich-enabled outputs (time-sensitive, explicitly labeled with `as_of`).
- Target list file: `internal/repos.md`
- Calibration artifact path: `runs/tool-sprawl/<run_id>/calibration/`
- Preregistration file: `reports/ai-tool-sprawl-q1-2026/preregistration.md`
- Approved-tools policy: `pipelines/policies/approved-tools.v1.yaml`
- Production-targets policy: `pipelines/policies/production-targets.v1.yaml`
- Segment metadata (optional): `pipelines/policies/campaign-segments.v1.yaml`
- Publish threshold policy: `pipelines/config/publish-thresholds.json`
- Default production-claim posture: do not publish production-write prevalence until production targets are intentionally populated.
- Current headline thresholds:
  - `sprawl_unapproved_to_approved_ratio >= 2.5`
  - `sprawl_avg_unknown_tools_per_org >= 1.5`
  - `sprawl_orgs_scanned >= 500`
  - `sprawl_orgs_with_destructive_tooling_pct >= 15.0`
  - `sprawl_orgs_without_approval_gate_pct >= 10.0`
- Recommended headline-strength thresholds (advisory):
  - `sprawl_unapproved_to_approved_ratio >= 4.0`
  - `sprawl_avg_unknown_tools_per_org >= 3.0`
  - `sprawl_article50_gap_prevalence_pct >= 30.0`
  - `sprawl_orgs_with_destructive_tooling_pct >= 30.0`
  - `sprawl_orgs_without_approval_gate_pct >= 20.0`
  - `sprawl_orgs_prompt_only_controls_pct >= 25.0`
  - `sprawl_orgs_without_audit_artifacts_pct >= 30.0`

## Input Assumptions

- Target list lives in `internal/repos.md`.
- Recommended calibration generation path (AI-native cohort):
  - `pipelines/sprawl/generate_targets.sh --total 50 --ai-weight 100 --dev-weight 0 --sec-weight 0 --output internal/repos.md --catalog internal/repos_candidates.csv`
- Recommended publication-campaign generation path:
  - `pipelines/sprawl/generate_targets.sh --total 101 --output internal/repos.md --catalog internal/repos_candidates.csv`
- Expected `internal/repos.md` format:
  - one `owner/repo` per line
  - blank lines allowed
  - lines starting with `#` treated as comments

## Step-by-Step Execution

## 0) Detector Calibration (Mandatory Pre-Pass)

1. Run fixed AI-native pre-pass cohort:
   - `pipelines/sprawl/run.sh --run-id sprawl-ai50-<timestamp> --mode baseline-only --targets-file internal/repos.md --max-targets 50 --scan-source clone --no-synthetic-fallback`
2. Generate calibration artifacts:
   - `pipelines/sprawl/calibrate_detectors.sh --run-id sprawl-ai50-<timestamp> --strict`
3. Fill manual labels from generated template:
   - `runs/tool-sprawl/sprawl-ai50-<timestamp>/calibration/gold-labels.template.json`
4. Evaluate detector quality once labels are available:
   - `pipelines/sprawl/calibrate_detectors.sh --run-id sprawl-ai50-<timestamp> --gold-labels <path-to-filled-labels.json> --strict`
5. Tune detector set and repeat until non-`source_repo` extraction quality is acceptable.
6. Exit criterion for publication-campaign eligibility:
   - `sprawl_non_source_recall_exists_pct >= 60.0` on labeled calibration cohort.

## 1) Preflight

1. Ensure toolchain is available:
   - `wrkr`, `jq`, `bash`, `curl` (and `gh` if using authenticated GitHub search generation)
2. (Recommended) regenerate target list:
   - `pipelines/sprawl/generate_targets.sh --total 101 --output internal/repos.md --catalog internal/repos_candidates.csv`
3. Confirm preregistration lock fields are set:
   - `reports/ai-tool-sprawl-q1-2026/preregistration.md`
4. Confirm required policy/config inputs exist:
   - `pipelines/policies/approved-tools.v1.yaml`
   - `pipelines/policies/production-targets.v1.yaml` (required for production-write claims)
   - `pipelines/policies/campaign-segments.v1.yaml` (optional)
5. Confirm report controls are present:
   - `reports/ai-tool-sprawl-q1-2026/definitions.md`
   - `reports/ai-tool-sprawl-q1-2026/study-protocol.md`
   - `claims/ai-tool-sprawl-q1-2026/claims.json`

## 2) Create Immutable Run

1. Preflight (no writes):
   - `pipelines/sprawl/run.sh --run-id sprawl-<timestamp> --dry-run`
2. Generate run scaffold:
   - `pipelines/sprawl/run.sh --run-id sprawl-<timestamp>`
3. If interrupted, resume same run ID:
   - `pipelines/sprawl/run.sh --run-id sprawl-<timestamp> --resume`
4. Capture run metadata in:
   - `runs/tool-sprawl/<run_id>/artifacts/run-manifest.json`
5. Record:
   - Wrkr version
   - commit SHA(s) of this repo and Wrkr repo used
   - scan window start timestamp

## 3) Execute Scans From `internal/repos.md`

For each repo in `internal/repos.md`:

1. Run deterministic baseline scan:
   - write scan envelope to `runs/tool-sprawl/<run_id>/scans/<slug>.scan.json`
   - write state to `runs/tool-sprawl/<run_id>/states/<slug>.json`
2. Optional enrich lane:
   - write enrich scan to `runs/tool-sprawl/<run_id>/scans/<slug>.scan.enrich.json`
   - write enrich state to `runs/tool-sprawl/<run_id>/states-enrich/<slug>.json`
3. Fail closed on scan errors; do not silently skip targets.

## 4) Validate Raw Scan Outputs

1. Assert all baseline scan files have `status=="ok"`.
2. If enrich is enabled, assert all enrich scan files have `status=="ok"`.
3. Record failed targets explicitly in run notes if any.

## 5) Build Campaign Aggregate

1. Build baseline aggregate:
   - output: `runs/tool-sprawl/<run_id>/agg/campaign-summary.json`
   - envelope: `runs/tool-sprawl/<run_id>/agg/campaign-envelope.json`
   - public md: `runs/tool-sprawl/<run_id>/agg/campaign-public.md`
2. If enrich enabled, build separate enrich aggregate:
   - `campaign-summary-enrich.json`
3. Keep baseline and enrich claims separate unless explicitly marked.

## 6) Export Appendix Tables

1. Export appendix per state:
   - baseline states -> `runs/tool-sprawl/<run_id>/appendix/<slug>/...csv`
2. Optional enrich exports:
   - `runs/tool-sprawl/<run_id>/appendix/<slug>.enrich/...csv`
3. Build combined matrix:
   - `runs/tool-sprawl/<run_id>/appendix/combined-appendix.json`

## 7) Compute and Set Claim Values

First derive all claims automatically (no manual counting):

- `pipelines/common/derive_claim_values.sh --claims claims/ai-tool-sprawl-q1-2026/claims.json --run-id <run_id> --output runs/tool-sprawl/<run_id>/artifacts/claim-values.json --strict`

Then, only when promoting a publication run, update `claims/ai-tool-sprawl-q1-2026/claims.json` from derived values in:

- `runs/tool-sprawl/<run_id>/agg/campaign-summary.json`

At minimum:

- `sprawl_unapproved_to_approved_ratio`
- `sprawl_avg_unknown_tools_per_org`
- `sprawl_article50_gap_prevalence_pct`
- `sprawl_orgs_with_destructive_tooling_pct`
- `sprawl_orgs_without_approval_gate_pct`
- `sprawl_orgs_prompt_only_controls_pct`
- `sprawl_orgs_without_audit_artifacts_pct`

## 8) Run Publish Gates

1. Readiness:
   - `pipelines/sprawl/validate.sh`
2. Strict run-bound validation:
   - `pipelines/sprawl/validate.sh --run-id <run_id> --strict`
3. Resolve any failures before writing manuscript claims.

## 9) Assemble Publish Pack

1. Build package:
   - `pipelines/sprawl/publish_pack.sh --run-id <run_id>`
2. Confirm package includes:
   - report package content
   - claims file
   - regulatory source log
   - run manifest and hash manifests (if available)

## 10) Manuscript Fill and Freeze

1. Fill `report.pdf` and summary artifacts from validated values only.
2. Ensure all Section 1 numbers map to claims entries.
3. Freeze run ID and publish date.

## Publish Decision Bands (Stop/Go)

1. Hard gate (must pass):
   - required thresholds in `pipelines/config/publish-thresholds.json`
2. Headline-strength band (recommended):
   - recommended thresholds in `pipelines/config/publish-thresholds.json`
3. If hard gate passes but recommended band misses:
   - treat as "hold for stronger signal" unless timing requires publication with explicit caveat.

## What I Need From You (Sprawl)

1. `internal/repos.md` target list (canonical scan set).

Defaults are already locked for:

- baseline + enrich execution model (baseline canonical)
- approved-tools baseline policy
- production-targets and segment metadata placeholders
- publish thresholds
