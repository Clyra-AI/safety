# Run Artifacts

Store immutable run outputs by report and run ID.

Layout:

- `runs/openclaw/<run_id>/{config,raw,derived,artifacts}`
- `runs/tool-sprawl/<run_id>/{states,states-enrich,scans,agg,appendix,artifacts}`

Run semantics:

- `pipelines/openclaw/run.sh --run-id <id> --dry-run` and `pipelines/sprawl/run.sh --run-id <id> --dry-run` preview actions only.
- First creation uses `pipelines/*/run.sh --run-id <id>`.
- Existing run IDs fail fast by default.
- Use `--resume` to continue an existing run ID without overwriting prior scaffold artifacts.

Execution behavior:

- OpenClaw run script executes lane workloads, writes raw and derived summaries, and emits claim/repro metadata artifacts.
- Sprawl run script executes campaign scans (Wrkr or deterministic synthetic fallback), writes aggregate/appendix outputs, and emits claim/repro metadata artifacts.

Large generated directories are ignored by default in `.gitignore` (`raw`, `derived`, `states`, `scans`, `agg`, `appendix`).

Artifact manifests under `artifacts/` are intended to remain trackable for reproducibility.
