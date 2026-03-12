#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  generate_targets.sh [--total <n>] [--output <path>] [--catalog <path>]
                      [--min-pushed <YYYY-MM-DD>] [--pages <n>] [--per-page <n>]
                      [--ai-weight <0-100>] [--dev-weight <0-100>] [--sec-weight <0-100>]
                      [--max-size-kb <n>] [--selection-profile <v1|v2>] [--http-client <auto|gh|curl>]

Builds a reproducible open-source target list for the sprawl campaign.
Outputs:
  - owner/repo list (default: internal/repos.md)
  - selected-candidate catalog CSV (default: internal/repos_candidates.csv)

Notes:
  - Uses GitHub Search API.
  - Keeps one repo per owner (because current sprawl metrics count one line as one org).
  - Excludes archived/fork repos and obvious list/tutorial/example repos.
  - `v2` expands the AI-native cohort and adds stronger deterministic exclusions for template/docs/prompt-pack style repos.
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
MAX_SIZE_KB="200000"
SELECTION_PROFILE="v1"
HTTP_CLIENT="auto"
AI_WEIGHT_SET=0
DEV_WEIGHT_SET=0
SEC_WEIGHT_SET=0

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
      AI_WEIGHT_SET=1
      shift 2
      ;;
    --dev-weight)
      DEV_WEIGHT="${2:-}"
      DEV_WEIGHT_SET=1
      shift 2
      ;;
    --sec-weight)
      SEC_WEIGHT="${2:-}"
      SEC_WEIGHT_SET=1
      shift 2
      ;;
    --max-size-kb)
      MAX_SIZE_KB="${2:-}"
      shift 2
      ;;
    --selection-profile|--profile)
      SELECTION_PROFILE="${2:-}"
      shift 2
      ;;
    --http-client)
      HTTP_CLIENT="${2:-}"
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

case "${SELECTION_PROFILE}" in
  v1|v2)
    ;;
  *)
    echo "[sprawl-targets] --selection-profile must be one of: v1, v2" >&2
    exit 1
    ;;
esac
case "${HTTP_CLIENT}" in
  auto|gh|curl)
    ;;
  *)
    echo "[sprawl-targets] --http-client must be one of: auto, gh, curl" >&2
    exit 1
    ;;
esac

if [[ "${SELECTION_PROFILE}" == "v2" ]]; then
  if (( AI_WEIGHT_SET == 0 )); then
    AI_WEIGHT=50
  fi
  if (( DEV_WEIGHT_SET == 0 )); then
    DEV_WEIGHT=30
  fi
  if (( SEC_WEIGHT_SET == 0 )); then
    SEC_WEIGHT=20
  fi
fi

for n in "${TOTAL}" "${PAGES}" "${PER_PAGE}" "${AI_WEIGHT}" "${DEV_WEIGHT}" "${SEC_WEIGHT}"; do
  if ! [[ "${n}" =~ ^[0-9]+$ ]]; then
    echo "[sprawl-targets] numeric arguments must be integers" >&2
    exit 1
  fi
done
if [[ -n "${MAX_SIZE_KB}" ]] && ! [[ "${MAX_SIZE_KB}" =~ ^[0-9]+$ ]]; then
  echo "[sprawl-targets] --max-size-kb must be an integer when provided" >&2
  exit 1
fi
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
if [[ "${HTTP_CLIENT}" != "curl" ]] && command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then
    USE_GH_API=1
  fi
fi
if [[ "${HTTP_CLIENT}" == "gh" && "${USE_GH_API}" -eq 0 ]]; then
  echo "[sprawl-targets] --http-client gh requested but gh auth is unavailable" >&2
  exit 1
fi
if [[ "${HTTP_CLIENT}" == "curl" ]]; then
  USE_GH_API=0
fi

case "${SELECTION_PROFILE}" in
  v1)
    AI_QUERIES=(
      "topic:ai-agent pushed:>=${MIN_PUSHED} stars:>=25 archived:false fork:false"
      "topic:model-context-protocol pushed:>=${MIN_PUSHED} stars:>=10 archived:false fork:false"
      "topic:mcp-server pushed:>=${MIN_PUSHED} stars:>=10 archived:false fork:false"
    )
    DEV_QUERIES=(
      "topic:devops pushed:>=${MIN_PUSHED} stars:>=500 -topic:ai -topic:llm -topic:machine-learning archived:false fork:false"
      "topic:cloud-native pushed:>=${MIN_PUSHED} stars:>=500 -topic:ai -topic:llm archived:false fork:false"
      "topic:developer-tools pushed:>=${MIN_PUSHED} stars:>=500 -topic:ai -topic:llm archived:false fork:false"
      "topic:platform-engineering pushed:>=${MIN_PUSHED} stars:>=250 -topic:ai -topic:llm archived:false fork:false"
      "topic:ci-cd pushed:>=${MIN_PUSHED} stars:>=500 -topic:ai -topic:llm archived:false fork:false"
      "topic:observability pushed:>=${MIN_PUSHED} stars:>=500 -topic:ai -topic:llm archived:false fork:false"
    )
    SEC_QUERIES=(
      "topic:security-tools pushed:>=${MIN_PUSHED} stars:>=250 -topic:ai -topic:llm archived:false fork:false"
      "topic:application-security pushed:>=${MIN_PUSHED} stars:>=250 -topic:ai -topic:llm archived:false fork:false"
      "topic:devsecops pushed:>=${MIN_PUSHED} stars:>=250 -topic:ai -topic:llm archived:false fork:false"
      "topic:cloud-security pushed:>=${MIN_PUSHED} stars:>=250 -topic:ai -topic:llm archived:false fork:false"
      "topic:security-automation pushed:>=${MIN_PUSHED} stars:>=100 -topic:ai -topic:llm archived:false fork:false"
      "topic:secrets-detection pushed:>=${MIN_PUSHED} stars:>=100 -topic:ai -topic:llm archived:false fork:false"
    )
    NAME_EXCLUDE_REGEX="^(awesome|learn|tutorial|course|example|examples|demo|benchmark|benchmarks)"
    FULLNAME_EXCLUDE_REGEX="awesome-|/awesome|/learn-|/tutorial|/course|/examples?|/demo|/benchmarks?"
    DESCRIPTION_EXCLUDE_REGEX=""
    FILTERS_DESC="one-repo-per-owner, archived=false, fork=false, pushed>=${MIN_PUSHED}, size<${MAX_SIZE_KB}, no obvious list/tutorial/example repos"
    ;;
  v2)
    AI_QUERIES=(
      "topic:ai-agent pushed:>=${MIN_PUSHED} stars:>=25 archived:false fork:false"
      "topic:model-context-protocol pushed:>=${MIN_PUSHED} stars:>=10 archived:false fork:false"
      "topic:mcp-server pushed:>=${MIN_PUSHED} stars:>=10 archived:false fork:false"
      "topic:multi-agent pushed:>=${MIN_PUSHED} stars:>=10 archived:false fork:false"
      "\"agent framework\" in:name,description,readme pushed:>=${MIN_PUSHED} stars:>=25 archived:false fork:false"
      "\"agent orchestration\" in:name,description,readme pushed:>=${MIN_PUSHED} stars:>=15 archived:false fork:false"
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
    NAME_EXCLUDE_REGEX="(^|[-_])(awesome|learn|tutorial|course|example|examples|demo|benchmark|benchmarks|prompt|prompts|template|templates|boilerplate|starter|starters|scaffold|scaffolds|cookbook|cookbooks|docs|documentation)([-_]|$)"
    FULLNAME_EXCLUDE_REGEX="awesome-|/awesome|/learn-|/tutorial|/course|/examples?|/demo|/benchmarks?|/prompts?$|/prompt-|/template(s)?$|/template-|/boilerplate|/starter(s)?$|/starter-|/scaffold(s)?$|/scaffold-|/cookbook(s)?$|/cookbook-|/docs?$|/docs-|/documentation|/mirror|mirror-"
    DESCRIPTION_EXCLUDE_REGEX="\\b(mirror of|read-only mirror|documentation site|docs site|prompt collection|prompt pack|starter template|boilerplate template)\\b"
    FILTERS_DESC="profile=v2, one-repo-per-owner, archived=false, fork=false, pushed>=${MIN_PUSHED}, size<${MAX_SIZE_KB}, stratified cohort mix (actual weights recorded below), expanded AI-native agent queries, excludes obvious list/tutorial/example/template/docs/prompt-pack/mirror repos"
    ;;
esac

if [[ -n "${MAX_SIZE_KB}" ]]; then
  for i in "${!AI_QUERIES[@]}"; do
    AI_QUERIES[$i]="${AI_QUERIES[$i]} size:<${MAX_SIZE_KB}"
  done
  for i in "${!DEV_QUERIES[@]}"; do
    DEV_QUERIES[$i]="${DEV_QUERIES[$i]} size:<${MAX_SIZE_KB}"
  done
  for i in "${!SEC_QUERIES[@]}"; do
    SEC_QUERIES[$i]="${SEC_QUERIES[$i]} size:<${MAX_SIZE_KB}"
  done
fi

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
         description: (.description // ""),
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

if (( AI_WEIGHT > 0 )); then
  for q in "${AI_QUERIES[@]}"; do
    fetch_query "ai_native" "${q}" >> "${tmp_raw}"
  done
fi
if (( DEV_WEIGHT > 0 )); then
  for q in "${DEV_QUERIES[@]}"; do
    fetch_query "dev_platform" "${q}" >> "${tmp_raw}"
  done
fi
if (( SEC_WEIGHT > 0 )); then
  for q in "${SEC_QUERIES[@]}"; do
    fetch_query "security_platform" "${q}" >> "${tmp_raw}"
  done
fi

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
  --argjson sec_quota "${sec_quota}" \
  --arg name_exclude_regex "${NAME_EXCLUDE_REGEX}" \
  --arg full_name_exclude_regex "${FULLNAME_EXCLUDE_REGEX}" \
  --arg description_exclude_regex "${DESCRIPTION_EXCLUDE_REGEX}" '
  def keep_regex($value; $regex):
    if ($regex | length) == 0 then true else (($value | test($regex)) | not) end;

  def dedupe_by_full_name:
    reduce .[] as $item (
      {seen: {}, items: []};
      if (.seen[$item.full_name] // false)
      then .
      else .seen[$item.full_name] = true | .items += [$item]
      end
    ) | .items;

  def dedupe_by_owner:
    reduce .[] as $item (
      {seen: {}, items: []};
      if (.seen[$item.owner] // false)
      then .
      else .seen[$item.owner] = true | .items += [$item]
      end
    ) | .items;

  def norm:
    map(select(.full_name != null and .owner != null and .pushed_at != null))
    | map(. + {pushed_ts: (.pushed_at | fromdateiso8601)})
    | map(select(.pushed_at >= ($min_pushed + "T00:00:00Z")))
    | map(select(.archived == false and .fork == false))
    | map(select(keep_regex((.name | ascii_downcase); $name_exclude_regex)))
    | map(select(keep_regex((.full_name | ascii_downcase); $full_name_exclude_regex)))
    | map(select(keep_regex((.description // "" | ascii_downcase); $description_exclude_regex)))
    | sort_by(-.pushed_ts, -.stars, .full_name);

  def cohort_pool($all; $cohort):
    $all
    | map(select(.cohort == $cohort))
    | sort_by(-.pushed_ts, -.stars, .full_name)
    | dedupe_by_full_name
    | dedupe_by_owner;

  def pick_quota($pool; $used_owners; $n):
    $pool
    | map(select((.owner as $o | $used_owners | index($o)) | not))
    | .[0:$n];

  . | norm as $all
  | (cohort_pool($all; "security_platform")) as $sec_pool
  | (pick_quota($sec_pool; []; $sec_quota)) as $sec
  | ($sec | map(.owner)) as $owners_after_sec
  | (cohort_pool($all; "dev_platform")) as $dev_pool
  | (pick_quota($dev_pool; $owners_after_sec; $dev_quota)) as $dev
  | (($owners_after_sec + ($dev | map(.owner)))) as $owners_after_dev
  | (cohort_pool($all; "ai_native")) as $ai_pool
  | (pick_quota($ai_pool; $owners_after_dev; $ai_quota)) as $ai
  | ($sec + $dev + $ai) as $seed
  | ($seed | map(.owner)) as $seed_owners
  | (
      $all
      | sort_by(-.pushed_ts, -.stars, .full_name)
      | dedupe_by_full_name
      | map(select((.owner as $o | $seed_owners | index($o)) | not))
      | dedupe_by_owner
    ) as $remaining
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
  echo "# selection_profile=${SELECTION_PROFILE} | total=${selected_total} | ai_native=${ai_count} dev_platform=${dev_count} security_platform=${sec_count}"
  echo "# cohort_weights: ai_native=${AI_WEIGHT} dev_platform=${DEV_WEIGHT} security_platform=${SEC_WEIGHT}"
  echo "# filters: ${FILTERS_DESC}"
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
