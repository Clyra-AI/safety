# OpenClaw 24-Hour Container Reproduction Setup

This folder contains the exact runtime configuration used for the governed vs ungoverned comparison.

## Files

- `Dockerfile`
- `docker-compose.yml`
- `gait-policies/`
- `ISOLATION_REQUIREMENTS.md`

## Usage

Populate this folder with the locked configuration from the run manifest, then execute via the pipeline scripts in `pipelines/openclaw/`.

The compose model defines two lanes (`openclaw-ungoverned`, `openclaw-governed`) on an internal network with dropped capabilities and no-new-privileges enabled.
