#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  build_report_pdf.sh --report-dir <path> [--source <md>] [--header <tex>] [--out <pdf>] [--copy-to-root]

Builds a report PDF from Markdown deterministically with visible blue hyperlinks.

Defaults:
  --source <report-dir>/manuscript/report.md
  --header <report-dir>/manuscript/pdf-header.tex
  --out    <report-dir>/manuscript/report.pdf
  --copy-to-root enabled (copies manuscript/report.pdf to <report-dir>/report.pdf)
EOF
}

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPORT_DIR=""
SOURCE_MD=""
HEADER_TEX=""
OUT_PDF=""
COPY_TO_ROOT=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --report-dir)
      REPORT_DIR="${2:-}"
      shift 2
      ;;
    --source)
      SOURCE_MD="${2:-}"
      shift 2
      ;;
    --header)
      HEADER_TEX="${2:-}"
      shift 2
      ;;
    --out)
      OUT_PDF="${2:-}"
      shift 2
      ;;
    --copy-to-root)
      COPY_TO_ROOT=1
      shift
      ;;
    --no-copy-to-root)
      COPY_TO_ROOT=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[build-report-pdf] unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "${REPORT_DIR}" ]]; then
  echo "[build-report-pdf] --report-dir is required" >&2
  usage >&2
  exit 1
fi

if [[ "${REPORT_DIR}" != /* ]]; then
  REPORT_DIR="${REPO_ROOT}/${REPORT_DIR}"
fi

if [[ -z "${SOURCE_MD}" ]]; then
  SOURCE_MD="${REPORT_DIR}/manuscript/report.md"
fi
if [[ -z "${HEADER_TEX}" ]]; then
  HEADER_TEX="${REPORT_DIR}/manuscript/pdf-header.tex"
fi
if [[ -z "${OUT_PDF}" ]]; then
  OUT_PDF="${REPORT_DIR}/manuscript/report.pdf"
fi

if [[ "${SOURCE_MD}" != /* ]]; then
  SOURCE_MD="${REPO_ROOT}/${SOURCE_MD}"
fi
if [[ "${HEADER_TEX}" != /* ]]; then
  HEADER_TEX="${REPO_ROOT}/${HEADER_TEX}"
fi
if [[ "${OUT_PDF}" != /* ]]; then
  OUT_PDF="${REPO_ROOT}/${OUT_PDF}"
fi

MANUSCRIPT_DIR="$(cd "$(dirname "${SOURCE_MD}")" && pwd)"
REPORT_TEX="${MANUSCRIPT_DIR}/report.tex"
MANUSCRIPT_PDF="${MANUSCRIPT_DIR}/report.pdf"

if [[ ! -f "${SOURCE_MD}" ]]; then
  echo "[build-report-pdf] missing source markdown: ${SOURCE_MD}" >&2
  exit 1
fi
if [[ ! -f "${HEADER_TEX}" ]]; then
  echo "[build-report-pdf] missing header file: ${HEADER_TEX}" >&2
  exit 1
fi
if ! command -v pandoc >/dev/null 2>&1; then
  echo "[build-report-pdf] pandoc is required" >&2
  exit 1
fi
if ! command -v latexmk >/dev/null 2>&1; then
  echo "[build-report-pdf] latexmk is required" >&2
  exit 1
fi

mkdir -p "$(dirname "${OUT_PDF}")"

pandoc "${SOURCE_MD}" \
  --standalone \
  --from gfm \
  --to latex \
  --include-in-header="${HEADER_TEX}" \
  -V geometry:margin=1in \
  -V colorlinks=true \
  -V linkcolor=blue \
  -V urlcolor=blue \
  -V citecolor=blue \
  -V filecolor=blue \
  -o "${REPORT_TEX}"

latexmk -pdfxe -interaction=nonstopmode -halt-on-error -outdir="${MANUSCRIPT_DIR}" "${REPORT_TEX}"

if [[ "${MANUSCRIPT_PDF}" != "${OUT_PDF}" ]]; then
  cp "${MANUSCRIPT_PDF}" "${OUT_PDF}"
fi

if [[ "${COPY_TO_ROOT}" -eq 1 ]]; then
  ROOT_COPY="${REPORT_DIR}/report.pdf"
  if [[ "${MANUSCRIPT_PDF}" != "${ROOT_COPY}" ]]; then
    cp "${MANUSCRIPT_PDF}" "${ROOT_COPY}"
  fi
  echo "[build-report-pdf] wrote ${OUT_PDF}"
  echo "[build-report-pdf] wrote ${ROOT_COPY}"
else
  echo "[build-report-pdf] wrote ${OUT_PDF}"
fi
