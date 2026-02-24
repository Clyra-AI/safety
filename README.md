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

## Repository Structure

- `AGENTS.md`: operating rules and quality bar for AI agents in this repository
- `docs/`: GitHub Pages index and per-report pages
- `reports/`: report packages, definitions, protocols, data dictionaries
- `runs/`: immutable run outputs keyed by report and run ID
- `pipelines/`: run, validation, threshold, and packaging scripts
- `claims/`: claim ledgers mapping metrics to artifact/query pairs
- `schemas/`: schema contracts
- `citations/`: source logs for timeline and regulatory claims

## Validation and Publish Gates

Readiness checks:

- `pipelines/openclaw/validate.sh`
- `pipelines/sprawl/validate.sh`

Strict publish readiness:

- `pipelines/openclaw/validate.sh --run-id <id> --strict`
- `pipelines/sprawl/validate.sh --run-id <id> --strict`

Common gates:

- `pipelines/common/claim_gates.sh`
- `pipelines/common/threshold_gate.sh`
- `pipelines/common/hash_manifest.sh`

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for contribution standards and validation expectations.

## License

Split license model:

- reports and narrative content: CC BY 4.0
- code and methodology scripts: MIT
- data: CC BY 4.0 by default, CC0 only when explicitly marked

See `LICENSE` and `LICENSES/` for details.
