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
- default stratified mix: `50% ai_native`, `30% dev_platform`, `20% security_platform`
- expanded AI-native candidate pool for agent-framework and agent-orchestration repos
- stronger deterministic exclusions for obvious tutorial, template, docs, prompt-pack, boilerplate, and mirror repos

The publication weighting is not intended to mimic the broader public GitHub population.
It is intentionally biased toward repositories that combine visible AI adoption with meaningful software-delivery and security surface, because those are the environments where AppSec, audit, and platform-governance questions become operationally important.

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

## Narrative Boundary

The publication manuscript should treat this study primarily as a software-delivery governance baseline, not as a generic "AI adoption" survey.

- adoption signal matters because it anchors relevance
- delivery-surface exposure matters because it connects to code, CI, and operational write paths
- evidence and approval gaps matter because they determine whether leadership, audit, and AppSec can verify control claims

## Publication Boundary

Headline regulatory claims remain limited to deterministic or proof-backed outputs for:

- EU AI Act
- SOC 2
- PCI DSS 4.0.1

Colorado AI Act, Texas TRAIGA, and NIST mappings remain appendix-only until control IDs and proof-backed rollups are harmonized.

## Activation Checklist

Before the first v2 campaign:

1. pin the intended Wrkr revision in `pipelines/sprawl/tooling.lock.json`
2. vendor the matching Wrkr revision into this repo with `pipelines/sprawl/vendor_wrkr.sh`
3. collect the immutable run with `pipelines/sprawl/run_v2.sh`
4. complete reviewer-owned gold labels and rerun `pipelines/sprawl/calibrate_detectors_v2.sh --gold-labels <path>`
5. finalize claim values with `pipelines/sprawl/finalize_claims_v2.sh`
6. update the canonical claims ledger from the immutable run
7. pass `pipelines/sprawl/validate_v2.sh --run-id <id> --lane full --strict`
