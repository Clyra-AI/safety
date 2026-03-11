# AI Tool Sprawl V2 2026 Data Dictionary

## Expected Files

- `aggregated-findings.csv`
- `tool-inventory.csv`
- `agent-inventory.csv`
- `agent-privilege-map.csv`
- `attack-paths.csv`
- `framework-rollups.csv`
- `regulatory-gap-matrix.csv`

## Notes

- tool inventory remains separated from agent inventory
- tool headline scope excludes `source_repo` rows
- agent exports come directly from `inventory.agents` and `agent_privilege_map`
- canonical source artifacts live under `runs/tool-sprawl/<run_id>/{agg,appendix,scans}`
