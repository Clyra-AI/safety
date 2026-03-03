#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  validate.sh [--run-id <id>] [--strict]

Validates OpenClaw report readiness:
  - required report protocol/definition files exist
  - preregistration and citation controls exist
  - claim/threshold mapping coverage is complete
  - claims ledger structure and query reproducibility
  - citation gate (TBD markers fail in strict mode)
  - optional run artifact layout when --run-id is provided
  - headline threshold gate when run claims are finalized
  - deterministic SHA-256 manifest generation for run artifacts
USAGE
}

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUN_ID="${RUN_ID:-}"
STRICT=0
FAILURES=0

contains_machine_path() {
  local file="$1"
  jq -e '.. | strings | select(test("^/Users/|^/home/"))' "${file}" >/dev/null 2>&1
}

collect_example_timestamps() {
  local manuscript="$1"
  awk '
    /^### Example Events/ { in_section=1; next }
    /^## / && in_section { exit }
    in_section { print }
  ' "${manuscript}" | rg -o '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+Z' | sort -u
}

collect_media_example_timestamps() {
  local media_brief="$1"
  awk '
    /^## Artifact-Backed Scenario Examples/ { in_section=1; next }
    /^## / && in_section { exit }
    in_section { print }
  ' "${media_brief}" | rg -o '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+Z' | sort -u
}

collect_stat_card_example_timestamps() {
  local stat_cards="$1"
  rg -o '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+Z' "${stat_cards}" | sort -u
}

timestamp_in_anecdotes() {
  local anecdotes_file="$1"
  local timestamp="$2"
  jq -e --arg ts "${timestamp}" '
    ([.top_incidents[]?.timestamp, .examples_by_scenario[]?[]?.timestamp]
      | map(select(. != null))
      | index($ts)) != null
  ' "${anecdotes_file}" >/dev/null
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)
      RUN_ID="${2:-}"
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
      echo "[openclaw-validate] unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

required_files=(
  "internal/OPENCLAW_REPORT_TEMPLATE.md"
  "reports/openclaw-2026/definitions.md"
  "reports/openclaw-2026/study-protocol.md"
  "reports/openclaw-2026/methodology.md"
  "reports/openclaw-2026/preregistration.md"
  "claims/openclaw-2026/claims.json"
  "citations/openclaw-timeline-sources.md"
  "pipelines/config/publish-thresholds.json"
  "pipelines/common/metric_coverage_gate.sh"
  "pipelines/common/derive_claim_values.sh"
  "pipelines/common/evaluate_claim_values.sh"
)

for rel in "${required_files[@]}"; do
  if [[ ! -f "${REPO_ROOT}/${rel}" ]]; then
    echo "[openclaw-validate] missing required file: ${rel}" >&2
    FAILURES=$((FAILURES + 1))
  fi
done

if [[ "${FAILURES}" -gt 0 ]]; then
  echo "[openclaw-validate] required-file failures=${FAILURES}" >&2
  exit 1
fi

coverage_args=(
  --report-id "openclaw-2026"
  --claims "${REPO_ROOT}/claims/openclaw-2026/claims.json"
  --thresholds "${REPO_ROOT}/pipelines/config/publish-thresholds.json"
)
if [[ "${STRICT}" -eq 1 ]]; then
  coverage_args+=(--strict)
fi
"${REPO_ROOT}/pipelines/common/metric_coverage_gate.sh" "${coverage_args[@]}"

claim_args=(
  --repo-root "${REPO_ROOT}"
  --claims "claims/openclaw-2026/claims.json"
)
if [[ -n "${RUN_ID}" ]]; then
  claim_args+=(--run-id "${RUN_ID}")
fi
if [[ "${STRICT}" -eq 1 ]]; then
  claim_args+=(--strict)
fi
"${REPO_ROOT}/pipelines/common/claim_gates.sh" "${claim_args[@]}"

citation_args=(
  --citations "${REPO_ROOT}/citations/openclaw-timeline-sources.md"
)
if [[ "${STRICT}" -eq 1 ]]; then
  citation_args+=(--strict)
fi
"${REPO_ROOT}/pipelines/common/citation_gates.sh" "${citation_args[@]}"

if [[ -n "${RUN_ID}" ]]; then
  run_dir="${REPO_ROOT}/runs/openclaw/${RUN_ID}"
  for dir in config raw derived artifacts; do
    if [[ ! -d "${run_dir}/${dir}" ]]; then
      echo "[openclaw-validate] missing run directory: runs/openclaw/${RUN_ID}/${dir}" >&2
      FAILURES=$((FAILURES + 1))
    fi
  done

  required_run_files=(
    "raw/ungoverned/events.jsonl"
    "raw/governed/events.jsonl"
    "derived/ungoverned_summary.json"
    "derived/governed_summary.json"
    "derived/scenario_summary.json"
    "artifacts/anecdotes.json"
    "artifacts/run-manifest.json"
  )
  for rel in "${required_run_files[@]}"; do
    if [[ ! -f "${run_dir}/${rel}" ]]; then
      echo "[openclaw-validate] missing run artifact: runs/openclaw/${RUN_ID}/${rel}" >&2
      FAILURES=$((FAILURES + 1))
    fi
  done

  if [[ -d "${run_dir}" ]]; then
    derive_args=(
      --repo-root "${REPO_ROOT}"
      --claims "claims/openclaw-2026/claims.json"
      --run-id "${RUN_ID}"
      --output "${run_dir}/artifacts/claim-values.json"
    )
    if [[ "${STRICT}" -eq 1 ]]; then
      derive_args+=(--strict)
    fi
    "${REPO_ROOT}/pipelines/common/derive_claim_values.sh" "${derive_args[@]}"

    lane_duration_sec="$(jq -r '.measurement_window.lane_duration_sec // empty' "${run_dir}/artifacts/run-manifest.json" 2>/dev/null || true)"
    if [[ -n "${lane_duration_sec}" ]]; then
      "${REPO_ROOT}/pipelines/common/evaluate_claim_values.sh" \
        --report-id "openclaw-2026" \
        --repo-root "${REPO_ROOT}" \
        --claim-values "${run_dir}/artifacts/claim-values.json" \
        --thresholds "${REPO_ROOT}/pipelines/config/publish-thresholds.json" \
        --lane-duration-sec "${lane_duration_sec}" \
        --scale-ids "openclaw_sensitive_access_without_approval" \
        --output "${run_dir}/artifacts/threshold-evaluation.json"
    fi

    mkdir -p "${run_dir}/artifacts"
    "${REPO_ROOT}/pipelines/common/hash_manifest.sh" \
      --input "${run_dir}" \
      --output "${run_dir}/artifacts/manifest.sha256"

    if [[ -f "${run_dir}/derived/scenario_summary.json" ]]; then
      if ! jq -e '
        (.coverage.ungoverned_missing | type) == "array"
        and (.coverage.governed_missing | type) == "array"
        and ((.coverage.ungoverned_missing | length) == 0)
        and ((.coverage.governed_missing | length) == 0)
      ' "${run_dir}/derived/scenario_summary.json" >/dev/null; then
        echo "[openclaw-validate] scenario coverage incomplete for run ${RUN_ID}" >&2
        FAILURES=$((FAILURES + 1))
      fi
    fi

    machine_path_files=(
      "${run_dir}/artifacts/claim-values.json"
      "${run_dir}/artifacts/threshold-evaluation.json"
      "${run_dir}/artifacts/run-manifest.json"
    )
    for abs_check in "${machine_path_files[@]}"; do
      if [[ -f "${abs_check}" ]] && contains_machine_path "${abs_check}"; then
        rel_path="${abs_check#${REPO_ROOT}/}"
        echo "[openclaw-validate] machine-specific absolute path detected in ${rel_path}" >&2
        FAILURES=$((FAILURES + 1))
      fi
    done

    manuscript_path="${REPO_ROOT}/reports/openclaw-2026/manuscript/report.md"
    anecdotes_path="${run_dir}/artifacts/anecdotes.json"
    if [[ -f "${manuscript_path}" && -f "${anecdotes_path}" ]]; then
      example_timestamps_raw="$(collect_example_timestamps "${manuscript_path}" || true)"
      if [[ -z "${example_timestamps_raw}" ]]; then
        msg="[openclaw-validate] no Example Events timestamps found in manuscript"
        if [[ "${STRICT}" -eq 1 ]]; then
          echo "${msg}" >&2
          FAILURES=$((FAILURES + 1))
        else
          echo "${msg} (warning in non-strict mode)" >&2
        fi
      else
        while IFS= read -r ts; do
          [[ -z "${ts}" ]] && continue
          if ! timestamp_in_anecdotes "${anecdotes_path}" "${ts}"; then
            echo "[openclaw-validate] manuscript example timestamp not found in promoted anecdotes: ${ts}" >&2
            FAILURES=$((FAILURES + 1))
          fi
        done <<< "${example_timestamps_raw}"
      fi
    fi

    press_media_path="${REPO_ROOT}/reports/openclaw-2026/press-pack/media-brief.md"
    if [[ -f "${press_media_path}" && -f "${anecdotes_path}" ]]; then
      media_timestamps_raw="$(collect_media_example_timestamps "${press_media_path}" || true)"
      if [[ -n "${media_timestamps_raw}" ]]; then
        while IFS= read -r ts; do
          [[ -z "${ts}" ]] && continue
          if ! timestamp_in_anecdotes "${anecdotes_path}" "${ts}"; then
            echo "[openclaw-validate] press media-brief example timestamp not found in promoted anecdotes: ${ts}" >&2
            FAILURES=$((FAILURES + 1))
          fi
        done <<< "${media_timestamps_raw}"
      fi
    fi

    press_stat_cards_path="${REPO_ROOT}/reports/openclaw-2026/press-pack/stat-cards.md"
    if [[ -f "${press_stat_cards_path}" && -f "${anecdotes_path}" ]]; then
      stat_timestamps_raw="$(collect_stat_card_example_timestamps "${press_stat_cards_path}" || true)"
      if [[ -n "${stat_timestamps_raw}" ]]; then
        while IFS= read -r ts; do
          [[ -z "${ts}" ]] && continue
          if ! timestamp_in_anecdotes "${anecdotes_path}" "${ts}"; then
            echo "[openclaw-validate] press stat-card timestamp not found in promoted anecdotes: ${ts}" >&2
            FAILURES=$((FAILURES + 1))
          fi
        done <<< "${stat_timestamps_raw}"
      fi
    fi
  fi

  threshold_args=(
    --report-id "openclaw-2026"
    --claims "${REPO_ROOT}/claims/openclaw-2026/claims.json"
    --thresholds "${REPO_ROOT}/pipelines/config/publish-thresholds.json"
  )
  if jq -e '.claims[] | select((.value | type) == "string" and .value == "TBD")' \
    "${REPO_ROOT}/claims/openclaw-2026/claims.json" >/dev/null; then
    if [[ "${STRICT}" -eq 1 ]]; then
      threshold_args+=(--strict)
      "${REPO_ROOT}/pipelines/common/threshold_gate.sh" "${threshold_args[@]}"
    else
      echo "[openclaw-validate] threshold gate skipped (claims not finalized)." >&2
    fi
  else
    if [[ "${STRICT}" -eq 1 ]]; then
      threshold_args+=(--strict)
    fi
    "${REPO_ROOT}/pipelines/common/threshold_gate.sh" "${threshold_args[@]}"
  fi
fi

if [[ "${FAILURES}" -gt 0 ]]; then
  echo "[openclaw-validate] failures=${FAILURES}" >&2
  exit 1
fi

echo "[openclaw-validate] ok"
