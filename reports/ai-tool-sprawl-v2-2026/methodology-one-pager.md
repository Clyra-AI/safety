# AI Tool Sprawl V2 2026 - Methodology One Pager

## What changes from v1

- v1 measured deterministic tool approval and evidence posture
- v2 adds first-class deterministic agent inventory, binding posture, deployment posture, and agent privilege posture
- v2 publication framing shifts toward software-delivery and AppSec relevance rather than AI-native ecosystem prevalence alone

## What stays the same

- deterministic baseline remains canonical
- enrich remains separate and explicitly time-sensitive
- headline tool metrics still exclude `tool_type == "source_repo"`
- legal language stays scoped to deterministic proxies unless proof-backed control coverage is available

## Raw data source

Out-of-box `wrkr scan --json` provides the v2 raw surfaces:

- `inventory.tools`
- `inventory.agents`
- `agent_privilege_map`
- `attack_paths`
- `compliance_summary`

Bundled `proof` frameworks provide reusable framework definitions and evidence-set coverage logic.

## What is implemented now

- v2 target generation for publication and calibration cohorts
- v2 campaign aggregation from `wrkr` scan JSON
- v2 appendix exports for tools, agents, privilege maps, attack paths, and framework rollups
- v2 run wrapper, validation path, and calibration template generation

## Why this matters operationally

- public AI-tool signals matter most when they sit inside software-delivery systems
- regulated or trust-sensitive engineering environments need evidence, not just inventory
- the study is strongest when it can connect AI adoption, delivery surface, and proof-of-control posture in the same denominator

## What still separates collection from publication

- finalized claim values populated from the immutable publication run
- gold-labeled agent calibration evaluation for a publication cohort
- final manuscript population from the locked full-scale run

This package is now executable for both test and full collection runs. Publication remains a post-run validation step.
