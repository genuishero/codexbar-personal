#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CSV_PATH="$ROOT_DIR/codex.csv"
CREATE_SCRIPT="$ROOT_DIR/scripts/create_and_import_openai_account.sh"
IMPORT_SCRIPT="$ROOT_DIR/scripts/import_openai_account_to_codexbar.sh"
CSV_SHADOW_HELPER="$ROOT_DIR/scripts/codex_csv_shadow.sh"
CSV_STATE_HELPER="$ROOT_DIR/scripts/codex_csv_state.py"
BATCH_SIZE="${BATCH_SIZE:-5}"
IMPORT_PHASE_DELAY_SECS="${IMPORT_PHASE_DELAY_SECS:-0}"
ACCOUNTS_FILE="$(mktemp)"

REGISTERED_COUNT=0
IMPORTED_COUNT=0
IMPORT_CANDIDATE_COUNT=0
REGISTRATION_FAILURE=0
IMPORT_FAILURE=0

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'missing required command: %s\n' "$1" >&2
    exit 127
  }
}

cleanup() {
  rm -f "$ACCOUNTS_FILE"
}

trap cleanup EXIT

ensure_positive_integer() {
  local name="$1"
  local value="$2"

  if [[ ! "$value" =~ ^[1-9][0-9]*$ ]]; then
    printf '%s must be a positive integer, got %s\n' "$name" "$value" >&2
    exit 64
  fi
}

csv_upsert_row() {
  local email="$1" password="$2" status="$3" url="$4" auth_method="$5" phase="$6" failure_category="$7" manual_action="$8"
  shift 8
  codex_csv_begin_mutation "$CSV_PATH"
  python3 "$CSV_STATE_HELPER" ensure "$CSV_PATH"
  python3 "$CSV_STATE_HELPER" upsert "$CSV_PATH" \
    --email "$email" \
    --password "$password" \
    --status "$status" \
    --url "$url" \
    --auth-method "$auth_method" \
    --phase "$phase" \
    --failure-category "$failure_category" \
    --manual-action "$manual_action" \
    "$@"
  codex_csv_sync_shadow "$CSV_PATH"
}

require_cmd bash
require_cmd python3
source "$CSV_SHADOW_HELPER"

ensure_positive_integer "BATCH_SIZE" "$BATCH_SIZE"

if [[ ! "$IMPORT_PHASE_DELAY_SECS" =~ ^[0-9]+$ ]]; then
  printf 'IMPORT_PHASE_DELAY_SECS must be a non-negative integer, got %s\n' "$IMPORT_PHASE_DELAY_SECS" >&2
  exit 64
fi

for index in $(seq 1 "$BATCH_SIZE"); do
  printf 'REGISTER_PHASE_ITEM=%s/%s\n' "$index" "$BATCH_SIZE"
  if ! output="$(IMPORT_AFTER_REGISTER=0 "$CREATE_SCRIPT" 2>&1)"; then
    printf '%s\n' "$output" >&2
    REGISTRATION_FAILURE=1
    break
  fi

  printf '%s\n' "$output"

  email="$(printf '%s\n' "$output" | sed -n 's/^REGISTERED_EMAIL=//p' | tail -n 1)"
  password="$(printf '%s\n' "$output" | sed -n 's/^PASSWORD=//p' | tail -n 1)"
  workflow_status="$(printf '%s\n' "$output" | sed -n 's/^WORKFLOW_STATUS=//p' | tail -n 1)"
  import_eligible="$(printf '%s\n' "$output" | sed -n 's/^IMPORT_ELIGIBLE=//p' | tail -n 1)"
  auth_method="$(printf '%s\n' "$output" | sed -n 's/^AUTH_METHOD=//p' | tail -n 1)"
  manual_action="$(printf '%s\n' "$output" | sed -n 's/^MANUAL_ACTION=//p' | tail -n 1)"

  if [[ -z "$email" ]]; then
    printf 'failed to parse registration output for batch item %s\n' "$index" >&2
    REGISTRATION_FAILURE=1
    break
  fi

  if [[ "$workflow_status" == "completed" ]]; then
    ((REGISTERED_COUNT += 1))
  fi
  if [[ "${import_eligible:-0}" == "1" && -n "$password" ]]; then
    printf '%s\t%s\t%s\n' "$email" "$password" "${auth_method:-password}" >>"$ACCOUNTS_FILE"
    ((IMPORT_CANDIDATE_COUNT += 1))
  else
    printf 'REGISTER_PHASE_SKIP_IMPORT=%s\t%s\n' "$email" "${manual_action:-not_import_eligible}"
  fi
done

if (( REGISTERED_COUNT == 0 )); then
  printf 'no accounts were registered; skipping import phase\n' >&2
  exit 1
fi

if (( IMPORT_CANDIDATE_COUNT == 0 )); then
  printf 'BATCH_REGISTERED_COUNT=%s\n' "$REGISTERED_COUNT"
  printf 'BATCH_IMPORTED_COUNT=0\n'
  printf 'BATCH_IMPORT_SKIPPED_COUNT=%s\n' "$REGISTERED_COUNT"
  exit $(( REGISTRATION_FAILURE ? 1 : 0 ))
fi

if (( IMPORT_PHASE_DELAY_SECS > 0 )); then
  sleep "$IMPORT_PHASE_DELAY_SECS"
fi

index=0
while IFS=$'\t' read -r email password auth_method; do
  ((index += 1))
  printf 'IMPORT_PHASE_ITEM=%s/%s\n' "$index" "$IMPORT_CANDIDATE_COUNT"
  if output="$(CODEX_CSV_PATH="$CSV_PATH" CODEX_CSV_EMAIL="$email" OPENAI_EMAIL="$email" OPENAI_PASSWORD="$password" "$IMPORT_SCRIPT" 2>&1)"; then
    printf '%s\n' "$output"
    last_seen_url_host_path="$(printf '%s\n' "$output" | sed -n 's/^LAST_SEEN_URL_HOST_PATH=//p' | tail -n 1)"
    csv_upsert_row "$email" "$password" "completed" "${last_seen_url_host_path:-}" "${auth_method:-password}" "import" "" "none" --retry-count 0
    ((IMPORTED_COUNT += 1))
    continue
  fi

  printf '%s\n' "$output" >&2
  failure_category="$(printf '%s\n' "$output" | sed -n 's/^IMPORT_FAILURE_CATEGORY=//p' | tail -n 1)"
  workflow_status="$(printf '%s\n' "$output" | sed -n 's/^WORKFLOW_STATUS=//p' | tail -n 1)"
  manual_action="$(printf '%s\n' "$output" | sed -n 's/^MANUAL_ACTION=//p' | tail -n 1)"
  last_seen_url_host_path="$(printf '%s\n' "$output" | sed -n 's/^LAST_SEEN_URL_HOST_PATH=//p' | tail -n 1)"
  if [[ "$workflow_status" == "retryable_failure" ]]; then
    csv_upsert_row "$email" "$password" "$workflow_status" "${last_seen_url_host_path:-}" "${auth_method:-password}" "import" "${failure_category:-provider_timeout}" "${manual_action:-retry_after_local_fix}" --increment-retry-count
  else
    csv_upsert_row "$email" "$password" "${workflow_status:-manual_required}" "${last_seen_url_host_path:-}" "${auth_method:-password}" "import" "${failure_category:-provider_timeout}" "${manual_action:-complete_provider_challenge}"
  fi
  IMPORT_FAILURE=1
done <"$ACCOUNTS_FILE"

printf 'BATCH_REGISTERED_COUNT=%s\n' "$REGISTERED_COUNT"
printf 'BATCH_IMPORTED_COUNT=%s\n' "$IMPORTED_COUNT"
printf 'BATCH_IMPORT_SKIPPED_COUNT=%s\n' "$(( REGISTERED_COUNT - IMPORTED_COUNT ))"

if (( REGISTRATION_FAILURE || IMPORT_FAILURE )); then
  exit 1
fi
