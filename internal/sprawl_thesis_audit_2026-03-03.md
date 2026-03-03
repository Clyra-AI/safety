# AI Tool Sprawl Q1 2026: Defense-Grade Audit (2026-03-03)

Status: post-remediation audit (updated after fresh execution)  
Canonical run under review: `sprawl-live-101-clone-20260303T191500Z`  
Audit timestamp (UTC): `2026-03-03T19:45:00Z`

## 1) Audit scope and standard

This audit treats the sprawl pipeline as a thesis-defense artifact:

- deterministic metric derivation only
- no silent fallbacks
- run provenance and runtime compatibility must be explicit
- headline scope must exclude `source_repo` by design

Evidence reviewed:

- `runs/tool-sprawl/sprawl-live-101-clone-20260303T191500Z/scans/*.scan.json`
- `runs/tool-sprawl/sprawl-live-101-clone-20260303T191500Z/states/*.json`
- `runs/tool-sprawl/sprawl-live-101-clone-20260303T191500Z/agg/campaign-summary.json`
- `runs/tool-sprawl/sprawl-live-101-clone-20260303T191500Z/artifacts/run-manifest.json`
- `runs/tool-sprawl/sprawl-live-101-clone-20260303T191500Z/artifacts/claim-values.json`
- `claims/ai-tool-sprawl-q1-2026/claims.json`
- `reports/ai-tool-sprawl-q1-2026/definitions.md`
- `reports/ai-tool-sprawl-q1-2026/study-protocol.md`

## 2) Systemic defects fixed in this pass

## 2.1 `langfuse`/resume stop root cause fixed

Root causes:

- runner selected an older PATH `wrkr` binary that does not support `scan`
- Wrkr internal state and derived state previously collided on resume

Fixes in `pipelines/sprawl/run.sh`:

- runtime selection now prefers repo-pinned Wrkr (`go run` from `WRKR_REPO_PATH`)
- runtime compatibility check (`scan --help`) with fallback to repo runtime
- Wrkr state separated from derived state:
  - `wrkr-state/`, `wrkr-state-enrich/`
  - `states/`, `states-enrich/`

## 2.2 Resume correctness hardened

- Resume now skips only targets with valid non-empty JSON in both scan + derived state.
- Invalid/zero-byte artifacts are recomputed.

## 2.3 Clone/scan failure diagnosability and resilience

- Per-target stderr logs now written for:
  - clone failures (`*.clone.stderr.log`)
  - scan failures (`*.scan.stderr.log`)
- Retries with backoff added for clone and scan attempts.
- If clone repeatedly fails (for example GitHub transient 5xx), runner falls back to `--repo` scan for that target and records provenance in state (`wrkr-scan-repo-fallback`).

## 2.4 Metric-model and scope integrity

- Mapper aligned to Wrkr tool schema (`inventory.tools[]`).
- Headline metrics exclude `tool_type == "source_repo"`.
- Raw totals retained in `segmented_totals` for transparency.
- `unapproved_to_approved_ratio` fixed to true ratio (`n/d`, 2 decimals).

## 2.5 Validation hardening

`pipelines/sprawl/validate.sh` now checks:

- scan artifacts are non-empty valid JSON
- source-repo segmentation arithmetic reconciles
- run manifest mode is not `scaffold`
- artifact paths in claim/threshold outputs are relative (no machine-local absolute paths)

## 3) Fresh run integrity outcomes

Run: `sprawl-live-101-clone-20260303T191500Z`

- scans produced: `101`
- states produced: `101`
- zero-byte scan files: `0`
- run manifest mode: `resume` (expected; run completed via resume checkpoints)
- runtime recorded:
  - `wrkr_runtime = go-run:/Users/davidahmann/Projects/wrkr`
  - `wrkr_sha = 2b0efd6edc63856b9b21bcfa8136528c98e57202`

`pipelines/sprawl/validate.sh --run-id sprawl-live-101-clone-20260303T191500Z`: `ok` (non-strict; claims ledger still `TBD`)

## 4) Campaign metrics (fresh run)

From `agg/campaign-summary.json`:

- `orgs_scanned`: `101`
- `avg_unknown_tools_per_org`: `0`
- `unapproved_to_approved_ratio`: `1.16`
- `article50_gap_prevalence_pct`: `17.82`
- `orgs_with_destructive_tooling_pct`: `0.99`
- `orgs_without_approval_gate_pct`: `0`
- `orgs_prompt_only_controls_pct`: `1.98`
- `orgs_without_audit_artifacts_pct`: `56.44`

Scope segmentation:

- headline-scope tools (`non-source_repo`): `41`
- raw tools (includes `source_repo`): `893`
- `source_repo` tools: `852`

Arithmetic check: `893 - 41 = 852` (passes).

## 5) Remaining publication blockers

## 5.1 Claim ledger still not finalized

`claims/ai-tool-sprawl-q1-2026/claims.json` values remain `TBD`.

Impact: strict publish gate cannot pass yet.

## 5.2 Threshold-policy mismatch vs campaign size

Current policy expects 500-org scale for required thresholds, while this run is intentionally 101 orgs.

Decision needed:

- scale campaign to threshold size, or
- formally version and revise threshold policy for 101-org release.

## 5.3 Manuscript is still scaffold-level

`reports/ai-tool-sprawl-q1-2026/manuscript/report.md` has not been converted to evidence-complete narrative sections.

## 6) Defensibility verdict

Technically defensible now:

- deterministic pipeline behavior
- explicit source-repo segmentation
- reproducible fresh run with full artifact set
- auditable failure handling and runtime provenance

Not publish-defensible yet:

- strict claim/threshold closure
- manuscript completion and locked claim values
