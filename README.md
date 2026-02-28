# Clyra AI Safety Initiative

Independent, reproducible research on AI governance gaps in enterprise and open-source environments.

## What This Is

This repository contains the methodology, source artifacts, and validation workflows for each Clyra AI Safety Initiative report.  
Every headline finding is expected to map to:

- a versioned artifact
- a deterministic query in the claims ledger
- a reproducible execution path in `pipelines/`

The intent is simple: clone it, rerun it, verify it.

## Research Status

Reports are currently in progress (not yet published from this repo):

| Report | Status | Report Folder |
|---|---|---|
| 1.5 Million Agents, Zero Governance: The OpenClaw Case Study | In progress | [`reports/openclaw-2026/`](reports/openclaw-2026/) |
| The State of AI Tool Sprawl, Q1 2026 | In progress | [`reports/ai-tool-sprawl-q1-2026/`](reports/ai-tool-sprawl-q1-2026/) |

## Methodology

The research workflow uses two open-source tools:

- [Wrkr](https://github.com/Clyra-AI/wrkr): AI tool discovery and inventory
- [Gait](https://github.com/Clyra-AI/gait): tool-boundary policy enforcement and evidence generation

Deterministic contract:

- same inputs, same pinned tool versions, same commit SHAs, same detector set, same command sequence => same derived outputs

See report-specific methodology:

- [`reports/openclaw-2026/methodology.md`](reports/openclaw-2026/methodology.md)
- [`reports/ai-tool-sprawl-q1-2026/methodology.md`](reports/ai-tool-sprawl-q1-2026/methodology.md)

Pre-registration controls:

- [`reports/openclaw-2026/preregistration.md`](reports/openclaw-2026/preregistration.md)
- [`reports/ai-tool-sprawl-q1-2026/preregistration.md`](reports/ai-tool-sprawl-q1-2026/preregistration.md)
- [`internal/headline_rubric.md`](internal/headline_rubric.md) (headline selection and scoring contract)

## Repository Structure

- `AGENTS.md`: operating rules and quality bar for AI agents in this repository
- `CITATION.cff`: citation metadata for researchers and analysts
- `docs/`: GitHub Pages index and per-report pages
- `reports/`: report packages, definitions, protocols, data dictionaries
- `runs/`: immutable run outputs keyed by report and run ID
- `pipelines/`: run, validation, threshold, and packaging scripts
- `claims/`: claim ledgers mapping metrics to artifact/query pairs
- `schemas/`: schema contracts
- `citations/`: source logs for timeline and regulatory claims

## Run Semantics

Run IDs are immutable by default:

- preview only: `pipelines/*/run.sh --run-id <id> --dry-run`
- create run: `pipelines/*/run.sh --run-id <id>`
- continue existing run: `pipelines/*/run.sh --run-id <id> --resume`

Execution behavior:

- OpenClaw: `pipelines/openclaw/run.sh` executes dual lanes, derives summaries, writes claim-value + threshold-evaluation artifacts, and emits reproducibility metadata.
- Sprawl: `pipelines/sprawl/run.sh` executes campaign scans, builds aggregate/appendix artifacts, writes claim-value artifacts, and emits reproducibility metadata.

If a run ID already exists, `run.sh` fails fast unless `--resume` is explicitly provided.

## Validation and Publish Gates

Readiness checks:

- `pipelines/openclaw/validate.sh`
- `pipelines/sprawl/validate.sh`

Strict publish readiness:

- `pipelines/openclaw/validate.sh --run-id <id> --strict`
- `pipelines/sprawl/validate.sh --run-id <id> --strict`

Common gates:

- `pipelines/common/claim_gates.sh`
- `pipelines/common/citation_gates.sh`
- `pipelines/common/threshold_gate.sh`
- `pipelines/common/metric_coverage_gate.sh`
- `pipelines/common/derive_claim_values.sh`
- `pipelines/common/evaluate_claim_values.sh`
- `pipelines/common/hash_manifest.sh`

In strict mode, unresolved `TBD` markers in citation logs fail validation.

## Output Formats

Each report is published in two formats:

- `research-pack`: full technical package (report source, methodology, claims, citations, run artifacts)
- `press-pack`: media-friendly package (media brief, methods-at-a-glance, stat-card copy)

`pipelines/*/publish_pack.sh` builds both under:

- `runs/<report-scope>/<run_id>/artifacts/publish-pack/research-pack/`
- `runs/<report-scope>/<run_id>/artifacts/publish-pack/press-pack/`

## Artifact Promotion

Run directories are intentionally ignored in git by default.
After a clean run, promote only canonical reproducibility artifacts into a tracked path:

- `pipelines/openclaw/promote_run_artifacts.sh --run-id <run_id>`

Default destination:

- `reports/openclaw-2026/data/runs/<run_id>/`

Optional full raw archive (for release upload):

- `pipelines/openclaw/promote_run_artifacts.sh --run-id <run_id> --raw-archive-out runs/openclaw/<run_id>/artifacts/openclaw-<run_id>-full-run.tar.gz`

Packaged research/press bundles can include a full raw archive:

- `pipelines/openclaw/publish_pack.sh --run-id <run_id> --include-raw-archive`

Release CI:

- GitHub Actions workflow: `.github/workflows/openclaw-release-bundle.yml`
- Trigger manually with `run_id` after promoted artifacts are committed.

## Manuscript Build Policy

Canonical manuscript source lives under each report's `manuscript/` directory.  
Preferred source format is Markdown or LaTeX.

Recommended deterministic build commands (examples):

- Markdown to PDF with Pandoc:
  - `pandoc reports/<report-id>/manuscript/report.md --pdf-engine=xelatex --include-in-header=reports/<report-id>/manuscript/pdf-header.tex -V geometry:margin=1in -o reports/<report-id>/report.pdf`
- LaTeX to PDF with latexmk:
  - `latexmk -pdf -interaction=nonstopmode reports/<report-id>/manuscript/report.tex`

Header policy:

- Use report-local `manuscript/pdf-header.tex` for portable font/code-block styling.
- Avoid machine-specific fonts in header files (for example `Helvetica Neue`, `Menlo`).

Build output paths:

- `reports/openclaw-2026/report.pdf`
- `reports/ai-tool-sprawl-q1-2026/report.pdf`

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for contribution standards and validation expectations.

## License

Split license model:

- reports and narrative content: CC BY 4.0
- code and methodology scripts: MIT
- data: CC BY 4.0 by default, CC0 only when explicitly marked

See `LICENSE` and `LICENSES/` for details.
