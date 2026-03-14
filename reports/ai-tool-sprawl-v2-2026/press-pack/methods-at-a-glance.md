# AI Tool and Agent Sprawl 2026 Methods At A Glance

- **Run ID:** `sprawl-v2-full-20260312b`
- **Measured subset:** `890` completed targets from a frozen `1,000`-target publication cohort
- **Selection frame:** public GitHub repositories, one repo per owner, stratified v2 publication profile
- **Collection mode:** deterministic baseline, clone-sourced scans
- **Headline tool scope:** excludes `tool_type == "source_repo"`
- **Agent scope:** derived from `inventory.agents[]`, `agent_privilege_map[]`, and `attack_paths[]`
- **Wrkr pin:** `fb819fb9ff235f1160c21103779904f871918cf3` (`v1.0.8`)
- **Framework families treated as headline-eligible:** EU AI Act, SOC 2, PCI DSS
- **Primary aggregate artifact:** `runs/tool-sprawl/sprawl-v2-full-20260312b/agg/campaign-summary-v2.json`
- **Primary appendix artifact:** `runs/tool-sprawl/sprawl-v2-full-20260312b/appendix/combined-appendix-v2.json`
- **Validation state used for publication subset:** relaxed validation passed, required threshold checks passed `6/6`

## Interpretation Guardrails

- This report is strongest as a public visibility and governance-readiness study.
- It does not claim direct visibility into private runtime privilege or production configuration.
- Public `0%` values for write-capable, exec-capable, or attack-path metrics should not be interpreted as internal safety guarantees.
- The missing `110` targets are all AI-native, so the completed subset likely understates some AI-native-heavy problems.
