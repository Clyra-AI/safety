# Pipeline Config

`publish-thresholds.json` defines:

- required claim thresholds (hard publish gate)
- recommended claim thresholds (advisory strength band for headline quality)

Current defaults:

- OpenClaw:
  - required:
    - `openclaw_total_tool_calls_24h >= 2000`
    - `openclaw_policy_violations_24h >= 500`
    - `openclaw_governed_evidence_verification_rate_pct >= 99.0`
  - recommended:
    - `openclaw_total_tool_calls_24h >= 5000`
    - `openclaw_policy_violations_24h >= 1000`
    - `openclaw_governed_evidence_verification_rate_pct >= 99.9`
- Sprawl:
  - required:
    - `sprawl_unapproved_to_approved_ratio >= 2.5`
    - `sprawl_avg_unknown_tools_per_org >= 1.5`
    - `sprawl_orgs_scanned >= 500`
  - recommended:
    - `sprawl_unapproved_to_approved_ratio >= 4.0`
    - `sprawl_avg_unknown_tools_per_org >= 3.0`
    - `sprawl_article50_gap_prevalence_pct >= 30.0`

Notes:

- Thresholds are policy controls, not scientific conclusions.
- Update thresholds only with explicit rationale in commit message.
- Required threshold checks run through `pipelines/common/threshold_gate.sh`.
- Recommended thresholds are advisory and currently reviewed manually in report planning.
- In non-strict validation mode, threshold checks are skipped until claim values are finalized (not `TBD`).
- In strict mode, unresolved claim values fail validation.
