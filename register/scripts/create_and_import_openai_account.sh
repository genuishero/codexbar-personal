#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HIDE_MY_EMAIL_SCRIPT="$ROOT_DIR/chatgpt-anon-register/scripts/create_hide_my_email.sh"
REGISTER_SCRIPT="$ROOT_DIR/chatgpt-anon-register/scripts/register_chatgpt.sh"
IMPORT_SCRIPT="$ROOT_DIR/scripts/import_openai_account_to_codexbar.sh"
CSV_SHADOW_HELPER="$ROOT_DIR/scripts/codex_csv_shadow.sh"
CSV_STATE_HELPER="$ROOT_DIR/scripts/codex_csv_state.py"
CSV_PATH="$ROOT_DIR/codex.csv"
REGISTRATION_SETTLE_SECS="${REGISTRATION_SETTLE_SECS:-90}"
IMPORT_AFTER_REGISTER="${IMPORT_AFTER_REGISTER:-1}"
AUTH_URL_FILE="$(mktemp)"

LOG_EMAIL=""
LOG_PASSWORD=""
LOG_URL=""
LOG_STATUS="pending"
LOG_AUTH_METHOD="unknown"
LOG_PHASE="register"
LOG_FAILURE_CATEGORY=""
LOG_MANUAL_ACTION="none"
LOG_RETRY_ARGS=(--retry-count 0)

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'missing required command: %s\n' "$1" >&2
    exit 127
  }
}

csv_upsert_row() {
  python3 "$CSV_STATE_HELPER" upsert "$CSV_PATH" \
    --email "$LOG_EMAIL" \
    --password "$LOG_PASSWORD" \
    --status "$LOG_STATUS" \
    --url "$LOG_URL" \
    --auth-method "$LOG_AUTH_METHOD" \
    --phase "$LOG_PHASE" \
    --failure-category "$LOG_FAILURE_CATEGORY" \
    --manual-action "$LOG_MANUAL_ACTION" \
    "${LOG_RETRY_ARGS[@]}"
}

sync_csv() {
  codex_csv_begin_mutation "$CSV_PATH"
  python3 "$CSV_STATE_HELPER" ensure "$CSV_PATH"
  if [[ -n "$LOG_EMAIL" || -n "$LOG_FAILURE_CATEGORY" ]]; then
    csv_upsert_row
  fi
  codex_csv_sync_shadow "$CSV_PATH"
}

finalize_log() {
  if [[ -f "$AUTH_URL_FILE" ]]; then
    LOG_URL="$(cat "$AUTH_URL_FILE")"
  fi
  sync_csv
  rm -f "$AUTH_URL_FILE"
}

trap finalize_log EXIT

require_cmd bash
require_cmd python3
source "$CSV_SHADOW_HELPER"

RELAY_EMAIL="$("$HIDE_MY_EMAIL_SCRIPT")"
if [[ -z "$RELAY_EMAIL" ]]; then
  LOG_EMAIL=""
  LOG_STATUS="retryable_failure"
  LOG_PHASE="register"
  LOG_FAILURE_CATEGORY="hide_my_email_failed"
  LOG_MANUAL_ACTION="retry_after_local_fix"
  LOG_RETRY_ARGS=(--increment-retry-count)
  printf 'failed to create a new Hide My Email alias\n' >&2
  exit 1
fi

REGISTER_OUTPUT="$(RELAY_EMAIL="$RELAY_EMAIL" "$REGISTER_SCRIPT" 2>&1)" || REGISTER_EXIT=$?
REGISTER_EXIT="${REGISTER_EXIT:-0}"
REGISTERED_EMAIL="$(printf '%s\n' "$REGISTER_OUTPUT" | sed -n 's/^REGISTERED_EMAIL=//p' | tail -n 1)"
PASSWORD="$(printf '%s\n' "$REGISTER_OUTPUT" | sed -n 's/^PASSWORD=//p' | tail -n 1)"
WORKFLOW_PHASE="$(printf '%s\n' "$REGISTER_OUTPUT" | sed -n 's/^WORKFLOW_PHASE=//p' | tail -n 1)"
WORKFLOW_STATUS="$(printf '%s\n' "$REGISTER_OUTPUT" | sed -n 's/^WORKFLOW_STATUS=//p' | tail -n 1)"
AUTH_METHOD="$(printf '%s\n' "$REGISTER_OUTPUT" | sed -n 's/^AUTH_METHOD=//p' | tail -n 1)"
FAILURE_CATEGORY="$(printf '%s\n' "$REGISTER_OUTPUT" | sed -n 's/^FAILURE_CATEGORY=//p' | tail -n 1)"
MANUAL_ACTION="$(printf '%s\n' "$REGISTER_OUTPUT" | sed -n 's/^MANUAL_ACTION=//p' | tail -n 1)"
IMPORT_ELIGIBLE="$(printf '%s\n' "$REGISTER_OUTPUT" | sed -n 's/^IMPORT_ELIGIBLE=//p' | tail -n 1)"
LAST_SEEN_URL_HOST_PATH="$(printf '%s\n' "$REGISTER_OUTPUT" | sed -n 's/^LAST_SEEN_URL_HOST_PATH=//p' | tail -n 1)"

if [[ -z "$REGISTERED_EMAIL" ]]; then
  LOG_STATUS="terminal_failure"
  LOG_PHASE="register"
  LOG_FAILURE_CATEGORY="parse_failure"
  LOG_MANUAL_ACTION="review_legacy_row"
  printf 'failed to parse registration output\n' >&2
  printf '%s\n' "$REGISTER_OUTPUT" >&2
  exit 1
fi

LOG_EMAIL="$REGISTERED_EMAIL"
LOG_PASSWORD="$PASSWORD"
LOG_STATUS="${WORKFLOW_STATUS:-retryable_failure}"
LOG_AUTH_METHOD="${AUTH_METHOD:-unknown}"
LOG_PHASE="${WORKFLOW_PHASE:-register}"
LOG_FAILURE_CATEGORY="${FAILURE_CATEGORY:-}"
LOG_MANUAL_ACTION="${MANUAL_ACTION:-none}"
LOG_URL="${LAST_SEEN_URL_HOST_PATH:-}"
if [[ "$LOG_STATUS" == "retryable_failure" ]]; then
  LOG_RETRY_ARGS=(--increment-retry-count)
else
  LOG_RETRY_ARGS=(--retry-count 0)
fi
sync_csv

if [[ "$REGISTER_EXIT" -ne 0 ]]; then
  printf '%s\n' "$REGISTER_OUTPUT" >&2
  exit "$REGISTER_EXIT"
fi

if [[ "$IMPORT_AFTER_REGISTER" != "1" ]]; then
  printf 'REGISTERED_EMAIL=%s\n' "$REGISTERED_EMAIL"
  printf 'PASSWORD=%s\n' "$PASSWORD"
  printf 'WORKFLOW_PHASE=%s\n' "$LOG_PHASE"
  printf 'WORKFLOW_STATUS=%s\n' "$LOG_STATUS"
  printf 'AUTH_METHOD=%s\n' "$LOG_AUTH_METHOD"
  printf 'FAILURE_CATEGORY=%s\n' "$LOG_FAILURE_CATEGORY"
  printf 'MANUAL_ACTION=%s\n' "$LOG_MANUAL_ACTION"
  printf 'IMPORT_ELIGIBLE=%s\n' "${IMPORT_ELIGIBLE:-0}"
  exit 0
fi

if [[ "${IMPORT_ELIGIBLE:-0}" != "1" ]]; then
  printf 'REGISTERED_EMAIL=%s\n' "$REGISTERED_EMAIL"
  printf 'PASSWORD=%s\n' "$PASSWORD"
  printf 'IMPORT_SKIPPED_REASON=not_import_eligible\n'
  printf 'WORKFLOW_PHASE=%s\n' "$LOG_PHASE"
  printf 'WORKFLOW_STATUS=%s\n' "$LOG_STATUS"
  printf 'AUTH_METHOD=%s\n' "$LOG_AUTH_METHOD"
  printf 'MANUAL_ACTION=%s\n' "$LOG_MANUAL_ACTION"
  exit 1
fi

if [[ "$REGISTRATION_SETTLE_SECS" =~ ^[0-9]+$ ]] && (( REGISTRATION_SETTLE_SECS > 0 )); then
  sleep "$REGISTRATION_SETTLE_SECS"
fi

if ! IMPORT_OUTPUT="$(CODEX_CSV_PATH="$CSV_PATH" CODEX_CSV_EMAIL="$REGISTERED_EMAIL" CODEX_AUTH_URL_FILE="$AUTH_URL_FILE" OPENAI_EMAIL="$REGISTERED_EMAIL" OPENAI_PASSWORD="$PASSWORD" "$IMPORT_SCRIPT" 2>&1)"; then
  if [[ -f "$AUTH_URL_FILE" ]]; then
    LOG_URL="$(cat "$AUTH_URL_FILE")"
  fi
  LOG_PHASE="import"
  LOG_STATUS="$(printf '%s\n' "$IMPORT_OUTPUT" | sed -n 's/^WORKFLOW_STATUS=//p' | tail -n 1)"
  LOG_FAILURE_CATEGORY="$(printf '%s\n' "$IMPORT_OUTPUT" | sed -n 's/^IMPORT_FAILURE_CATEGORY=//p' | tail -n 1)"
  LOG_MANUAL_ACTION="$(printf '%s\n' "$IMPORT_OUTPUT" | sed -n 's/^MANUAL_ACTION=//p' | tail -n 1)"
  LOG_AUTH_METHOD="$(printf '%s\n' "$IMPORT_OUTPUT" | sed -n 's/^AUTH_METHOD=//p' | tail -n 1)"
  LAST_SEEN_URL_HOST_PATH="$(printf '%s\n' "$IMPORT_OUTPUT" | sed -n 's/^LAST_SEEN_URL_HOST_PATH=//p' | tail -n 1)"
  if [[ -n "$LAST_SEEN_URL_HOST_PATH" ]]; then
    LOG_URL="$LAST_SEEN_URL_HOST_PATH"
  fi
  if [[ "$LOG_STATUS" == "retryable_failure" ]]; then
    LOG_RETRY_ARGS=(--increment-retry-count)
  else
    LOG_RETRY_ARGS=(--retry-count 0)
  fi
  sync_csv
  printf '%s\n' "$IMPORT_OUTPUT" >&2
  exit 1
fi

if [[ -f "$AUTH_URL_FILE" ]]; then
  LOG_URL="$(cat "$AUTH_URL_FILE")"
fi
LOG_PHASE="import"
LOG_STATUS="completed"
LOG_FAILURE_CATEGORY=""
LOG_MANUAL_ACTION="none"
LOG_RETRY_ARGS=(--retry-count 0)
sync_csv

printf 'REGISTERED_EMAIL=%s\n' "$REGISTERED_EMAIL"
printf 'PASSWORD=%s\n' "$PASSWORD"
printf '%s\n' "$IMPORT_OUTPUT"
