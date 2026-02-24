# Research Policy Inputs

Default policy inputs for the Q1 2026 research cycle.

Files:

- `approved-tools.v1.yaml`
- `production-targets.v1.yaml`
- `campaign-segments.v1.yaml`

Notes:

- These are pinned research inputs and should be versioned per cycle.
- `approved-tools.v1.yaml` currently uses a default approved tool-type baseline (`codex`, `copilot`, `cursor`, `claude`).
- `production-targets.v1.yaml` is schema-valid with empty targets by default (safe default; effectively no production targets selected).
- Segment metadata defaults to empty (`orgs: {}`), which routes benchmarking to `unknown` buckets unless populated later.
