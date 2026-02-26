#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  citation_gates.sh --citations <file> [--strict]

Checks citation-log readiness:
  - citation file exists
  - table rows exist
  - unresolved TBD markers are warnings in non-strict mode
  - unresolved TBD markers are failures in strict mode
EOF
}

CITATIONS_FILE=""
STRICT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --citations)
      CITATIONS_FILE="${2:-}"
      shift 2
      ;;
    --strict)
      STRICT=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[citation-gates] unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "${CITATIONS_FILE}" ]]; then
  echo "[citation-gates] --citations is required" >&2
  usage >&2
  exit 1
fi

if [[ ! -f "${CITATIONS_FILE}" ]]; then
  echo "[citation-gates] citations file not found: ${CITATIONS_FILE}" >&2
  exit 1
fi

row_count="$(
  awk '
    BEGIN { c = 0 }
    /^\|/ {
      if ($0 ~ /^\|---/) next
      if ($0 ~ /\|[[:space:]]*Claim[[:space:]]*\|/) next
      if ($0 ~ /\|[[:space:]]*Regulation[[:space:]]*\|/) next
      c++
    }
    END { print c + 0 }
  ' "${CITATIONS_FILE}"
)"

if [[ "${row_count}" -eq 0 ]]; then
  echo "[citation-gates] no citation rows found: ${CITATIONS_FILE}" >&2
  exit 1
fi

tbd_count="$(
  (grep -Eo '\bTBD\b' "${CITATIONS_FILE}" || true) | wc -l | tr -d '[:space:]'
)"
if [[ "${tbd_count}" -gt 0 ]]; then
  msg="[citation-gates] unresolved TBD markers in ${CITATIONS_FILE}: ${tbd_count}"
  if [[ "${STRICT}" -eq 1 ]]; then
    echo "${msg}" >&2
    exit 1
  fi
  echo "${msg} (warning)" >&2
fi

echo "[citation-gates] ok rows=${row_count} tbd=${tbd_count}"
