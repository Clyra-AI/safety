#!/usr/bin/env python3
"""Generate an enterprise-relevant public GitHub target set for Wrkr sprawl scans."""

from __future__ import annotations

import argparse
import csv
import json
import math
import os
import re
import subprocess
import sys
import time
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.parse import quote


COHORT_QUOTAS = {
    "ai_agent": 85,
    "dev_platform": 85,
    "security_automation": 80,
}

QUERY_GROUPS = {
    "ai_agent": [
        "topic:ai-agent stars:>=25",
        "topic:mcp-server stars:>=25",
        "topic:model-context-protocol stars:>=25",
        "topic:llmops stars:>=25",
        "topic:agent-framework stars:>=25",
        "topic:ai-coding stars:>=25",
        "topic:autonomous-agents stars:>=25",
        "mcp server in:name,description stars:>=50",
        "claude code in:name,description stars:>=50",
        "coding agent in:name,description stars:>=50",
    ],
    "dev_platform": [
        "topic:platform-engineering stars:>=100",
        "topic:developer-tools stars:>=500",
        "topic:devops stars:>=500",
        "topic:ci-cd stars:>=250",
        "topic:gitops stars:>=250",
        "topic:kubernetes stars:>=500",
        "topic:terraform stars:>=500",
        "topic:infrastructure-as-code stars:>=250",
        "topic:observability stars:>=500",
        "topic:opentelemetry stars:>=250",
        "topic:backstage stars:>=50",
        "topic:workflow-automation stars:>=100",
    ],
    "security_automation": [
        "topic:application-security stars:>=100",
        "topic:security-tools stars:>=250",
        "topic:security-automation stars:>=100",
        "topic:devsecops stars:>=100",
        "topic:cloud-security stars:>=100",
        "topic:supply-chain-security stars:>=100",
        "topic:secrets-detection stars:>=50",
        "topic:vulnerability-scanner stars:>=100",
        "topic:sast stars:>=100",
        "topic:sbom stars:>=100",
        "topic:policy-as-code stars:>=50",
        "topic:identity-management stars:>=100",
    ],
}

EXCLUDE_NAME_RE = re.compile(
    r"(^|[-_/])(awesome|learn|tutorial|course|example|examples|demo|demos|"
    r"benchmark|benchmarks|paper|papers|slides|workshop|starter|template|templates|"
    r"sample|samples|prompt-pack|prompts|everything|guide|guidelines|book|books|resources|"
    r"collection|collections|cheatsheet|roadmap|handbook|interview)([-_/]|$)",
    re.IGNORECASE,
)

LOW_RESEARCH_VALUE_RE = re.compile(
    r"(dictatorship|censorship|propaganda|politics|political|anime|vtuber|"
    r"bilibili|news collection|reading list|awesome list|awesome-list|job interview|leetcode|"
    r"course notes|study notes|university notes|learning paths?|ultimate .*library)",
    re.IGNORECASE,
)

ENTERPRISE_ORG_BOOST = {
    "microsoft",
    "google",
    "aws",
    "aws-samples",
    "azure",
    "github",
    "gitlabhq",
    "hashicorp",
    "kubernetes",
    "kubernetes-sigs",
    "argoproj",
    "istio",
    "envoyproxy",
    "prometheus",
    "grafana",
    "elastic",
    "opensearch-project",
    "datadog",
    "cloudflare",
    "backstage",
    "open-telemetry",
    "jenkinsci",
    "tektoncd",
    "fluxcd",
    "helm",
    "ansible",
    "pulumi",
    "crossplane",
    "trufflesecurity",
    "gitguardian",
    "aquasecurity",
    "anchore",
    "dependencytrack",
    "ossf",
    "sigstore",
    "open-policy-agent",
    "cncf",
    "snyk",
    "semgrep",
    "zaproxy",
    "owasp",
    "cisa",
    "cisagov",
    "authzed",
    "keycloak",
    "ory",
    "openai",
    "anthropics",
    "modelcontextprotocol",
    "langchain-ai",
    "langgenius",
    "continuedev",
}

SECURITY_TERMS = {
    "security",
    "appsec",
    "devsecops",
    "sast",
    "dast",
    "secrets",
    "vulnerability",
    "cve",
    "sbom",
    "supply-chain",
    "supply chain",
    "policy",
    "opa",
    "identity",
    "iam",
    "compliance",
    "audit",
    "threat",
    "scanner",
    "malware",
}

AI_TERMS = {
    "ai-agent",
    "agent",
    "agents",
    "mcp",
    "model-context-protocol",
    "llm",
    "llmops",
    "claude",
    "codex",
    "copilot",
    "cursor",
    "autonomous",
    "agentic",
}

AUTOMATION_TERMS = {
    "ci",
    "cd",
    "deploy",
    "deployment",
    "release",
    "workflow",
    "actions",
    "runner",
    "gitops",
    "kubernetes",
    "terraform",
    "pulumi",
    "ansible",
    "cloud",
    "iac",
    "bot",
    "automation",
    "mcp",
}

ENTERPRISE_TERMS = {
    "platform",
    "developer-tools",
    "devops",
    "observability",
    "opentelemetry",
    "kubernetes",
    "terraform",
    "gitops",
    "identity",
    "security",
    "supply-chain",
    "policy",
    "mcp",
    "agent",
}


@dataclass
class Candidate:
    full_name: str
    owner: str
    name: str
    html_url: str
    description: str
    stars: int
    forks: int
    size: int
    pushed_at: str
    updated_at: str
    language: str
    topics: list[str]
    cohorts: set[str] = field(default_factory=set)
    query_ids: set[str] = field(default_factory=set)
    score: float = 0.0
    score_breakdown: dict[str, float] = field(default_factory=dict)
    primary_cohort: str = ""


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--total", type=int, default=250)
    parser.add_argument("--output", required=True)
    parser.add_argument("--catalog", required=True)
    parser.add_argument("--min-pushed", default="2025-01-01")
    parser.add_argument("--max-size-kb", type=int, default=300000)
    parser.add_argument("--pages", type=int, default=3)
    parser.add_argument("--per-page", type=int, default=100)
    parser.add_argument("--max-per-owner", type=int, default=1)
    parser.add_argument("--exclude-file", action="append", default=[])
    parser.add_argument("--sleep-sec", type=float, default=2.0)
    return parser.parse_args()


def run_gh_search(query: str, page: int, per_page: int) -> dict[str, Any]:
    encoded = quote(query, safe="")
    path = f"/search/repositories?q={encoded}&sort=stars&order=desc&per_page={per_page}&page={page}"
    cmd = ["gh", "api", "-H", "Accept: application/vnd.github+json", path]
    for attempt in range(5):
        proc = subprocess.run(cmd, text=True, capture_output=True)
        if proc.returncode == 0:
            return json.loads(proc.stdout)
        stderr = proc.stderr.lower()
        if "rate limit" in stderr or "secondary rate" in stderr:
            time.sleep(30 + attempt * 15)
            continue
        if "validation failed" in stderr:
            return {"items": []}
        if attempt == 4:
            raise RuntimeError(f"gh api failed for query={query!r}: {proc.stderr.strip()}")
        time.sleep(5 + attempt * 5)
    return {"items": []}


def words(candidate: Candidate) -> set[str]:
    joined = " ".join(
        [
            candidate.full_name,
            candidate.description,
            candidate.language,
            " ".join(candidate.topics),
        ]
    ).lower()
    tokens = set(re.split(r"[^a-z0-9+.-]+", joined))
    tokens.update(t.lower() for t in candidate.topics)
    if "supply" in tokens and "chain" in tokens:
        tokens.add("supply chain")
    return tokens


def term_score(tokens: set[str], terms: set[str], max_score: float) -> float:
    hits = sum(1 for term in terms if term in tokens)
    return min(max_score, hits * (max_score / 4.0))


def recency_score(pushed_at: str) -> float:
    try:
        pushed = datetime.fromisoformat(pushed_at.replace("Z", "+00:00"))
    except ValueError:
        return 0.0
    age_days = (datetime.now(timezone.utc) - pushed).days
    if age_days <= 30:
        return 10.0
    if age_days <= 90:
        return 8.0
    if age_days <= 180:
        return 6.0
    if age_days <= 365:
        return 4.0
    return 1.0


def compute_score(candidate: Candidate) -> None:
    tokens = words(candidate)
    adoption = min(18.0, math.log10(max(candidate.stars, 1) + 1) * 5.0)
    forks = min(8.0, math.log10(max(candidate.forks, 1) + 1) * 3.0)
    enterprise = term_score(tokens, ENTERPRISE_TERMS, 20.0)
    security = term_score(tokens, SECURITY_TERMS, 20.0)
    ai = term_score(tokens, AI_TERMS, 15.0)
    automation = term_score(tokens, AUTOMATION_TERMS, 15.0)
    recency = recency_score(candidate.pushed_at)
    source = 5.0 if candidate.owner.lower() in ENTERPRISE_ORG_BOOST else 0.0
    multi_surface = min(10.0, len(candidate.cohorts) * 3.0)
    size_penalty = 0.0
    if candidate.size > 200000:
        size_penalty = min(8.0, (candidate.size - 200000) / 25000)

    candidate.score_breakdown = {
        "adoption": round(adoption, 2),
        "forks": round(forks, 2),
        "enterprise_control_plane": round(enterprise, 2),
        "security_appsec": round(security, 2),
        "ai_agent_surface": round(ai, 2),
        "automation_write_path": round(automation, 2),
        "recency": round(recency, 2),
        "enterprise_source": round(source, 2),
        "multi_surface": round(multi_surface, 2),
        "size_penalty": round(size_penalty, 2),
    }
    candidate.score = round(sum(candidate.score_breakdown.values()) - size_penalty, 2)
    cohort_scores = {
        "security_automation": security + automation,
        "ai_agent": ai + automation,
        "dev_platform": enterprise + automation,
    }
    candidate.primary_cohort = max(cohort_scores, key=cohort_scores.get)


def excluded(item: dict[str, Any], min_pushed: str, max_size_kb: int, explicit_excludes: set[str]) -> bool:
    full_name = str(item.get("full_name", ""))
    name = str(item.get("name", ""))
    description = str(item.get("description") or "")
    topics = " ".join(str(topic) for topic in (item.get("topics") or []))
    searchable = " ".join([full_name, name, description, topics])
    if full_name.lower() in explicit_excludes:
        return True
    if item.get("archived") or item.get("fork"):
        return True
    if str(item.get("pushed_at", "")) < min_pushed:
        return True
    if int(item.get("size") or 0) > max_size_kb:
        return True
    if EXCLUDE_NAME_RE.search(name) or EXCLUDE_NAME_RE.search(full_name) or EXCLUDE_NAME_RE.search(description):
        return True
    if LOW_RESEARCH_VALUE_RE.search(searchable):
        return True
    return False


def load_excludes(paths: list[str]) -> set[str]:
    out: set[str] = set()
    for raw in paths:
        path = Path(raw)
        if not path.exists():
            continue
        for line in path.read_text().splitlines():
            line = line.split("#", 1)[0].strip()
            if line:
                out.add(line.lower())
    return out


def item_to_candidate(item: dict[str, Any]) -> Candidate:
    owner = item.get("owner") or {}
    return Candidate(
        full_name=str(item.get("full_name", "")),
        owner=str(owner.get("login", "")),
        name=str(item.get("name", "")),
        html_url=str(item.get("html_url", "")),
        description=str(item.get("description") or ""),
        stars=int(item.get("stargazers_count") or 0),
        forks=int(item.get("forks_count") or 0),
        size=int(item.get("size") or 0),
        pushed_at=str(item.get("pushed_at", "")),
        updated_at=str(item.get("updated_at", "")),
        language=str(item.get("language") or ""),
        topics=list(item.get("topics") or []),
    )


def select_candidates(candidates: dict[str, Candidate], total: int, max_per_owner: int) -> list[Candidate]:
    selected: list[Candidate] = []
    owner_counts: dict[str, int] = {}
    selected_names: set[str] = set()

    def can_take(candidate: Candidate) -> bool:
        if candidate.full_name in selected_names:
            return False
        return owner_counts.get(candidate.owner.lower(), 0) < max_per_owner

    def take(candidate: Candidate) -> None:
        selected.append(candidate)
        selected_names.add(candidate.full_name)
        owner_key = candidate.owner.lower()
        owner_counts[owner_key] = owner_counts.get(owner_key, 0) + 1

    ranked = sorted(candidates.values(), key=lambda c: (-c.score, -c.stars, c.full_name.lower()))
    for cohort, quota in COHORT_QUOTAS.items():
        cohort_ranked = [c for c in ranked if c.primary_cohort == cohort or cohort in c.cohorts]
        for candidate in cohort_ranked:
            if len([c for c in selected if c.primary_cohort == cohort or cohort in c.cohorts]) >= quota:
                break
            if can_take(candidate):
                take(candidate)
            if len(selected) >= total:
                return selected

    for candidate in ranked:
        if len(selected) >= total:
            break
        if can_take(candidate):
            take(candidate)
    return selected


def main() -> int:
    args = parse_args()
    if args.total <= 0:
        raise SystemExit("--total must be positive")
    if args.per_page < 1 or args.per_page > 100:
        raise SystemExit("--per-page must be 1..100")
    if not shutil_which("gh"):
        raise SystemExit("gh CLI is required for authenticated GitHub Search API access")

    explicit_excludes = load_excludes(args.exclude_file)
    candidates: dict[str, Candidate] = {}

    for cohort, queries in QUERY_GROUPS.items():
        for query_index, base_query in enumerate(queries, start=1):
            query_id = f"{cohort}:{query_index}"
            query = f"{base_query} pushed:>={args.min_pushed} archived:false fork:false size:<{args.max_size_kb}"
            print(f"[enterprise-targets] query={query_id} {query}", file=sys.stderr)
            for page in range(1, args.pages + 1):
                payload = run_gh_search(query, page, args.per_page)
                items = payload.get("items") or []
                if not items:
                    break
                for item in items:
                    if excluded(item, args.min_pushed, args.max_size_kb, explicit_excludes):
                        continue
                    full_name = str(item.get("full_name", ""))
                    if not full_name:
                        continue
                    candidate = candidates.get(full_name)
                    if candidate is None:
                        candidate = item_to_candidate(item)
                        candidates[full_name] = candidate
                    candidate.cohorts.add(cohort)
                    candidate.query_ids.add(query_id)
                time.sleep(args.sleep_sec)

    for candidate in candidates.values():
        compute_score(candidate)

    selected = select_candidates(candidates, args.total, args.max_per_owner)
    if len(selected) < args.total:
        raise SystemExit(f"selected only {len(selected)} targets; need {args.total}")

    output_path = Path(args.output)
    catalog_path = Path(args.catalog)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    catalog_path.parent.mkdir(parents=True, exist_ok=True)

    generated_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    output_path.write_text(
        "\n".join(
            [
                "# Enterprise-relevant Wrkr scan target list.",
                f"# Generated at: {generated_at}",
                f"# total={args.total} min_pushed={args.min_pushed} max_size_kb={args.max_size_kb} max_per_owner={args.max_per_owner}",
                "# rubric=internal/enterprise_target_selection_rubric.md",
                *[candidate.full_name for candidate in selected],
                "",
            ]
        )
    )

    with catalog_path.open("w", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "rank",
                "full_name",
                "primary_cohort",
                "cohorts",
                "enterprise_score",
                "score_breakdown_json",
                "owner",
                "name",
                "stars",
                "forks",
                "size_kb",
                "pushed_at",
                "updated_at",
                "language",
                "topics",
                "query_ids",
                "url",
                "description",
            ],
        )
        writer.writeheader()
        for rank, candidate in enumerate(selected, start=1):
            writer.writerow(
                {
                    "rank": rank,
                    "full_name": candidate.full_name,
                    "primary_cohort": candidate.primary_cohort,
                    "cohorts": "|".join(sorted(candidate.cohorts)),
                    "enterprise_score": candidate.score,
                    "score_breakdown_json": json.dumps(candidate.score_breakdown, sort_keys=True),
                    "owner": candidate.owner,
                    "name": candidate.name,
                    "stars": candidate.stars,
                    "forks": candidate.forks,
                    "size_kb": candidate.size,
                    "pushed_at": candidate.pushed_at,
                    "updated_at": candidate.updated_at,
                    "language": candidate.language,
                    "topics": "|".join(candidate.topics),
                    "query_ids": "|".join(sorted(candidate.query_ids)),
                    "url": candidate.html_url,
                    "description": candidate.description,
                }
            )

    print(f"[enterprise-targets] candidates={len(candidates)} selected={len(selected)}", file=sys.stderr)
    print(f"[enterprise-targets] wrote {output_path}", file=sys.stderr)
    print(f"[enterprise-targets] wrote {catalog_path}", file=sys.stderr)
    return 0


def shutil_which(name: str) -> str | None:
    for item in os.environ.get("PATH", "").split(os.pathsep):
        candidate = Path(item) / name
        if candidate.exists() and os.access(candidate, os.X_OK):
            return str(candidate)
    return None


if __name__ == "__main__":
    raise SystemExit(main())
