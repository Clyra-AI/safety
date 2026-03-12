#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  generate_targets_v2.sh [--purpose calibration|publication] [--total <n>]
                         [--output <path>] [--catalog <path>]
                         [--min-pushed <YYYY-MM-DD>] [--pages <n>] [--per-page <n>]
                         [--ai-weight <0-100>] [--dev-weight <0-100>] [--sec-weight <0-100>]
                         [--max-size-kb <n>] [--http-client <auto|gh|curl>]

Builds a v2-specific reproducible target list using the explicit v2 selection profile.

Defaults:
  - publication: AppSec-oriented publication cohort, 50/30/20 AI/dev/sec
  - calibration: agent-dense calibration cohort, 85/10/5 AI/dev/sec
USAGE
}

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PURPOSE="publication"
TOTAL=""
OUTPUT_PATH=""
CATALOG_PATH=""
MIN_PUSHED=""
PAGES=""
PER_PAGE=""
AI_WEIGHT=""
DEV_WEIGHT=""
SEC_WEIGHT=""
MAX_SIZE_KB=""
HTTP_CLIENT="auto"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --purpose)
      PURPOSE="${2:-}"
      shift 2
      ;;
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
    --max-size-kb)
      MAX_SIZE_KB="${2:-}"
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
      echo "[sprawl-targets-v2] unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

case "${PURPOSE}" in
  publication)
    [[ -n "${TOTAL}" ]] || TOTAL="1000"
    [[ -n "${OUTPUT_PATH}" ]] || OUTPUT_PATH="internal/repos-v2-publication.md"
    [[ -n "${CATALOG_PATH}" ]] || CATALOG_PATH="internal/repos-v2-publication_candidates.csv"
    [[ -n "${AI_WEIGHT}" ]] || AI_WEIGHT="50"
    [[ -n "${DEV_WEIGHT}" ]] || DEV_WEIGHT="30"
    [[ -n "${SEC_WEIGHT}" ]] || SEC_WEIGHT="20"
    [[ -n "${MAX_SIZE_KB}" ]] || MAX_SIZE_KB="200000"
    ;;
  calibration)
    [[ -n "${TOTAL}" ]] || TOTAL="100"
    [[ -n "${OUTPUT_PATH}" ]] || OUTPUT_PATH="internal/repos-v2-calibration.md"
    [[ -n "${CATALOG_PATH}" ]] || CATALOG_PATH="internal/repos-v2-calibration_candidates.csv"
    [[ -n "${AI_WEIGHT}" ]] || AI_WEIGHT="85"
    [[ -n "${DEV_WEIGHT}" ]] || DEV_WEIGHT="10"
    [[ -n "${SEC_WEIGHT}" ]] || SEC_WEIGHT="5"
    [[ -n "${MAX_SIZE_KB}" ]] || MAX_SIZE_KB="50000"
    ;;
  *)
    echo "[sprawl-targets-v2] --purpose must be one of: calibration, publication" >&2
    exit 1
    ;;
esac

[[ -n "${MIN_PUSHED}" ]] || MIN_PUSHED="2025-01-01"
[[ -n "${PAGES}" ]] || PAGES="2"
[[ -n "${PER_PAGE}" ]] || PER_PAGE="100"
[[ -n "${MAX_SIZE_KB}" ]] || MAX_SIZE_KB="200000"

cmd=(
  "${REPO_ROOT}/pipelines/sprawl/generate_targets.sh"
  --selection-profile v2
  --total "${TOTAL}"
  --output "${OUTPUT_PATH}"
  --catalog "${CATALOG_PATH}"
  --min-pushed "${MIN_PUSHED}"
  --pages "${PAGES}"
  --per-page "${PER_PAGE}"
  --http-client "${HTTP_CLIENT}"
  --ai-weight "${AI_WEIGHT}"
  --dev-weight "${DEV_WEIGHT}"
  --sec-weight "${SEC_WEIGHT}"
  --max-size-kb "${MAX_SIZE_KB}"
)

echo "[sprawl-targets-v2] purpose=${PURPOSE} total=${TOTAL} ai=${AI_WEIGHT} dev=${DEV_WEIGHT} sec=${SEC_WEIGHT}"
"${cmd[@]}"
