#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  hash_manifest.sh --input <dir> --output <file>

Writes a deterministic SHA-256 manifest with lines:
  <sha256>  <relative_path>
EOF
}

INPUT_DIR=""
OUTPUT_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input)
      INPUT_DIR="${2:-}"
      shift 2
      ;;
    --output)
      OUTPUT_FILE="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[hash-manifest] unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "${INPUT_DIR}" || -z "${OUTPUT_FILE}" ]]; then
  echo "[hash-manifest] --input and --output are required" >&2
  usage >&2
  exit 1
fi

if [[ ! -d "${INPUT_DIR}" ]]; then
  echo "[hash-manifest] input directory not found: ${INPUT_DIR}" >&2
  exit 1
fi

if command -v sha256sum >/dev/null 2>&1; then
  HASHER=(sha256sum)
elif command -v shasum >/dev/null 2>&1; then
  HASHER=(shasum -a 256)
else
  echo "[hash-manifest] missing required hash command (sha256sum or shasum)" >&2
  exit 1
fi

INPUT_ABS="$(cd "${INPUT_DIR}" && pwd)"
mkdir -p "$(dirname "${OUTPUT_FILE}")"
OUTPUT_ABS="$(cd "$(dirname "${OUTPUT_FILE}")" && pwd)/$(basename "${OUTPUT_FILE}")"
TMP_FILE="$(mktemp)"

files=()
while IFS= read -r line; do
  files+=("${line}")
done < <(find "${INPUT_ABS}" -type f | sort)
if [[ "${#files[@]}" -eq 0 ]]; then
  echo "[hash-manifest] no files found under ${INPUT_ABS}" >&2
  rm -f "${TMP_FILE}"
  exit 1
fi

for file in "${files[@]}"; do
  if [[ "${file}" = "${OUTPUT_ABS}" ]]; then
    continue
  fi
  rel="${file#${INPUT_ABS}/}"
  hash="$("${HASHER[@]}" "${file}" | awk '{print $1}')"
  printf '%s  %s\n' "${hash}" "${rel}" >> "${TMP_FILE}"
done

mv "${TMP_FILE}" "${OUTPUT_FILE}"
echo "[hash-manifest] wrote ${OUTPUT_FILE}"
