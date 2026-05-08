# AI Tool and Agent Sprawl 2026 Methods At A Glance

- **Run ID:** `sprawl-v2-top250-20260508a`
- **Measured cohort:** locked `250` public targets
- **Cohort mix:** `125` AI-native, `75` developer-platform, `50` security-platform
- **Selection frame:** public GitHub repositories, one repo per owner, stratified v2 publication profile
- **Collection mode:** deterministic baseline, local clone-sourced scans
- **Headline tool scope:** excludes `tool_type == "source_repo"`
- **Agent scope:** derived from `inventory.agents[]`, `agent_privilege_map[]`, and `attack_paths[]`
- **Wrkr pin:** `9134c3cf2ab903905babf5a38aa29e1526928bc7` (`9134c3c`)
- **Framework families treated as headline-eligible:** EU AI Act, SOC 2, PCI DSS
- **Primary aggregate artifact:** `runs/tool-sprawl/sprawl-v2-top250-20260508a/agg/campaign-summary-v2.json`
- **Primary appendix artifact:** `runs/tool-sprawl/sprawl-v2-top250-20260508a/appendix/combined-appendix-v2.json`
- **Validation state used for publication:** strict full-lane validation passed, required threshold checks passed `6/6`, recommended threshold checks passed `11/11`

## Interpretation Guardrails

- This report is strongest as a public visibility and governance-readiness study.
- It does not claim direct visibility into private runtime privilege or production configuration.
- Public deployment signal does not prove fully governed runtime execution.
- Public `0%` production-write results should not be interpreted as internal safety guarantees.
- One target failed scanner parsing and was carried fail-closed into aggregate outputs.
