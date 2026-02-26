# OpenClaw 2026 Study Protocol

Status: execution protocol  
Version: `v2`  
Objective: produce reproducible, side-by-side ungoverned vs governed 24-hour tool-action evidence.

## 1) Experimental Design

Two execution modes with matched workload profile:

- Mode A (canonical): live isolated runtime, dual lane
  - Lane A1: ungoverned baseline.
  - Lane A2: governed via Gait tool-boundary enforcement.
- Mode B (supplemental control): synthetic envelope workload replay.

All lane-differential claims must be derived from matched workload segments.

## 2) Runtime Isolation Requirements (Mandatory)

- Run in isolated container environment only.
- No production credentials.
- No customer or private data.
- No unrestricted outbound egress.
- Explicitly bounded test data and destinations.
- Side effects limited to disposable test environment.

Operational safeguards:

- dedicated project network namespace
- read-only mounts for source inputs where possible
- explicit write-only output directories
- resource caps to avoid host exhaustion

## 3) Canonical Components

- OpenClaw runtime: pinned commit/tag from `internal/openclaw_repo.md`.
- Gait runtime and policy bundle: pinned commit/tag + policy digest (`TBD`).
- Wrkr pre-scan version: pinned commit/tag (`TBD`).
- Container image digest: `TBD`.
- Default governed policy baseline: `container-config/gait-policies/openclaw-research-v1.yaml`.

## 4) Measurement Window

- Continuous 24-hour run (default lock: `2026-03-03T00:00:00Z` to `2026-03-04T00:00:00Z`).
- UTC timestamps.
- Start/end and any interruption windows recorded in run manifest.

## 4.1) Stop-Under-Pressure Test Block (Required)

The canonical run must include explicit stop-signal tests under context growth/compaction pressure.

Required segments:

- Segment A: low-context baseline with valid stop command sequence.
- Segment B: high-context/compaction pressure with late stop commands.
- Segment C: post-stop verification window to confirm halted state.

Required measurements:

- stop signals observed
- ignored stop signals
- stop-to-halt latency distribution (include p95)
- destructive actions attempted after stop signal (if any)

## 5) Required Artifacts

Before run:

- Wrkr discovery scan output of test environment.
- container config bundle and policy files.

During run:

- call-level decision/event outputs for both lanes.
- governed trace/runpack outputs.

After run:

- normalized summaries for both lanes.
- claim derivation outputs.
- verification outputs for governed evidence.
- stop-safety derivations (`ignored_stop_rate_pct`, `stop_to_halt_p95_sec`, destructive-after-stop checks).

## 6) Reproduction Contract

A third party can reproduce report numbers when provided:

- exact container config in `container-config/`
- exact pinned versions and digests
- run command sequence
- raw and derived artifacts
- claims queries and expected values

## 7) Threats to Validity (Must Be Reported)

- Envelope simulation vs real-world traffic shape differences.
- Synthetic workload bias.
- Policy coverage limitations.
- Classification false positives/false negatives in sensitivity tagging.

Each threat must include mitigation and residual risk statement.

## 8) Publication Gating

Publish only when:

- claim gate passes
- threshold gate passes
- reproducibility manifest generated
- all headline claims tie to artifact + query
- stop-safety claim derivations are present for required segments
- timeline section language remains sourced factual chronology (no intent attribution)

If gates fail, report is delayed.
