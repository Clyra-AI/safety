#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  generate_targets.sh [--total <n>] [--output <path>] [--catalog <path>]
                      [--min-pushed <YYYY-MM-DD>] [--pages <n>] [--per-page <n>]
                      [--ai-weight <0-100>] [--dev-weight <0-100>] [--sec-weight <0-100>]

Builds a reproducible open-source target list for the sprawl campaign.
Outputs:
  - owner/repo list (default: internal/repos.md)
  - selected-candidate catalog CSV (default: internal/repos_candidates.csv)

Notes:
  - Uses GitHub Search API.
  - Keeps one repo per owner (because current sprawl metrics count one line as one org).
  - Excludes archived/fork repos and obvious list/tutorial/example repos.
  - Auth token optional (GH_TOKEN, GITHUB_TOKEN, or WRKR_GITHUB_TOKEN).
USAGE
}

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TOTAL=101
OUTPUT_PATH="internal/repos.md"
CATALOG_PATH="internal/repos_candidates.csv"
MIN_PUSHED="2025-09-01"
PAGES=2
PER_PAGE=100
AI_WEIGHT=50
DEV_WEIGHT=30
SEC_WEIGHT=20

while [[ $# -gt 0 ]]; do
  case "$1" in
    --total)
      TOTAL="${2:-}"
      shift 2
      ;;
    --output)
      OUTPUT_PATH="${2:-}"
      shift 2
      ;;
    --catalog)
      CATALOG_PATH="${2:-}"
      shift 2
      ;;
    --min-pushed)
      MIN_PUSHED="${2:-}"
      shift 2
      ;;
    --pages)
      PAGES="${2:-}"
      shift 2
      ;;
    --per-page)
      PER_PAGE="${2:-}"
      shift 2
      ;;
    --ai-weight)
      AI_WEIGHT="${2:-}"
      shift 2
      ;;
    --dev-weight)
      DEV_WEIGHT="${2:-}"
      shift 2
      ;;
    --sec-weight)
      SEC_WEIGHT="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[sprawl-targets] unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

for n in "${TOTAL}" "${PAGES}" "${PER_PAGE}" "${AI_WEIGHT}" "${DEV_WEIGHT}" "${SEC_WEIGHT}"; do
  if ! [[ "${n}" =~ ^[0-9]+$ ]]; then
    echo "[sprawl-targets] numeric arguments must be integers" >&2
    exit 1
  fi
done
if (( TOTAL <= 0 )); then
  echo "[sprawl-targets] --total must be > 0" >&2
  exit 1
fi
if (( PAGES <= 0 || PER_PAGE <= 0 || PER_PAGE > 100 )); then
  echo "[sprawl-targets] --pages must be > 0 and --per-page must be between 1 and 100" >&2
  exit 1
fi
if (( AI_WEIGHT + DEV_WEIGHT + SEC_WEIGHT != 100 )); then
  echo "[sprawl-targets] weights must sum to 100" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "[sprawl-targets] jq is required" >&2
  exit 1
fi
if ! command -v curl >/dev/null 2>&1; then
  echo "[sprawl-targets] curl is required" >&2
  exit 1
fi

OUTPUT_ABS="${OUTPUT_PATH}"
CATALOG_ABS="${CATALOG_PATH}"
if [[ "${OUTPUT_ABS}" != /* ]]; then
  OUTPUT_ABS="${REPO_ROOT}/${OUTPUT_ABS}"
fi
if [[ "${CATALOG_ABS}" != /* ]]; then
  CATALOG_ABS="${REPO_ROOT}/${CATALOG_ABS}"
fi
mkdir -p "$(dirname "${OUTPUT_ABS}")" "$(dirname "${CATALOG_ABS}")"

TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-${WRKR_GITHUB_TOKEN:-}}}"
USE_GH_API=0
if command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then
    USE_GH_API=1
  fi
fi

AI_QUERIES=(
  "topic:ai-agent pushed:>=${MIN_PUSHED} stars:>=250 archived:false fork:false"
  "topic:model-context-protocol pushed:>=${MIN_PUSHED} stars:>=80 archived:false fork:false"
  "topic:llmops pushed:>=${MIN_PUSHED} stars:>=150 archived:false fork:false"
  "topic:ai-coding-assistant pushed:>=${MIN_PUSHED} stars:>=100 archived:false fork:false"
)
DEV_QUERIES=(
  "topic:devops pushed:>=${MIN_PUSHED} stars:>=7000 -topic:ai -topic:llm -topic:machine-learning archived:false fork:false"
  "topic:cloud-native pushed:>=${MIN_PUSHED} stars:>=7000 -topic:ai -topic:llm archived:false fork:false"
  "topic:developer-tools pushed:>=${MIN_PUSHED} stars:>=7000 -topic:ai -topic:llm archived:false fork:false"
)
SEC_QUERIES=(
  "topic:security-tools pushed:>=${MIN_PUSHED} stars:>=3500 -topic:ai -topic:llm archived:false fork:false"
  "topic:application-security pushed:>=${MIN_PUSHED} stars:>=3000 -topic:ai -topic:llm archived:false fork:false"
  "topic:devsecops pushed:>=${MIN_PUSHED} stars:>=2500 -topic:ai -topic:llm archived:false fork:false"
)

fetch_query() {
  local cohort="$1"
  local query="$2"
  local page encoded url response message
  encoded="$(jq -rn --arg q "${query}" '$q|@uri')"
  for ((page=1; page<=PAGES; page++)); do
    if (( USE_GH_API == 1 )); then
      response="$(gh api "search/repositories?q=${encoded}&sort=stars&order=desc&per_page=${PER_PAGE}&page=${page}")"
    else
      url="https://api.github.com/search/repositories?q=${encoded}&sort=stars&order=desc&per_page=${PER_PAGE}&page=${page}"
      if [[ -n "${TOKEN}" ]]; then
        response="$(curl -sS -L -H "Accept: application/vnd.github+json" -H "Authorization: Bearer ${TOKEN}" "${url}")"
      else
        response="$(curl -sS -L -H "Accept: application/vnd.github+json" "${url}")"
      fi
    fi

    message="$(jq -r '.message // empty' <<<"${response}")"
    if [[ -n "${message}" ]]; then
      if [[ "${message}" == *"rate limit"* ]]; then
        if (( USE_GH_API == 1 )); then
          echo "[sprawl-targets] GitHub API rate limit exceeded for gh auth context." >&2
        else
          echo "[sprawl-targets] GitHub API rate limit exceeded. Set GH_TOKEN or use gh auth and rerun." >&2
        fi
        exit 1
      fi
      echo "[sprawl-targets] warning: query failed (${cohort}, page ${page}): ${message}" >&2
      continue
    fi

    jq -cr \
      --arg cohort "${cohort}" \
      --arg query "${query}" \
      '.items[]? | {
         cohort: $cohort,
         query: $query,
         full_name: .full_name,
         owner: .owner.login,
         name: .name,
         stars: .stargazers_count,
         pushed_at: .pushed_at,
         archived: .archived,
         fork: .fork,
         url: .html_url
       }' <<<"${response}"
  done
}

if (( USE_GH_API == 1 )); then
  echo "[sprawl-targets] source=gh api (authenticated)"
else
  echo "[sprawl-targets] source=curl api (token=${TOKEN:+set}${TOKEN:-unset})"
fi

tmp_raw="$(mktemp)"
tmp_selected_json="$(mktemp)"
trap 'rm -f "${tmp_raw}" "${tmp_selected_json}"' EXIT

for q in "${AI_QUERIES[@]}"; do
  fetch_query "ai_native" "${q}" >> "${tmp_raw}"
done
for q in "${DEV_QUERIES[@]}"; do
  fetch_query "dev_platform" "${q}" >> "${tmp_raw}"
done
for q in "${SEC_QUERIES[@]}"; do
  fetch_query "security_platform" "${q}" >> "${tmp_raw}"
done

ai_quota=$((TOTAL * AI_WEIGHT / 100))
dev_quota=$((TOTAL * DEV_WEIGHT / 100))
sec_quota=$((TOTAL * SEC_WEIGHT / 100))
assigned=$((ai_quota + dev_quota + sec_quota))
remainder=$((TOTAL - assigned))

while (( remainder > 0 )); do
  ai_quota=$((ai_quota + 1))
  remainder=$((remainder - 1))
  (( remainder == 0 )) && break
  dev_quota=$((dev_quota + 1))
  remainder=$((remainder - 1))
  (( remainder == 0 )) && break
  sec_quota=$((sec_quota + 1))
  remainder=$((remainder - 1))
done

jq -cs \
  --argjson total "${TOTAL}" \
  --arg min_pushed "${MIN_PUSHED}" \
  --argjson ai_quota "${ai_quota}" \
  --argjson dev_quota "${dev_quota}" \
  --argjson sec_quota "${sec_quota}" '
  def norm:
    map(select(.full_name != null and .owner != null and .pushed_at != null))
    | map(. + {pushed_ts: (.pushed_at | fromdateiso8601)})
    | map(select(.pushed_at >= ($min_pushed + "T00:00:00Z")))
    | map(select(.archived == false and .fork == false))
    | map(select((.name | ascii_downcase) | test("^(awesome|learn|tutorial|course|example|examples|demo|benchmark|benchmarks)") | not))
    | map(select((.full_name | ascii_downcase) | test("awesome-|/awesome|/learn-|/tutorial|/course|/examples?|/demo|/benchmarks?") | not))
    | sort_by(-.pushed_ts, -.stars, .full_name)
    | group_by(.owner)
    | map(.[0]);

  def pick($all; $cohort; $n):
    ($all | map(select(.cohort == $cohort)) | sort_by(-.pushed_ts, -.stars, .full_name) | .[0:$n]);

  . | norm as $all
  | (pick($all; "ai_native"; $ai_quota)) as $ai
  | (pick($all; "dev_platform"; $dev_quota)) as $dev
  | (pick($all; "security_platform"; $sec_quota)) as $sec
  | ($ai + $dev + $sec) as $seed
  | ($seed | map(.full_name)) as $seed_names
  | ($all | map(select((.full_name as $n | $seed_names | index($n)) | not)) | sort_by(-.pushed_ts, -.stars, .full_name)) as $remaining
  | (
      if ($seed | length) >= $total
      then ($seed[0:$total])
      else ($seed + $remaining[0:($total - ($seed | length))])
      end
    ) as $selected
  | {
      selected: $selected,
      counts: {
        total: ($selected | length),
        ai_native: ($selected | map(select(.cohort=="ai_native")) | length),
        dev_platform: ($selected | map(select(.cohort=="dev_platform")) | length),
        security_platform: ($selected | map(select(.cohort=="security_platform")) | length)
      }
    }' "${tmp_raw}" > "${tmp_selected_json}"

selected_total="$(jq -r '.counts.total' "${tmp_selected_json}")"
if (( selected_total < TOTAL )); then
  echo "[sprawl-targets] insufficient candidates after filters: requested=${TOTAL}, got=${selected_total}" >&2
  exit 1
fi

generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
ai_count="$(jq -r '.counts.ai_native' "${tmp_selected_json}")"
dev_count="$(jq -r '.counts.dev_platform' "${tmp_selected_json}")"
sec_count="$(jq -r '.counts.security_platform' "${tmp_selected_json}")"

{
  echo "# Canonical scan target list for AI Tool Sprawl run."
  echo "# Generated by pipelines/sprawl/generate_targets.sh at ${generated_at}"
  echo "# total=${selected_total} | ai_native=${ai_count} dev_platform=${dev_count} security_platform=${sec_count}"
  echo "# filters: one-repo-per-owner, archived=false, fork=false, pushed>=${MIN_PUSHED}, no obvious list/tutorial/example repos"
  echo
  jq -r '.selected[] | .full_name' "${tmp_selected_json}"
} > "${OUTPUT_ABS}"

jq -r '
  (["cohort","full_name","owner","stars","pushed_at","url","query"] | @csv),
  (.selected[] | [.cohort,.full_name,.owner,(.stars|tostring),.pushed_at,.url,.query] | @csv)
' "${tmp_selected_json}" > "${CATALOG_ABS}"

echo "[sprawl-targets] wrote ${OUTPUT_ABS}"
echo "[sprawl-targets] wrote ${CATALOG_ABS}"
echo "[sprawl-targets] selected=${selected_total} ai=${ai_count} dev=${dev_count} sec=${sec_count}"
