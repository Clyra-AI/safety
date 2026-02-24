# Pipeline Config

`publish-thresholds.json` defines minimum claim values required to publish each report.

Current defaults:

- OpenClaw:
  - `openclaw_total_tool_calls_24h >= 2000`
  - `openclaw_policy_violations_24h >= 500`
  - `openclaw_governed_evidence_verification_rate_pct >= 99.0`
- Sprawl:
  - `sprawl_unapproved_to_approved_ratio >= 2.5`
  - `sprawl_avg_unknown_tools_per_org >= 1.5`
  - `sprawl_orgs_scanned >= 500`

Notes:

- Thresholds are policy controls, not scientific conclusions.
- Update thresholds only with explicit rationale in commit message.
- Threshold checks run through `pipelines/common/threshold_gate.sh`.
- In non-strict validation mode, threshold checks are skipped until claim values are finalized (not `TBD`).
- In strict mode, unresolved claim values fail validation.
