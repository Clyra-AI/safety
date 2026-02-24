# Isolation Requirements

These controls are mandatory for OpenClaw case-study runs.

## Environment controls

- Disposable container environment only.
- No production credentials or production secrets.
- No customer data.
- Internal-only lab network by default.
- No privileged containers.
- Drop Linux capabilities and enable `no-new-privileges`.

## Data controls

- Use synthetic or sanitized datasets only.
- Store raw outputs under `runs/openclaw/<run_id>/raw`.
- Store derived summaries under `runs/openclaw/<run_id>/derived`.

## Execution controls

- Route governed lane through tool-boundary enforcement wrapper.
- Treat non-`allow` outcomes as non-executable.
- Verify evidence artifacts before publication.

## Publication controls

- Claims and threshold gates must pass.
- Reproducibility hash manifest must be generated.
