# OpenClaw Case Study Research Plan

Status: execution plan  
Report ID: `openclaw-2026`  
Primary metric: policy-violating tool calls in 24 hours

## Objective

Run a full isolated OpenClaw experiment with two matched lanes (ungoverned vs governed), produce verified evidence artifacts, compute claims, and package a publish-ready case-study dataset.

## Locked Defaults (Current)

- Canonical workload strategy: run both live isolated runtime and synthetic envelope workload.
- Canonical headline source: live isolated runtime lane.
- Supplemental control lane: synthetic envelope replay/comparison.
- Canonical source pin file: `internal/openclaw_repo.md`
- Governed policy file set path: `reports/openclaw-2026/container-config/gait-policies/`
- Default governed policy file: `reports/openclaw-2026/container-config/gait-policies/openclaw-research-v1.yaml`
- Recommended default run window (UTC):
  - start: `2026-03-03T00:00:00Z`
  - end: `2026-03-04T00:00:00Z`
- Default legal/comms posture: sourced factual timeline only; no intent attribution; no legal conclusion language.
- Publish threshold policy: `pipelines/config/publish-thresholds.json`
- Current headline thresholds:
  - `openclaw_total_tool_calls_24h >= 2000`
  - `openclaw_policy_violations_24h >= 500`
  - `openclaw_governed_evidence_verification_rate_pct >= 99.0`

## Input Assumptions

- `internal/repos.md` exists and is available for Wrkr context and any comparative repository references.
- OpenClaw runtime source/version to execute is pinned in `internal/openclaw_repo.md` before run start.

## Step-by-Step Execution

## 1) Safety + Isolation Preflight

1. Confirm isolation controls:
   - `reports/openclaw-2026/container-config/ISOLATION_REQUIREMENTS.md`
2. Enforce:
   - no production credentials
   - no customer/private data
   - bounded side effects only
3. Verify dual-lane container config is current:
   - `reports/openclaw-2026/container-config/docker-compose.yml`

## 2) Create Immutable Run

1. Scaffold run:
   - `pipelines/openclaw/run.sh --run-id openclaw-<timestamp>`
2. Confirm structure:
   - `runs/openclaw/<run_id>/{config,raw,derived,artifacts}`
3. Record in run manifest:
   - OpenClaw commit/tag from `internal/openclaw_repo.md`
   - Gait commit/tag
   - Wrkr commit/tag (for pre-scan)
   - image digest(s)

## 3) Define Matched Workload

1. Freeze workload profile before execution:
   - action mix
   - frequency
   - synthetic data fixtures
2. Use same workload profile across both lanes.
3. Record workload seed/config in `runs/openclaw/<run_id>/config/`.

## 4) Pre-Test Wrkr Discovery Scan

1. Run Wrkr against the isolated test environment before 24h run.
2. Write output to:
   - `reports/openclaw-2026/data/wrkr-scan-output.json` (publish artifact)
   - `runs/openclaw/<run_id>/raw/wrkr/` (full run evidence)

## 5) Execute Lane A (Ungoverned Baseline)

1. Run 24h baseline in isolated container (same UTC window as governed lane).
2. Capture call-level outputs to:
   - `runs/openclaw/<run_id>/raw/ungoverned/`
3. Ensure timestamps are UTC and run window is complete.

## 6) Execute Lane B (Governed via Gait)

1. Route every tool call through Gait boundary path using policy files in `reports/openclaw-2026/container-config/gait-policies/`.
2. Enforce non-`allow` as non-executable.
3. Capture:
   - governed call outputs: `runs/openclaw/<run_id>/raw/governed/`
   - traces/runpacks: `runs/openclaw/<run_id>/artifacts/gait/`

## 7) Verify Governed Evidence

1. Verify trace/runpack integrity.
2. Store verification outputs in:
   - `runs/openclaw/<run_id>/artifacts/verification/`
3. Any verification failure blocks publication.

## 8) Derive Summaries and Export Report Data

1. Build normalized summary artifacts:
   - `runs/openclaw/<run_id>/derived/ungoverned_summary.json`
   - `runs/openclaw/<run_id>/derived/governed_summary.json`
2. Copy publish-facing data files:
   - `reports/openclaw-2026/data/ungoverned-24h.json`
   - `reports/openclaw-2026/data/governed-24h.json`
3. Keep derivation scripts/queries deterministic and documented.

## 9) Compute and Set Claim Values

Update `claims/openclaw-2026/claims.json` with values from derived summaries:

- `openclaw_total_tool_calls_24h`
- `openclaw_policy_violations_24h`
- `openclaw_sensitive_access_without_approval`
- `openclaw_governed_evidence_verification_rate_pct`

## 10) Run Publish Gates

1. Readiness:
   - `pipelines/openclaw/validate.sh`
2. Strict run-bound validation:
   - `pipelines/openclaw/validate.sh --run-id <run_id> --strict`
3. Resolve all failures before manuscript finalization.

## 11) Assemble Publish Pack

1. Build package:
   - `pipelines/openclaw/publish_pack.sh --run-id <run_id>`
2. Confirm package includes:
   - report package
   - claims file
   - timeline source log
   - run manifest/hash
   - derived summaries (if present)

## 12) Manuscript Fill and Freeze

1. Fill report sections from validated artifacts only.
2. Keep Section 1 timeline factual and source-linked.
3. Keep Section 3 brand-neutral data-only.
4. Freeze run ID and publish date.

## What I Need From You (OpenClaw)

1. Canonical OpenClaw source to run:
   - populate `internal/openclaw_repo.md` (repo URL + commit/tag).

Defaults are already locked for:

- workload mode (live canonical + synthetic supplemental)
- governed policy baseline path and starter file
- run window (`2026-03-03T00:00:00Z` to `2026-03-04T00:00:00Z`)
- legal/comms posture (facts-only sourced timeline, no intent attribution)
- publish thresholds
