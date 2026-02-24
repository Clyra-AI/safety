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
- Approved-tools policy: `pipelines/policies/approved-tools.v1.yaml`
- Production-targets policy: `pipelines/policies/production-targets.v1.yaml`
- Segment metadata (optional): `pipelines/policies/campaign-segments.v1.yaml`
- Publish threshold policy: `pipelines/config/publish-thresholds.json`
- Default production-claim posture: do not publish production-write prevalence until production targets are intentionally populated.
- Current headline thresholds:
  - `sprawl_unapproved_to_approved_ratio >= 2.5`
  - `sprawl_avg_unknown_tools_per_org >= 1.5`
  - `sprawl_orgs_scanned >= 500`

## Input Assumptions

- Target list will be provided in `internal/repos.md`.
- Expected `internal/repos.md` format:
  - one `owner/repo` per line
  - blank lines allowed
  - lines starting with `#` treated as comments

## Step-by-Step Execution

## 1) Preflight

1. Ensure toolchain is available:
   - `wrkr`, `jq`, `bash`
2. Confirm required policy/config inputs exist:
   - `pipelines/policies/approved-tools.v1.yaml`
   - `pipelines/policies/production-targets.v1.yaml` (required for production-write claims)
   - `pipelines/policies/campaign-segments.v1.yaml` (optional)
3. Confirm report controls are present:
   - `reports/ai-tool-sprawl-q1-2026/definitions.md`
   - `reports/ai-tool-sprawl-q1-2026/study-protocol.md`
   - `claims/ai-tool-sprawl-q1-2026/claims.json`

## 2) Create Immutable Run

1. Generate run scaffold:
   - `pipelines/sprawl/run.sh --run-id sprawl-<timestamp>`
2. Capture run metadata in:
   - `runs/tool-sprawl/<run_id>/artifacts/run-manifest.json`
3. Record:
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

Update `claims/ai-tool-sprawl-q1-2026/claims.json` with real values from:

- `runs/tool-sprawl/<run_id>/agg/campaign-summary.json`

At minimum:

- `sprawl_unapproved_to_approved_ratio`
- `sprawl_avg_unknown_tools_per_org`
- `sprawl_article15_gap_prevalence_pct`

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

## What I Need From You (Sprawl)

1. `internal/repos.md` target list (canonical scan set).

Defaults are already locked for:

- baseline + enrich execution model (baseline canonical)
- approved-tools baseline policy
- production-targets and segment metadata placeholders
- publish thresholds
