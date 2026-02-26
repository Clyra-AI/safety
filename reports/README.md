# Reports

Report packages live in subdirectories by report ID.

Notes:

- Report directories may contain in-progress scaffolding before publication.
- Every report directory must include a `preregistration.md` file before execution starts.
- Every report directory should maintain `manuscript/` (canonical research manuscript source).
- Every report directory should maintain `press-pack/` (media brief + methods-at-a-glance + stat-card copy).
- Publication status is tracked in the root README and per-report README files.
- Publish-ready bundles are generated from run artifacts via `pipelines/*/publish_pack.sh` into dual outputs (`research-pack` and `press-pack`).
