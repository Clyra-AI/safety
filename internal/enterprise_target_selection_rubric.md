# Enterprise-Relevant Target Selection Rubric

Purpose: build a reproducible public GitHub target set for measuring AI tooling and agent-governance exposure in repositories that resemble enterprise control surfaces.

This cohort is not intended to represent all open-source repositories. It prioritizes repositories with high research value for CISOs, AppSec leaders, security engineering, and platform teams.

## Selection Objective

Select 250 public `owner/repo` targets that are likely to expose one or more of these enterprise-relevant surfaces:

- AI agent, MCP, coding-agent, LLMOps, or autonomous developer tooling configuration.
- Developer platform, CI/CD, GitOps, infrastructure-as-code, cloud-native, observability, or deployment automation.
- Security automation, AppSec, secrets detection, vulnerability management, SBOM, identity, policy, or supply-chain security.

## Inclusion Rules

- Repository is public, non-archived, and not a fork.
- Repository has recent activity, defaulting to `pushed_at >= 2025-01-01`.
- Repository is not primarily a list, tutorial, toy, benchmark, paper-only artifact, course, prompt pack, or examples collection.
- Repository is not primarily a guide, book, resource collection, news/political repository, academic reading list, or community discussion space.
- Repository is small enough for cloned deterministic scanning under the configured run budget.
- Repository owner is not overrepresented. The default selector keeps one repository per owner unless explicitly configured otherwise.

## Scoring Dimensions

Each candidate is scored deterministically from GitHub Search metadata.

1. Enterprise control-plane relevance.
   - Higher score for platform, deployment, IaC, CI/CD, identity, observability, security, supply-chain, MCP, and AI-agent topics.
   - This dimension answers: could a misconfigured agent/tooling path touch software delivery, infrastructure, secrets, or regulated workflow evidence?

2. Security and AppSec relevance.
   - Higher score for repositories related to security automation, SAST, SBOM, secrets, vulnerability management, cloud security, identity, policy, and DevSecOps.
   - This dimension answers: would a CISO or Head of AppSec reasonably care about uncontrolled AI/write paths here?

3. AI and agent surface likelihood.
   - Higher score for MCP, coding agents, LLMOps, AI agents, Copilot/Codex/Claude/Cursor-adjacent configuration, autonomous workflows, and agent orchestration.
   - This dimension answers: is the repository likely to contain the kind of agentic configuration Wrkr is designed to discover?

4. Automation and write-path likelihood.
   - Higher score for deploy, workflow, CI, release, Kubernetes, Terraform, cloud, GitOps, policy, bot, runner, and MCP signals.
   - This dimension answers: could tool discovery plausibly map to action capability rather than documentation-only usage?

5. Public adoption and ecosystem gravity.
   - Higher score for stars and forks using log scaling so very large projects do not dominate the entire cohort.
   - This dimension answers: is this target important enough that a finding would matter beyond a niche repo?

6. Recency.
   - Higher score for repositories pushed recently.
   - This dimension answers: is the target active enough to reflect current engineering practice?

7. Enterprise-source signal.
   - Higher score for known enterprise/open-source platform, cloud, security, identity, AI, and developer-tooling organizations.
   - This is a small boost only. It must not replace the measurable metadata above.

## Cohort Balance

The default 250-target cohort is balanced across:

- AI-agent and MCP surface: 85 targets.
- Developer platform and software-delivery surface: 85 targets.
- Security automation and AppSec surface: 80 targets.

If one bucket does not fill, remaining slots are assigned to the highest-scoring candidates across all buckets while preserving the owner cap and exclusions.

## Interpretation Guardrails

- A target is a public repository, not a full enterprise tenant.
- Public-repo findings should be written as observable governance signals, not claims about the private security posture of the organization.
- Scanner failures are evidence about tool robustness, not measured target posture. Failed targets must be replaced for a clean 250-successful-scan cohort, and failures must remain documented separately.
- Production-write claims remain omitted unless production target policy is intentionally configured for the run.
