# AI Tool Sprawl V2 Backbone

Status: active scaffold  
Updated: `2026-03-12`

This note records what v2 can use directly from `wrkr` and `proof`, and what still needs CAISI-specific implementation in this repo.

## Short Answer

For raw deterministic capture, out-of-box `wrkr` and `proof` are enough.

For a publishable CAISI v2 report, no, they are not enough on their own.
This repo still needs campaign-level derivation, calibration, claims, and validation logic.

## What Out-of-Box Wrkr Already Gives V2

- `inventory.tools`
- `inventory.agents`
- `agent_privilege_map`
- `attack_paths`
- `compliance_summary`
- deterministic approval classifications on tool rows
- deterministic deployment and missing-binding hints on agent rows

## What Out-of-Box Proof Already Gives V2

- built-in framework catalog
- framework loading and schema validation
- evidence-set coverage logic
- publish-eligible framework backbone for `eu-ai-act`, `soc2`, and `pci-dss`

## What Still Requires Repo-Side CAISI Logic

- campaign summary generation for tool plus agent metrics
- organization-level aggregation across scan payloads
- appendix exports for agents, privilege maps, and attack paths
- calibration artifacts and thresholds for agent surfaces
- claim ledger derivation and threshold evaluation
- explicit separation between headline-eligible framework claims and appendix-only mappings

## V2 Selection Frame

The generator now supports an explicit v2 sampling profile via:

- `pipelines/sprawl/generate_targets.sh --selection-profile v2`

This keeps the locked v1 default path unchanged while versioning the v2 cohort logic:

- same core eligibility rules as v1
- default stratified mix of `50% ai_native`, `30% dev_platform`, `20% security_platform`
- expanded AI-native queries for agent-framework and agent-orchestration repos
- stronger deterministic exclusions for tutorial, template, docs, prompt-pack, boilerplate, and mirror repos

The publication weighting is intentionally more delivery- and security-heavy than the calibration cohort so the final denominator remains useful for AppSec, platform, and audit conversations.

## Recommended Implementation Order

1. vendor the intended Wrkr revision into `third_party/wrkr`
2. derive `campaign-summary-v2.json` from per-target scans
3. emit `agent-inventory.csv`, `agent-privilege-map.csv`, and `attack-paths.csv`
4. add v2 calibration generation and evaluation
5. register v2 thresholds and validators
6. lock preregistration and run calibration before any publication-scale cohort
