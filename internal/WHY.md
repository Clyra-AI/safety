# WHY.md - Canonical Project Context

## Why This Project Exists

Clyra AI Safety Initiative is building public, reproducible research that shows measurable AI governance failures and practical control patterns using working open-source tooling.

The objective is twofold:

1. Publish credible independent research papers that stand on their own.
2. Make replication easy enough that independent third parties can reproduce the same findings from the same inputs.

This repository is the canonical evidence layer for both goals.

## Why a Dedicated Research Repo

Separating research from product repositories is intentional:

- It provides a stable citation URL for journalists, analysts, and researchers.
- It keeps methodology, data, and report assets in one place.
- It reduces trust friction: "clone, run, verify" is possible without understanding internal product architecture.
- It preserves longitudinal value: each quarterly dataset is schema-compatible and comparable.

## What We Are Publishing

## Report 1: OpenClaw Case Study

Working title: "1.5 Million Agents, Zero Governance"

Purpose:
- Incident-driven technical analysis.
- Controlled 24-hour comparison of ungoverned vs governed behavior.
- Demonstrates what governance infrastructure changes in practice.

Primary headline metric:
- policy-violating tool calls in 24 hours.

## Report 2: State of AI Tool Sprawl Q1 2026

Purpose:
- Flagship cross-organization measurement report.
- Quantifies inventory, approval gap, privilege exposure, and regulatory gaps.

Primary headline metric:
- unapproved-to-approved AI tool ratio per organization.

## Research Philosophy

1. Determinism first.
- Baseline claims come from deterministic scan/evaluation artifacts.

2. Reproducibility as hard requirement.
- If a claim cannot be reproduced from repository artifacts and commands, it does not ship.

3. Explicit uncertainty.
- Every report includes limitations and threats to validity.

4. Controlled scope.
- No speculative modeling in core findings.
- No broad claims beyond measured evidence window.

## Mechanics: Repository Structure

- `reports/`: report-specific content, definitions, protocols, data dictionaries, and assets.
- `runs/`: immutable run outputs keyed by run ID.
- `pipelines/`: run, validate, and publish scripts.
- `claims/`: claim ledger mapping each headline number to artifact/query.
- `schemas/`: schema contracts for claims/data.
- `citations/`: source tracking for timeline/regulatory statements.
- `docs/`: GitHub Pages index and report pages.

## Mechanics: Execution Lifecycle

## 1) Define

Lock definitions before execution:

- `reports/openclaw-2026/definitions.md`
- `reports/ai-tool-sprawl-q1-2026/definitions.md`

Lock protocol before execution:

- `reports/openclaw-2026/study-protocol.md`
- `reports/ai-tool-sprawl-q1-2026/study-protocol.md`

## 2) Run

Create immutable run scaffolds:

- `pipelines/openclaw/run.sh --run-id <id>`
- `pipelines/sprawl/run.sh --run-id <id>`

Write artifacts under:

- `runs/openclaw/<run_id>/...`
- `runs/tool-sprawl/<run_id>/...`

Current script status:

- `pipelines/*/run.sh` currently scaffolds run directories and manifests.
- Actual workload execution commands are intentionally not hardcoded yet and must be added per finalized test plan.

## 3) Derive Claims

Update claim values:

- `claims/openclaw-2026/claims.json`
- `claims/ai-tool-sprawl-q1-2026/claims.json`

Each claim must include:

- artifact path
- deterministic query
- finalized value

## 4) Validate

Scaffold/readiness validation:

- `pipelines/openclaw/validate.sh`
- `pipelines/sprawl/validate.sh`

Strict publish readiness (hard fail on unresolved placeholders):

- `pipelines/openclaw/validate.sh --run-id <id> --strict`
- `pipelines/sprawl/validate.sh --run-id <id> --strict`

Validation includes:

- claims gate
- threshold gate
- hash manifest generation

## 5) Package

Create publication bundle:

- `pipelines/openclaw/publish_pack.sh --run-id <id>`
- `pipelines/sprawl/publish_pack.sh --run-id <id>`

Each package includes content, claims, source logs, and checksum manifest.

## OpenClaw Execution Model (Required)

Run OpenClaw fully in an isolated containerized lab:

- dual-lane setup (ungoverned + governed)
- identical workload profile across lanes
- no production credentials
- no customer data
- bounded side effects

Governed lane must enforce tool-boundary decisions as non-executable for non-`allow` outcomes.

Reference controls:

- `reports/openclaw-2026/container-config/docker-compose.yml`
- `reports/openclaw-2026/container-config/ISOLATION_REQUIREMENTS.md`

## Wrkr and Gait Roles in This Repo

- Wrkr:
  - primary measurement engine for sprawl inventory/approval/regulatory outputs.
- Gait:
  - primary enforcement/evidence comparison engine for OpenClaw governed lane.

Positioning rule:

- reports are research-first.
- tools are disclosed as open-source methods, not as sales collateral.

## Publication Gating Logic

Threshold policy file:

- `pipelines/config/publish-thresholds.json`

If hero metrics are weak, publication is delayed.

This prevents low-signal reports from damaging initiative credibility.

## Source Discipline

Timeline claims:

- `citations/openclaw-timeline-sources.md`

Regulatory claims:

- `citations/sprawl-regulatory-sources.md`

No timeline or regulatory statement should appear in a final report without a logged source.

## What Success Looks Like

1. Third parties can reproduce headline numbers from repository artifacts.
2. Reports are cited as technical research, not dismissed as vendor marketing.
3. Public datasets become reusable across quarters with stable schemas.
4. The full evidence chain remains auditable and reproducible over time.
