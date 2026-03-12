# AI Tool Sprawl V2 2026 Study Protocol

Status: locked  
Version: `v2`  
Objective: produce a reproducible multi-organization AI tool and agent governance baseline.

## 1) Campaign Design

- canonical campaign mode: deterministic baseline scan
- supplemental enrich mode: separate run with explicit provenance (`as_of`, `source`), never merged into baseline headline claims
- target cohort: use a v2-specific public-repository frame generated with `pipelines/sprawl/generate_targets_v2.sh --purpose publication`
- runtime pinning: prefer repo-pinned Wrkr runtime (`go run` from `WRKR_REPO_PATH`) over ambient PATH binary unless explicit `WRKR_BIN` override is supplied

The v2 selection profile must preserve the v1 core eligibility rules while changing the sampling mix:

- one public `owner/repo` target per owner
- `archived=false`
- `fork=false`
- `pushed>=<date>` activity cutoff
- optional size cap
- default cohort weighting: `50% ai_native`, `30% dev_platform`, `20% security_platform`
- publication weighting is intentionally delivery- and security-heavier than the calibration cohort so the denominator better reflects AppSec-relevant software-delivery surface
- deterministic exclusions for obvious tutorial, example, template, docs, prompt-pack, and mirror repos

## 2) Required Scanner Surfaces

Per-target capture must come from out-of-box `wrkr scan --json` plus proof-backed framework loading:

- `inventory.tools`
- `inventory.agents`
- `agent_privilege_map`
- `attack_paths`
- `compliance_summary`
- `privilege_budget`
- `ranked_findings`

No live probing, runtime execution, or enrich-only fields may be merged into baseline claims.

## 3) Required Inputs

- organization/repository target list
- approved-tool policy list
- production-target policy for production-write claims
- regulatory applicability scope
- citation log for publish-eligible framework assertions

## 4) Required Outputs

- per-target scan JSON artifacts
- per-target derived state JSON for:
  - tool counts
  - agent counts
  - deployment/binding posture
  - agent privilege posture
  - evidence posture
  - publish-eligible regulatory posture
- campaign aggregate artifact:
  - `runs/tool-sprawl/<run_id>/agg/campaign-summary-v2.json`
- appendix exports:
  - `combined-appendix-v2.json`
  - `tool-inventory.csv`
  - `agent-inventory.csv`
  - `agent-privilege-map.csv`
  - `regulatory-gap-matrix.csv`
  - `attack-paths.csv`
  - `framework-rollups.csv`
- claims ledger values and query mapping
- calibration artifacts for both tool and agent surfaces

## 5) Proposed Core Endpoints

- tool approval visibility gap
- organization-level agent prevalence
- organization-level deployed-agent prevalence
- organization-level incomplete-binding prevalence
- organization-level write-capable and exec-capable agent prevalence
- organization-level agent-linked attack-path prevalence
- organization-level evidence-tier prevalence
- organization-level EU AI Act Article 50 proxy prevalence

## 6) Reproducibility Contract

Third-party reproduction must be possible from:

- run command sequence
- pinned Wrkr version and commit
- pinned Proof framework set used by the Wrkr build
- input lists and policy files
- generated campaign and appendix artifacts
- deterministic scope filter for tool headline metrics
- claim and threshold gates
- detector calibration summary for both tool and agent surfaces

## 7) Publication Guardrails

Publish only when:

- v2 derivation logic exists in this repo
- v2 claim and threshold coverage exists in shared validation
- calibration artifacts cover agent presence, deployment, bindings, and privilege posture
- all regulatory language remains explicitly scoped as deterministic proxy or proof-backed coverage result
- appendix-only mappings remain segregated from headline claims

## 8) Threats to Validity (Must Be Reported)

- sample-selection bias
- public-repo visibility limits
- detector coverage boundaries for agent declarations
- binding inference limits (`missing_bindings` does not prove runtime absence)
- temporal drift between scan and publication

Each threat requires mitigation and residual-risk text.

## 9) Execution Sequence

For the locked v2 lane:

1. freeze the publication target list and candidate catalog
2. execute the full collection run with `pipelines/sprawl/run_v2.sh --lane full`
3. populate `claims/ai-tool-sprawl-v2-2026/claims.json` from the immutable run artifacts
4. complete gold-label calibration evaluation for the publication detector set
5. run strict publish validation with `pipelines/sprawl/validate_v2.sh --run-id <id> --lane full --strict`

The first full-scale collection run and the final publish-validation step are intentionally separate so claims are finalized from the immutable run rather than guessed in advance.
