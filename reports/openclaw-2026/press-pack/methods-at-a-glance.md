# OpenClaw Methods at a Glance

Status: release candidate

Reporter fact-check summary:

- Run ID: `openclaw-live-24h-20260228T143341Z`
- Window (UTC): `2026-02-28T14:33:41Z` to `2026-03-01T14:33:41Z`
- Lanes:
  - ungoverned baseline
  - governed boundary enforcement (non-`allow` is non-executable)
- Workload: `live`, scenario set `core5`:
  - `inbox_cleanup`
  - `drive_sharing`
  - `finance_ops`
  - `secrets_handling`
  - `ops_command`
- Runtime isolation:
  - containerized lanes
  - no production credentials
  - read-only root filesystem and dropped capabilities
- Reproducibility:
  - OpenClaw source pin recorded in run manifest
  - Wrkr/Gait commit SHAs recorded in run manifest
  - claim values derived by deterministic `jq` queries in `claims/openclaw-2026/claims.json`
- Evidence artifacts:
  - `runs/openclaw/openclaw-live-24h-20260228T143341Z/artifacts/verification/evidence-verification.json`
  - `reports/openclaw-2026/data/runs/openclaw-live-24h-20260228T143341Z/`
- Key limitations:
  - single pinned source snapshot
  - one canonical 24-hour run
  - controlled scenario workload, not uncontrolled production telemetry
