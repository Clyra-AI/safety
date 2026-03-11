# Methodology - AI Tool Sprawl V2 2026

## Scope

V2 expands the sprawl study from tool-only baseline inventory to tool plus agent posture.
The unit of analysis remains one deterministic public `owner/repo` target per campaign row.

## V2 Target Selection Profile

V2 keeps the core eligibility rules from the locked v1 campaign:

- public GitHub `owner/repo` targets only
- one repo per owner
- `archived=false`
- `fork=false`
- recent activity cutoff via `pushed>=<date>`
- optional size cap

V2 changes the publication sampling frame through an explicit generator profile:

- `pipelines/sprawl/generate_targets.sh --selection-profile v2`
- default stratified mix: `60% ai_native`, `20% dev_platform`, `20% security_platform`
- expanded AI-native candidate pool for agent-framework and agent-orchestration repos
- stronger deterministic exclusions for obvious tutorial, template, docs, prompt-pack, boilerplate, and mirror repos

The default generator path remains `v1`, so the legacy Q1 2026 sampling frame is unchanged unless the new profile is requested.

## What out-of-box Wrkr and Proof already provide

For a single target, out-of-box `wrkr` and `proof` already provide the core deterministic raw material needed for v2:

- tool inventory via `inventory.tools`
- agent inventory via `inventory.agents`
- agent privilege posture via `agent_privilege_map`
- agent-linked attack-path candidates via `attack_paths`
- publish-eligible compliance rollups via `compliance_summary`
- framework definitions and evidence-set coverage logic via bundled `proof` frameworks

That means v2 does not require custom collection logic for per-target deterministic capture.

## What CAISI still needs in this repo

V2 still requires repo-side logic before publication:

- campaign aggregation from per-target tool and agent payloads
- v2 appendix exports and data dictionary
- claim-value derivation for tool+agent metrics
- calibration coverage for agent presence, deployment, binding quality, and privilege posture
- publish gating that separates headline-eligible frameworks from appendix-only mappings

In short:

- raw capture: out-of-box `wrkr` and `proof` are enough
- publishable campaign math: special logic is still required in this repo

## Publication Boundary

Headline regulatory claims remain limited to deterministic or proof-backed outputs for:

- EU AI Act
- SOC 2
- PCI DSS 4.0.1

Colorado AI Act, Texas TRAIGA, and NIST mappings remain appendix-only until control IDs and proof-backed rollups are harmonized.

## Activation Checklist

Before the first v2 campaign:

1. vendor the intended Wrkr revision into this repo
2. implement `campaign-summary-v2.json` derivation
3. implement v2 appendix exports
4. lock definitions and preregistration
5. add v2 claim thresholds and validation coverage
6. run v2 calibration before publication-scale scanning
