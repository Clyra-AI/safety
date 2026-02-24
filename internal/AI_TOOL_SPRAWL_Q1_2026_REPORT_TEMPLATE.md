# Clyra AI Safety Initiative
# Report Template: "The State of AI Tool Sprawl, Q1 2026"

Document status: Draft template  
Target length: 20-25 pages including appendix tables  
Primary audience: CISOs, AppSec, GRC leaders, analysts, trade/business press  
Methodology engine: Wrkr OSS deterministic campaign pipeline

## 0) Publication Controls

- Report ID: `ai-tool-sprawl-q1-2026`
- Planned publish date: `TBD`
- Campaign run ID: `TBD` (immutable once set)
- Mandatory hero metric:
  - `Unapproved-to-approved AI tool ratio per organization`
- Secondary headline metrics:
  - `Average unknown/untracked AI tools per organization`
  - `% orgs with production-write AI exposure (only when policy configured)`
  - `% orgs with Article 15 transparency gaps`
- Canonical claims ledger: `claims/ai-tool-sprawl-q1-2026/claims.json`

## 1) Core Thesis and Messaging Stack

Core thesis: AI governance gaps are measurable now, not hypothetical future risk.

Primary message: `TBD headline number` is the average unknown/unapproved AI tooling burden observed across the sample.

Secondary message: For every one approved AI tool, organizations run a larger set of unapproved AI tools.

Tertiary message: EU AI Act enforcement starts August 2, 2026; many organizations cannot yet prove AI system transparency obligations.

## 2) Scope and Non-Negotiables

- Structure must follow the 10 sections below.
- Headline metrics must come from deterministic campaign artifacts.
- Any enrich-derived claims must include explicit `as_of` provenance.
- No production-write percentages unless production-target policy is configured.
- Gait appears only as a recommendation reference (no deep analysis section).

## 3) Required Evidence Inputs

- Campaign aggregate:
  - `runs/tool-sprawl/<run_id>/agg/campaign-summary.json`
  - `runs/tool-sprawl/<run_id>/agg/campaign-public.md`
- Appendix matrices:
  - `runs/tool-sprawl/<run_id>/appendix/combined-appendix.json`
  - CSV exports under `runs/tool-sprawl/<run_id>/appendix/...`
- Methodology metadata:
  - scan window, sample definition, Wrkr version, detector coverage
- Anonymized case-study rows from appendix exports

If a section claim cannot be tied to an artifact and query, delete the claim.

## 4) End-State Report Structure (10 Sections)

## Section 1: Headline findings

Goal: one-page opening with 3-5 standalone numbers.

Template:

| Headline stat | Value | Artifact source | Query |
|---|---:|---|---|
| AI tools discovered across sample | TBD | `...` | `...` |
| Unapproved-to-approved ratio | TBD | `...` | `...` |
| Orgs with transparency gap (Article 15) | TBD | `...` | `...` |
| Additional high-signal stat | TBD | `...` | `...` |

Narrative constraints:
- No caveats on this page.
- Numbers first, methods deferred to Section 2.

## Section 2: Methodology

Goal: reproducible, concise, and technically defensible.

Include:
- What was scanned (org/repo counts, scope).
- Detector classes and boundaries.
- Deterministic baseline vs optional enrich mode separation.
- Data handling and anonymization policy.
- Reproduction command sequence.

Template:

- Sample definition: `TBD`
- Scan window: `TBD`
- Wrkr version: `TBD`
- Command set: `TBD`
- Limitations and exclusions: `TBD`
- Threats to validity (required): `TBD`

## Section 3: AI tool inventory breakdown

Goal: category-level intelligence behind headline totals.

Categories to include:
- AI coding assistants
- Agent frameworks
- MCP servers/integrations
- Plugins/extensions and CI agents
- API/model provider integrations
- Custom/internal wrappers

Template table:

| Category | Count | % org prevalence | Most common tools | Notable unexpected findings |
|---|---:|---:|---|---|
| TBD | TBD | TBD | TBD | TBD |

## Section 4: Privilege and access map

Goal: convert inventory into operational risk.

Severity bands:
- CRITICAL
- HIGH
- MEDIUM
- LOW

Template table:

| Risk tier | Tool count | Typical capability pattern | Business impact summary |
|---|---:|---|---|
| CRITICAL | TBD | TBD | TBD |
| HIGH | TBD | TBD | TBD |
| MEDIUM | TBD | TBD | TBD |
| LOW | TBD | TBD | TBD |

## Section 5: The approval gap

Goal: quantify governance mismatch between approved and deployed tools.

Required outputs:
- approved / unapproved / unknown counts
- unapproved-to-approved ratio (primary report number)
- adoption pattern signal (org-wide vs team vs one-off)

Template table:

| Classification | Count | % of tools | Notes |
|---|---:|---:|---|
| Approved | TBD | TBD | TBD |
| Unapproved | TBD | TBD | TBD |
| Unknown | TBD | TBD | TBD |

Key ratio:

- `Unapproved-to-approved ratio = TBD`

## Section 6: Regulatory exposure analysis

Goal: map findings to concrete compliance deadlines and control gaps.

Required coverage:
- EU AI Act Articles 9, 12, 14, 15
- SOC 2 AI-relevant controls
- Colorado AI Act
- Texas TRAIGA
- NIST AI RMF alignment

Template table:

| Regulation | Control / Article | Gap prevalence | Evidence basis |
|---|---|---:|---|
| EU AI Act | Article 15 (Transparency) | TBD | TBD |
| EU AI Act | Article 12 (Record Keeping) | TBD | TBD |
| TBD | TBD | TBD | TBD |

## Section 7: Case studies (anonymized)

Goal: 3-5 concrete narratives grounded in exported evidence.

Per-case structure (200-300 words each):
- Org profile (anonymized)
- What was discovered
- Why it matters
- Corrective action path

Case slots:
- Case 1: `TBD`
- Case 2: `TBD`
- Case 3: `TBD`
- Optional Case 4: `TBD`
- Optional Case 5: `TBD`

## Section 8: Benchmarks and comparisons

Goal: position AI tool sprawl as a known infrastructure governance pattern.

Comparators:
- cloud sprawl era
- container sprawl era
- SaaS sprawl baseline
- segment breakdown (industry/size) where defensible

Template:

| Benchmark frame | Current finding | Comparison signal | Interpretation |
|---|---|---|---|
| Cloud sprawl analogue | TBD | TBD | TBD |
| Container sprawl analogue | TBD | TBD | TBD |
| SaaS sprawl analogue | TBD | TBD | TBD |

## Section 9: Recommendations

Goal: practical actions, not marketing copy.

Use max seven recommendations:
1. Inventory first.
2. Classify by privilege, not tool brand.
3. Continuous scanning and drift gates.
4. Early regulatory mapping.
5. Least-privilege at tool boundary.
6. Evidence trails by default.
7. Integrate with AppSec/GRC workflows.

Closing line template:

`The Wrkr open source scanner used for this report is available at https://github.com/Clyra-AI/wrkr.`

Reference note (single paragraph only):

`Tool-boundary enforcement is the natural response to high-privilege findings; Gait is the open-source implementation reference: https://github.com/Clyra-AI/gait.`

## Section 10: Appendix (full data tables)

Goal: make report citable and independently analyzable.

Required tables:
- inventory rows
- privilege rows
- approval-gap rows
- regulatory rows
- prompt-channel rows (if present)
- attack-path rows (if present)
- enrich MCP rows with provenance (if used)

Template index:

| Table | File | Schema version |
|---|---|---|
| Inventory | `...` | `v1` |
| Privilege map | `...` | `v1` |
| Approval gap | `...` | `v1` |
| Regulatory matrix | `...` | `v1` |

## 5) Asset Package Checklist

- Report PDF (`reports/ai-tool-sprawl-q1-2026/report.pdf`)
- Executive summary PDF (`reports/ai-tool-sprawl-q1-2026/executive-summary.pdf`)
- Methodology one-pager
- Full anonymized dataset (CSV/JSON)
- 5-7 social stat graphics
- EU AI Act readiness checklist (one page)

## 6) Quality Gate Before Publish

- Hero number is strong enough to anchor coverage.
- All headline claims pass artifact + query validation.
- Anonymization checks pass.
- Determinism rerun check passes for baseline aggregate.
- Any enrich claims include source + `as_of` timestamp.
