# Clyra AI Safety Initiative
# Report Template: "1.5 Million Agents, Zero Governance" (OpenClaw Case Study)

Document status: Draft template  
Target length: 8-10 pages including data tables  
Primary audience: security leaders, engineering leaders, trade press, analysts  
Publishing model: reproducible research artifact (report + data + methodology + configs)

## 0) Publication Controls

- Report ID: `openclaw-2026`
- Planned publish date: `TBD`
- Run ID: `TBD` (immutable once set)
- Primary headline claim:
  - `TBD policy-violating tool calls in 24h`
- Secondary headline claims:
  - `TBD total tool calls attempted in 24h`
  - `TBD sensitive-access actions without approval path (ungoverned baseline)`
  - `TBD governed distribution: allow / block / require_approval`
- Canonical claims ledger: `claims/openclaw-2026/claims.json`

## 1) Core Thesis and Messaging Stack

Core thesis: The largest consumer AI agent deployment in history had no inventory, no policy enforcement, no evidence trail, and no granular control. The fallback was a kill switch.

Primary message: If your only governance option is "shut everything down," you do not have governance.

Secondary message: In a controlled 24-hour run, OpenClaw agents attempted measurable tool actions, including policy-violating and sensitive-access behavior without approval controls.

Tertiary message: Under tool-boundary enforcement, the same action stream produced signed evidence and deterministic decisions. The difference is control infrastructure, not model intelligence.

## 2) Scope and Non-Negotiables

- Use only reproducible findings from committed artifacts.
- Do not include Axym content.
- Do not include Agnt content.
- Do not include speculative "what-if" modeling.
- Keep Section 3 brand-neutral (data only, no Clyra product messaging).
- Closing must be one line linking Wrkr and Gait OSS repos.

## 3) Required Evidence Inputs

- `reports/openclaw-2026/container-config/` (exact runtime setup)
- `reports/openclaw-2026/data/ungoverned-24h.json`
- `reports/openclaw-2026/data/governed-24h.json`
- `reports/openclaw-2026/data/wrkr-scan-output.json`
- `runs/openclaw/<run_id>/...` raw + derived artifacts
- Signed verification outputs from governed run (pack/trace verification artifacts)

If any headline number cannot be traced to an artifact and deterministic query, remove it.

## 4) End-State Report Structure

## Section 1: What happened (timeline only)

Goal: establish factual context without editorializing.

Hard constraints:
- Maximum three paragraphs.
- Include timeline facts only.

Required facts to cover:
- OpenClaw rise and adoption scale.
- Shutdown/control event sequence.
- API cutoff and downstream ecosystem impact.
- Scam hijack and market manipulation episode.

Template content:

1. Paragraph 1 (rise): `TBD`
2. Paragraph 2 (incident chain): `TBD`
3. Paragraph 3 (shutdown and implications): `TBD`

Timeline table:

| Date | Event | Verifiable source link |
|---|---|---|
| TBD | TBD | TBD |

## Section 2: What we tested (methodology)

Goal: make replication straightforward for technical readers and journalists.

Include:
- Container configuration summary.
- 24-hour test harness definition.
- Measurement definitions.
- Reproduction command set.
- Limits and exclusions.

Template blocks:

- Test environment: `TBD`
- Workload profile: `TBD`
- Measured metrics: `TBD`
- Reproduction commands:
  - `TBD`
- Validation checks:
  - `TBD`
- Threats to validity (required):
  - `TBD`

## Section 3: Ungoverned behavior (raw baseline)

Goal: present ungoverned results without product framing.

Required outputs:
- Total tool calls.
- Breakdown by action type:
  - data access
  - external API/network actions
  - messaging actions
  - financial actions
- Count and examples of enterprise-policy violations.
- Sensitive data access events with no approval mechanism.

Core table template:

| Metric | Value | Artifact source | Query |
|---|---|---|---|
| Total tool calls (24h) | TBD | `...` | `...` |
| Policy-violating calls | TBD | `...` | `...` |
| Sensitive access calls without approval path | TBD | `...` | `...` |

Action-type breakdown template:

| Action type | Count | % of total | Policy-violation subset |
|---|---|---|---|
| Data access | TBD | TBD | TBD |
| External API/network | TBD | TBD | TBD |
| Messaging | TBD | TBD | TBD |
| Financial | TBD | TBD | TBD |

## Section 4: Governed behavior (same workload under Gait enforcement)

Goal: show deterministic decisioning and evidence production.

Required outputs:
- Attempted vs approved vs blocked vs require_approval.
- Block reasons by explicit policy rule/reason code.
- Signed evidence summary (packs/traces verified).
- Side-by-side comparison with Section 3.

Comparison table template:

| Metric | Ungoverned | Governed | Delta |
|---|---:|---:|---:|
| Total calls | TBD | TBD | TBD |
| Approved | TBD | TBD | TBD |
| Blocked | TBD | TBD | TBD |
| Require approval | TBD | TBD | TBD |
| Signed evidence artifacts | 0 | TBD | TBD |

Policy reason-code table template:

| Reason code | Count | Rule intent |
|---|---:|---|
| TBD | TBD | TBD |

## Section 5: Wrkr discovery scan (pre-test posture)

Goal: prove inventory and permission visibility should precede deployment.

Include:
- What was discovered in the OpenClaw environment.
- Permission and connectivity surface.
- High-risk inventory findings that should trigger pre-deployment review.

Template table:

| Category | Count | High-risk subset | Notes |
|---|---:|---:|---|
| Detected AI tools | TBD | TBD | TBD |
| Write-capable tools | TBD | TBD | TBD |
| Credential/integration touchpoints | TBD | TBD | TBD |

## Section 6: Five lessons (industry-only language)

Goal: extract durable governance lessons without product branding.

Use exactly five lessons:
1. Inventory before scale.
2. Tool-boundary privilege scoping.
3. Evidence infrastructure before incidents.
4. Cryptographic identity for agents and approvals.
5. Kill switch is failure mode, not governance mode.

Each lesson template:
- Observation: `TBD`
- Evidence from this run: `TBD`
- Action implication: `TBD`

Methodological limitations paragraph (required): `TBD`

## Closing line (single sentence)

Template:

`The tools used in this analysis are open source: Wrkr (https://github.com/Clyra-AI/wrkr) and Gait (https://github.com/Clyra-AI/gait).`

## 5) Asset Package Checklist

- Report PDF (`reports/openclaw-2026/report.pdf`)
- One-page methodology brief (`reports/openclaw-2026/methodology-one-pager.md` or PDF)
- Container config and reproduction guide (`reports/openclaw-2026/container-config/`)
- Raw data bundle (ungoverned vs governed; JSON/CSV)
- Wrkr scan artifact as standalone download
- 3-5 social stat graphics (`reports/openclaw-2026/assets/headline-stats/`)

## 6) Quality Gate Before Publish

- Headline number is strong enough for standalone coverage.
- Every claim links to artifact + deterministic query.
- Independent rerun reproduces headline metrics.
- No non-reproducible statement remains in manuscript.
