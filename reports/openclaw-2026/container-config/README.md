# OpenClaw 24-Hour Container Reproduction Setup

This folder contains the runtime configuration used for governed vs ungoverned comparison lanes.

## Files

- `Dockerfile`
- `docker-compose.yml`
- `gait-policies/`
- `ISOLATION_REQUIREMENTS.md`

## Usage

Run through the OpenClaw pipeline script from repository root:

- dry-run: `pipelines/openclaw/run.sh --run-id <id> --dry-run`
- synthetic execution: `pipelines/openclaw/run.sh --run-id <id> --execution synthetic --workload synthetic`
- container execution: `pipelines/openclaw/run.sh --run-id <id> --execution container --workload synthetic`

`docker-compose.yml` now executes both lanes through `pipelines/openclaw/execute_lane.sh` with:

- internal-only lab network (`internal: true`)
- dropped Linux capabilities
- `no-new-privileges`
- read-only root filesystem + tmpfs scratch
- CPU/memory/pid resource caps
