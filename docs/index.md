# Centre for AI Security and Integrity

Independent research and field notes for teams rolling out AI coding agents,
MCP tools, CI/CD automation, approval controls, and audit evidence.

CAISI stands for the Centre for AI Security and Integrity. It publishes open
research and operator field notes on governing AI-assisted software delivery.

Core question:

> Your team is rolling out coding agents. Security is asking what they can touch.

Near-term operating goal:

> Adopt AI coding tools without losing visibility, review discipline, or proof.

## Practical rollout questions

- We are rolling out coding agents and security is nervous.
- AI-assisted output is rising faster than review capacity.
- We need audit evidence for AI-assisted SDLC.
- We do not know what agents, MCP tools, CI jobs, or tokens can reach.
- We need to approve risky actions, not every prompt.
- We do not want long-lived credentials in agent workflows.

CAISI translates those questions into action paths: actor, owner, repo,
workflow, credential, action, target, review or approval rule, and proof.

## Start with the artifact

- [Rolling out coding agents? Start with security review](./rolling-out-coding-agents-security-review/) - map action authority, credentials, MCP/tool reach, CI/CD actions, approvals, and proof.
- [Audit evidence for AI-assisted SDLC](./audit-evidence-ai-assisted-sdlc/) - define a proof packet for actor, owner, credential, action, target, approval, validation, and outcome.
- [Approve actions, not prompts](./approve-actions-not-prompts/) - classify actions as allowed, approval-required, or blocked at the execution boundary.
- [Agent Action BOM](./agent-action-bom/) - map actor, owner, repo, workflow, credential, reachable actions, targets, approval, and proof.
- [MCP tool risk in AI engineering workflows](./mcp-tool-risk-ai-engineering-workflows/) - map tool reach, invocation context, credentials, approval triggers, and proof.
- [Long-lived credentials in AI agent workflows](./long-lived-credentials-ai-agent-workflows/) - reduce standing-token risk across agents, CI/CD, tools, and release paths.
- [Secure AI coding agents in CI/CD](./secure-ai-coding-agents-ci-cd/) - practical controls for PRs, GitHub Actions, CI/CD, credentials, MCP/tool calls, approvals, and release paths.
- [Field note: suggestions are becoming actions](./blog/ai-coding-agents-from-suggestions-to-actions/) - why the missing artifact is an Agent Action BOM.

## Start by role

- [AppSec](./roles/#appsec) - runtime control evidence, approval, and proof.
- [CISO / Security leadership](./roles/#ciso) - approval posture, risk ownership, auditability, evidence quality, and governance reporting.
- [Engineering / Platform](./roles/#engineering-platform) - standards, CI/CD, workflow design, developer adoption, and delivery control.

## Reports

- [OpenClaw 2026](./openclaw-2026/) - release candidate, PDF and artifacts available.
- [AI Tool and Agent Sprawl 2026](./ai-tool-sprawl-v2-2026/) - published locked-cohort report, PDF and artifacts available.

## Quick links

- [OpenClaw report PDF](./assets/reports/openclaw-2026/report.pdf)
- [AI Tool and Agent Sprawl 2026 PDF](./assets/reports/ai-tool-sprawl-v2-2026/report.pdf)
- [OpenClaw artifacts](https://github.com/Clyra-AI/safety/tree/main/reports/openclaw-2026)
- [AI Tool and Agent Sprawl artifacts](https://github.com/Clyra-AI/safety/tree/main/runs/tool-sprawl/sprawl-v2-top250-20260508a)
