#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CSV_PATH="$ROOT_DIR/codex.csv"
IMPORT_SCRIPT="$ROOT_DIR/scripts/import_openai_account_to_codexbar.sh"
CSV_SHADOW_HELPER="$ROOT_DIR/scripts/codex_csv_shadow.sh"
CSV_STATE_HELPER="$ROOT_DIR/scripts/codex_csv_state.py"
EMAIL_FILTER="${EMAIL_FILTER:-}"
LOGIN_INTERVAL_SECS="${LOGIN_INTERVAL_SECS:-150}"
RECONCILED_COUNT=0
IMPORTED_COUNT=0
FAILED_COUNT=0
PENDING_FILE="$(mktemp)"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'missing required command: %s\n' "$1" >&2
    exit 127
  }
}

cleanup() {
  rm -f "$PENDING_FILE"
}

trap cleanup EXIT

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

reconcile_csv_with_codexbar() {
  local reconciled_count=""

  codex_csv_begin_mutation "$CSV_PATH"
  python3 "$CSV_STATE_HELPER" ensure "$CSV_PATH" >/dev/null
  reconciled_count="$(python3 "$CSV_STATE_HELPER" reconcile-imported "$CSV_PATH" --email-filter "$EMAIL_FILTER")"
  codex_csv_sync_shadow "$CSV_PATH"

  RECONCILED_COUNT="${reconciled_count:-0}"
  printf 'CSV_RECONCILED_SUCCESS_COUNT=%s\n' "$RECONCILED_COUNT"
}

require_cmd python3
source "$CSV_SHADOW_HELPER"
codex_csv_restore_if_needed "$CSV_PATH"

if [[ ! "$LOGIN_INTERVAL_SECS" =~ ^[0-9]+$ ]]; then
  printf 'LOGIN_INTERVAL_SECS must be a non-negative integer, got %s\n' "$LOGIN_INTERVAL_SECS" >&2
  exit 64
fi

reconcile_csv_with_codexbar

python3 "$CSV_STATE_HELPER" list-retry-candidates "$CSV_PATH" --email-filter "$EMAIL_FILTER" >"$PENDING_FILE"

readarray -t TARGETS <"$PENDING_FILE"

if (( ${#TARGETS[@]} < 2 )); then
  if [[ -n "$EMAIL_FILTER" ]]; then
    printf 'no auto-retry-eligible Codexbar import account found in %s for %s\n' "$CSV_PATH" "$EMAIL_FILTER"
  else
    printf 'no auto-retry-eligible Codexbar import account found in %s\n' "$CSV_PATH"
  fi
  printf 'BATCH_IMPORTED_COUNT=0\n'
  printf 'BATCH_FAILED_COUNT=0\n'
  exit 0
fi

total=$(( ${#TARGETS[@]} / 2 ))
index=0

while (( index < ${#TARGETS[@]} )); do
  email="${TARGETS[index]}"
  password="${TARGETS[index + 1]}"
  item=$(( index / 2 + 1 ))

  printf 'IMPORT_PHASE_ITEM=%s/%s\n' "$item" "$total"

  if output="$(CODEX_CSV_PATH="$CSV_PATH" CODEX_CSV_EMAIL="$email" OPENAI_EMAIL="$email" OPENAI_PASSWORD="$password" "$IMPORT_SCRIPT" 2>&1)"; then
    printf '%s\n' "$output"
    auth_method="$(printf '%s\n' "$output" | sed -n 's/^AUTH_METHOD=//p' | tail -n 1)"
    last_seen_url_host_path="$(printf '%s\n' "$output" | sed -n 's/^LAST_SEEN_URL_HOST_PATH=//p' | tail -n 1)"
    csv_upsert_row "$email" "$password" "completed" "${last_seen_url_host_path:-}" "${auth_method:-password}" "import" "" "none" --retry-count 0
    ((IMPORTED_COUNT += 1))
  else
    FAILURE_CATEGORY="$(printf '%s\n' "$output" | sed -n 's/^IMPORT_FAILURE_CATEGORY=//p' | tail -n 1)"
    WORKFLOW_STATUS="$(printf '%s\n' "$output" | sed -n 's/^WORKFLOW_STATUS=//p' | tail -n 1)"
    MANUAL_ACTION="$(printf '%s\n' "$output" | sed -n 's/^MANUAL_ACTION=//p' | tail -n 1)"
    AUTH_METHOD="$(printf '%s\n' "$output" | sed -n 's/^AUTH_METHOD=//p' | tail -n 1)"
    LAST_SEEN_URL_HOST_PATH="$(printf '%s\n' "$output" | sed -n 's/^LAST_SEEN_URL_HOST_PATH=//p' | tail -n 1)"
    printf '%s\n' "$output" >&2
    if [[ "$WORKFLOW_STATUS" == "retryable_failure" ]]; then
      csv_upsert_row "$email" "$password" "$WORKFLOW_STATUS" "${LAST_SEEN_URL_HOST_PATH:-}" "${AUTH_METHOD:-password}" "import" "${FAILURE_CATEGORY:-provider_timeout}" "${MANUAL_ACTION:-retry_after_local_fix}" --increment-retry-count
    else
      csv_upsert_row "$email" "$password" "${WORKFLOW_STATUS:-manual_required}" "${LAST_SEEN_URL_HOST_PATH:-}" "${AUTH_METHOD:-password}" "import" "${FAILURE_CATEGORY:-provider_timeout}" "${MANUAL_ACTION:-complete_provider_challenge}"
    fi
    if [[ -n "$FAILURE_CATEGORY" ]]; then
      printf 'IMPORT_FAILURE_CATEGORY=%s\n' "$FAILURE_CATEGORY" >&2
    fi
    ((FAILED_COUNT += 1))
  fi

  index=$(( index + 2 ))

  if (( index < ${#TARGETS[@]} && LOGIN_INTERVAL_SECS > 0 )); then
    printf 'WAIT_BEFORE_NEXT_IMPORT_SECS=%s\n' "$LOGIN_INTERVAL_SECS"
    sleep "$LOGIN_INTERVAL_SECS"
  fi
done

printf 'BATCH_IMPORTED_COUNT=%s\n' "$IMPORTED_COUNT"
printf 'BATCH_FAILED_COUNT=%s\n' "$FAILED_COUNT"

if (( FAILED_COUNT > 0 )); then
  exit 1
fi
