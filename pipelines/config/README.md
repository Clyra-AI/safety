# Pipeline Config

`publish-thresholds.json` defines:

- required claim thresholds (hard publish gate)
- recommended claim thresholds (advisory strength band for headline quality)

Current defaults:

- OpenClaw:
  - required:
    - `openclaw_total_tool_calls_24h >= 1000`
    - `openclaw_policy_violations_24h >= 500`
    - `openclaw_sensitive_access_without_approval >= 25`
    - `openclaw_governed_evidence_verification_rate_pct >= 99.0`
    - `openclaw_destructive_attempts_24h >= 50`
    - `openclaw_ignored_stop_rate_pct >= 1.0`
    - `openclaw_governed_destructive_block_rate_pct >= 99.0`
    - `openclaw_stop_to_halt_p95_sec <= 15.0`
  - recommended:
    - `openclaw_total_tool_calls_24h >= 5000`
    - `openclaw_policy_violations_24h >= 1000`
    - `openclaw_sensitive_access_without_approval >= 100`
    - `openclaw_governed_evidence_verification_rate_pct >= 99.9`
    - `openclaw_destructive_attempts_24h >= 200`
    - `openclaw_ignored_stop_rate_pct >= 5.0`
    - `openclaw_governed_destructive_block_rate_pct >= 99.9`
    - `openclaw_stop_to_halt_p95_sec <= 5.0`
- Sprawl:
  - required:
    - `sprawl_unapproved_to_approved_ratio >= 2.5`
    - `sprawl_avg_unknown_tools_per_org >= 1.5`
    - `sprawl_orgs_scanned >= 500`
    - `sprawl_orgs_with_destructive_tooling_pct >= 15.0`
    - `sprawl_orgs_without_approval_gate_pct >= 10.0`
  - recommended:
    - `sprawl_unapproved_to_approved_ratio >= 4.0`
    - `sprawl_avg_unknown_tools_per_org >= 3.0`
    - `sprawl_article50_gap_prevalence_pct >= 30.0`
    - `sprawl_orgs_with_destructive_tooling_pct >= 30.0`
    - `sprawl_orgs_without_approval_gate_pct >= 20.0`
    - `sprawl_orgs_prompt_only_controls_pct >= 25.0`
    - `sprawl_orgs_without_audit_artifacts_pct >= 30.0`

Notes:

- Thresholds are policy controls, not scientific conclusions.
- Update thresholds only with explicit rationale in commit message.
- Required threshold checks run through `pipelines/common/threshold_gate.sh`.
- Run-level projected threshold evaluation (including sub-24h scaling) runs through `pipelines/common/evaluate_claim_values.sh`.
- Coverage checks for claim IDs and threshold IDs run through `pipelines/common/metric_coverage_gate.sh`.
- Recommended thresholds are advisory and currently reviewed manually in report planning.
- In non-strict validation mode, threshold checks are skipped until claim values are finalized (not `TBD`).
- In strict mode, unresolved claim values fail validation.
