# Research Policy Inputs

Default policy inputs for the Q1 2026 research cycle.

Files:

- `approved-tools.v1.yaml`
- `production-targets.v1.yaml`
- `campaign-segments.v1.yaml`
- `regulatory-scope.v1.json`
- `regulatory-mappings.v1.yaml`
- `openclaw-egress-allowlist.txt`
- `sprawl-egress-allowlist.txt`

Notes:

- These are pinned research inputs and should be versioned per cycle.
- `approved-tools.v1.yaml` currently uses a default approved tool-type baseline (`codex`, `copilot`, `cursor`, `claude`).
- `production-targets.v1.yaml` is schema-valid with empty targets by default (safe default; effectively no production targets selected).
- Segment metadata defaults to empty (`orgs: {}`), which routes benchmarking to `unknown` buckets unless populated later.
- `regulatory-scope.v1.json` controls framework applicability by organization:
  - defaults: `eu_ai_act=true`, `soc2=true`, `pci_dss=true`
  - set `orgs.<owner>.pci_dss=false` to opt out of PCI proxy rows for non-PCI targets.
- `regulatory-mappings.v1.yaml` documents deterministic proxy mappings for EU AI Act, SOC 2, and PCI DSS 4.0.1 control IDs used in exports.
- OpenClaw allowlist is intentionally empty because canonical runs require internal-only container networking.
- Sprawl allowlist defaults to GitHub acquisition hosts and is enforced by `pipelines/sprawl/run.sh`.
