# AI Tool Sprawl V2 2026 Definitions

Status: locked  
Version: `v1`  
Created: `2026-03-11`

This file defines the locked classifications and formulas for the initial v2 tool+agent sprawl report.

## Headline Scope Filters

Tool headline metrics exclude tool rows where `tool_type == "source_repo"`.

- tool headline scope is derived from `inventory.tools[]`
- agent scope is derived from `inventory.agents[]` and `agent_privilege_map[]`
- raw tool totals remain published separately for transparency

## Tool Classifications

Tool classifications are carried forward from `ai-tool-sprawl-q1-2026`.

### Baseline-approved tool

A discovered AI tool classified as baseline-approved only when deterministically matched to the approved-tool policy/list used for the campaign.

### Explicit-unapproved tool

A discovered AI tool classified as explicit-unapproved when:

- approval classification is `unapproved`, and
- approval evidence is present (not missing/unknown/null).

### Approval-unknown tool

A discovered AI tool classified as approval-unknown when:

- approval evidence is incomplete or ambiguous, or
- approval policy coverage cannot deterministically resolve status.

### Not-baseline-approved tool

Union set used for publication claims:

- `not_baseline_approved = explicit_unapproved + approval_unknown`

## Agent Classifications

### Declared agent

A deterministically detected agent row emitted under `inventory.agents[]`.

### Binding-complete agent

A declared agent where `missing_bindings` is empty.

### Binding-incomplete agent

A declared agent where `missing_bindings` contains one or more values.

### Deployed agent

A declared agent where `deployment_status == "deployed"`.

### Write-capable agent

An `agent_privilege_map[]` row where `write_capable == true`.

### Exec-capable agent

An `agent_privilege_map[]` row where `exec_capable == true`.

### Credential-access agent

An `agent_privilege_map[]` row where `credential_access == true`.

### Production-write agent

An `agent_privilege_map[]` row where `production_write == true`.
If production-target policy is not configured, production-write claims remain omitted.

### Agent-linked attack path

An `attack_paths[]` row where any `edge_rationale[]` entry begins with `agent_to_`.

## Organization-Level Tool+Agent Derivations

### Agents present

- `org_has_agents = declared_agents > 0`

### Deployed agents present

- `org_has_deployed_agents = deployed_agents > 0`

### Incomplete bindings present

- `org_has_agents_missing_bindings = binding_incomplete_agents > 0`

### Write-capable agents present

- `org_has_write_capable_agents = write_capable_agents > 0`

### Exec-capable agents present

- `org_has_exec_capable_agents = exec_capable_agents > 0`

### Agent-linked attack paths present

- `org_has_agent_linked_attack_paths = agent_linked_attack_paths > 0`

## Evidence and Control Posture

Evidence posture remains deterministic.

- `evidence_tier` continues to use the v1 derivation unless explicitly version-bumped in protocol
- `orgs_without_verifiable_evidence_pct` remains scoped at the organization level

## Regulatory Boundaries

### Headline-eligible deterministic framework families in v2

- EU AI Act
- SOC 2
- PCI DSS 4.0.1

These are the only framework families currently treated as publish-eligible in the v2 scaffold because `wrkr` already emits proof-backed `compliance_summary` rows for them.

### Appendix-only mappings in v2

- Colorado AI Act
- Texas TRAIGA
- NIST AI governance mappings

These may appear in appendix analysis only until control IDs, source citations, and proof-backed rollups are harmonized.

### Not publish-grade in v2 without additional mapping work

- OWASP Agentic Top 10
- ISO 42001
- AIUC-1
- SOX

`proof` defines these frameworks, but this scaffold does not yet treat them as report-headline claim sources.

## Headline Metrics

Primary:

- `sprawl_v2_not_baseline_approved_to_approved_ratio`
- `sprawl_v2_orgs_with_agents_pct`

Supporting:

- `sprawl_v2_avg_agents_per_org`
- `sprawl_v2_orgs_with_deployed_agents_pct`
- `sprawl_v2_agents_missing_bindings_pct`
- `sprawl_v2_orgs_with_write_capable_agents_pct`
- `sprawl_v2_orgs_with_exec_capable_agents_pct`
- `sprawl_v2_orgs_with_agent_attack_paths_pct`
- `sprawl_v2_orgs_without_verifiable_evidence_pct`
- `sprawl_v2_article50_gap_prevalence_pct`
- `sprawl_v2_orgs_scanned`

## Lock Record

- Locked by: `David Ahmann`
- Locked at (UTC): `2026-03-11T23:26:49Z`
- Notes: `Initial locked v2 metric set for full-scale collection and post-run publish validation.`

## Change Control

- Any metric logic change requires a version bump in this file, a paired preregistration update, and rerun of affected metrics.
