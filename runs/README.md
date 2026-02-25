# Run Artifacts

Store immutable run outputs by report and run ID.

Layout:

- `runs/openclaw/<run_id>/{config,raw,derived,artifacts}`
- `runs/tool-sprawl/<run_id>/{states,states-enrich,scans,agg,appendix,artifacts}`

Run semantics:

- Use `pipelines/openclaw/run.sh --run-id <id> --dry-run` or `pipelines/sprawl/run.sh --run-id <id> --dry-run` to preview actions without writing files.
- First creation uses `pipelines/*/run.sh --run-id <id>`.
- Existing run IDs fail fast by default.
- Use `--resume` to continue an existing run ID without overwriting prior scaffolding artifacts.

Large generated directories are ignored by default in `.gitignore` (`raw`, `derived`, `states`, `scans`, `agg`, `appendix`).

Artifact manifests under `artifacts/` are intended to remain trackable for reproducibility.
