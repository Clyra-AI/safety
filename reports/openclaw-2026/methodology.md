# Methodology - OpenClaw 2026

## Scope

TBD.

Definitions lock: `definitions.md`  
Execution protocol: `study-protocol.md`

## Environment

See `container-config/`.

## Deterministic reproducibility contract

For this report, "deterministic" means the same inputs at the same repository commit SHAs, Wrkr/Gait versions, detector set, and command sequence produce the same derived outputs.

## External context boundary

- External threat-intel statistics are context framing only.
- They are never used as evidence values for OpenClaw claim IDs.
- Each context statistic must be logged in `citations/threat-context-sources.md` with source URL, publication date, and `Use=context-only`.

## Reproduction commands

TBD.

## Claim validation

See `/claims/openclaw-2026/claims.json`.
