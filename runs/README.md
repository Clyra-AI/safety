# Run Artifacts

Store immutable run outputs by report and run ID.

Layout:

- `runs/openclaw/<run_id>/{config,raw,derived,artifacts}`
- `runs/tool-sprawl/<run_id>/{states,states-enrich,scans,agg,appendix,artifacts}`

Large generated directories are ignored by default in `.gitignore` (`raw`, `derived`, `states`, `scans`, `agg`, `appendix`).

Artifact manifests under `artifacts/` are intended to remain trackable for reproducibility.
