# AGENTS.md - Operating Rules for AI Agents

This file defines required behavior for any AI agent operating in this repository.

## Mission

Produce independent, reproducible AI governance research artifacts that can be verified by third parties and cited publicly.

Primary outputs:

- OpenClaw case-study report (`openclaw-2026`)
- AI tool sprawl flagship report (`ai-tool-sprawl-q1-2026`)

## Non-Negotiable Standards

1. Reproducibility over rhetoric.
- Every headline claim must map to artifact + deterministic query in `claims/`.

2. Independent research tone.
- No hype language.
- No claims without evidence.
- Explicit limitations and threats-to-validity sections are mandatory.

3. Deterministic first.
- Treat deterministic baseline as canonical.
- Enrich-derived claims require explicit provenance (`as_of`, source) and separate labeling.

4. No production risk.
- OpenClaw execution must occur in isolated containerized lab conditions only.
- Never use production credentials, customer data, or unrestricted side effects.

5. Publish gates are hard gates.
- A report does not publish unless validation and claim/threshold checks pass.

## Canonical Control Files

- Strategic context: `internal/WHY.md`
- OpenClaw definitions: `reports/openclaw-2026/definitions.md`
- OpenClaw protocol: `reports/openclaw-2026/study-protocol.md`
- Sprawl definitions: `reports/ai-tool-sprawl-q1-2026/definitions.md`
- Sprawl protocol: `reports/ai-tool-sprawl-q1-2026/study-protocol.md`
- Claim ledgers: `claims/*/claims.json`
- Threshold policy: `pipelines/config/publish-thresholds.json`
- Citation logs: `citations/*.md`

If these files conflict with draft notes, control files win.

## Required Workflow

## A) Before execution

1. Confirm definitions and protocol version.
2. Confirm citation logs exist for timeline/regulatory assertions.
3. Preflight run scaffold with `pipelines/*/run.sh --run-id <id> --dry-run`.
4. Create immutable run scaffold with `pipelines/*/run.sh --run-id <id>` (or `--resume` only for existing IDs).
5. If workload commands are not yet implemented in `pipelines/*/run.sh`, add them before claiming execution results.

## B) During execution

1. Write artifacts to:
- `runs/openclaw/<run_id>/...`
- `runs/tool-sprawl/<run_id>/...`
2. Keep raw and derived outputs separated.
3. Preserve exact policy/config snapshots used in run.

## C) Before manuscript finalization

1. Update claim values in the report claim ledger:
- `claims/openclaw-2026/claims.json` or
- `claims/ai-tool-sprawl-q1-2026/claims.json`
2. Validate:
   - `pipelines/openclaw/validate.sh` or
   - `pipelines/sprawl/validate.sh`
3. For publish readiness:
   - `pipelines/openclaw/validate.sh --run-id <id> --strict` or
   - `pipelines/sprawl/validate.sh --run-id <id> --strict`

## D) Before publication

1. Assemble package:
   - `pipelines/openclaw/publish_pack.sh --run-id <id>` or
   - `pipelines/sprawl/publish_pack.sh --run-id <id>`
2. Ensure bundle hash manifest exists (`bundle.sha256`).
3. Confirm all links and artifact references are real and resolvable.

## Writing Guardrails

- OpenClaw Section 1 is facts-only timeline (max three paragraphs).
- OpenClaw Section 3 is brand-neutral data section (no product messaging).
- Sprawl report follows 10-section canonical structure.
- Gait deep analysis belongs in OpenClaw report; Sprawl references Gait only in recommendations context.

## Change Control

- Do not silently change metric definitions, threshold policy, or schemas.
- If changed:
  - update version marker in definitions/protocol/schema docs
  - rerun affected metrics
  - update claims and cite change in commit message

## Anti-Patterns (Disallowed)

- Backfilling narrative claims without data proof.
- Mixing enriched and deterministic metrics without clear labeling.
- Publishing production-write percentages without configured production-target policy.
- Treating non-`allow` outcomes as executable in governed lane logic.
- Omitting limitations to make results look stronger.
