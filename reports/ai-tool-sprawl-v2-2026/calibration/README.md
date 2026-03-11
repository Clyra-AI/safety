# Detector Calibration (AI Tool Sprawl V2)

This directory defines the draft calibration contract for both non-`source_repo` tool extraction and agent-surface quality before publication-scale campaigns.

## Why this exists

V2 adds first-class agent claims.
That means calibration must cover not just whether non-source tools exist, but also whether agents, deployments, bindings, and privilege posture are being surfaced consistently.

## Draft labeled dimensions

- non-`source_repo` tool presence and count
- agent presence and count
- deployed-agent presence
- incomplete-binding presence
- write-capable agent presence
- exec-capable agent presence
- agent-linked attack-path presence
- approval-unknown presence and count

## Draft activation floors

These are scaffolding targets, not canonical publish gates yet:

- tool non-source recall/precision existence: `>= 60.0`
- agent existence recall/precision: `>= 60.0`
- deployed-agent existence recall/precision: `>= 60.0`
- incomplete-binding existence recall/precision: `>= 60.0`
- write-capable agent existence recall/precision: `>= 60.0`
- exec-capable agent existence recall/precision: `>= 60.0`

## Expected outputs per run

- `runs/tool-sprawl/<run_id>/calibration/observed-by-target.csv`
- `runs/tool-sprawl/<run_id>/calibration/observed-non-source-tools.csv`
- `runs/tool-sprawl/<run_id>/calibration/observed-agents.csv`
- `runs/tool-sprawl/<run_id>/calibration/gold-labels.template.json`
- `runs/tool-sprawl/<run_id>/calibration/detector-coverage-summary.json`
- `runs/tool-sprawl/<run_id>/calibration/gold-label-evaluation.json`

## Label schema

Each gold-label entry is a JSON object with:

- `target`
- `expected_non_source_exists`
- `expected_non_source_count`
- `expected_agent_exists`
- `expected_agent_count`
- `expected_deployed_agent_exists`
- `expected_agent_missing_bindings_exists`
- `expected_write_capable_agent_exists`
- `expected_exec_capable_agent_exists`
- `expected_agent_attack_path_exists`
- `expected_unknown_exists`
- `expected_unknown_count`
- `reviewer`
- `notes`
