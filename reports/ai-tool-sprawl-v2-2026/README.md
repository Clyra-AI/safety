# AI Tool Sprawl V2 2026 Report Package

Status: locked execution controls; manuscript draft

This directory contains the v2 report backbone for a deterministic AI tool and agent sprawl study focused on software delivery, AppSec, and governance evidence.
It preserves the locked Q1 2026 tool-only report and opens a separate tool+agent track.

Backbone status on 2026-03-11:

- report/control docs exist
- claims scaffold exists
- calibration schema is extended for agent surfaces
- manuscript/template stubs exist
- v2-specific target selection profile exists in `pipelines/sprawl/generate_targets.sh`
- v2 run, rebuild, validation, and calibration scripts exist in `pipelines/sprawl/`
- publication release still requires finalized claims, gold-label calibration review, and strict post-run validation

Expected outputs after activation:

- `report.pdf`
- `methodology-one-pager.md` (or PDF equivalent)
- `methodology.md`
- `definitions.md`
- `study-protocol.md`
- `preregistration.md`
- `calibration/`
- `manuscript/`
- `data/`

Execution note:

- out-of-box `wrkr` plus `proof` is sufficient for deterministic per-target capture
- CAISI now has repo-side aggregation, calibration templating, and claim-gating logic for v2 collection runs
- the locked v2 controls support full-scale collection, while final publication still requires post-run claim finalization and strict validation
