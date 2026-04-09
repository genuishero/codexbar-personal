#!/usr/bin/env bash

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGISTER_SCRIPT="$SCRIPT_DIR/create_and_import_openai_account.sh"
RETRY_IMPORT_SCRIPT="$SCRIPT_DIR/retry_codexbar_import_from_csv.sh"
TOTAL_ACCOUNTS=10
FAILED_EMAILS=()
SUCCESS_COUNT=0

for i in $(seq 1 "$TOTAL_ACCOUNTS"); do
  printf '\n========== [%d/%d] Starting registration and import ==========\n' "$i" "$TOTAL_ACCOUNTS"
  
  if output="$(REGISTRATION_SETTLE_SECS=60 "$REGISTER_SCRIPT" 2>&1)"; then
    printf '%s\n' "$output"
    printf '========== [%d/%d] SUCCESS ==========\n' "$i" "$TOTAL_ACCOUNTS"
    ((SUCCESS_COUNT++))
  else
    EXIT_CODE=$?
    printf '%s\n' "$output" >&2
    printf '========== [%d/%d] FAILED (exit %d) - recording for retry ==========\n' "$i" "$TOTAL_ACCOUNTS" "$EXIT_CODE"
    FAILED_EMAIL="$(printf '%s\n' "$output" | sed -n 's/^REGISTERED_EMAIL=//p' | tail -n 1)"
    WORKFLOW_PHASE="$(printf '%s\n' "$output" | sed -n 's/^WORKFLOW_PHASE=//p' | tail -n 1)"
    WORKFLOW_STATUS="$(printf '%s\n' "$output" | sed -n 's/^WORKFLOW_STATUS=//p' | tail -n 1)"
    MANUAL_ACTION="$(printf '%s\n' "$output" | sed -n 's/^MANUAL_ACTION=//p' | tail -n 1)"
    if [[ -n "$FAILED_EMAIL" && "$WORKFLOW_PHASE" == "import" && "$WORKFLOW_STATUS" == "retryable_failure" ]]; then
      FAILED_EMAILS+=("$FAILED_EMAIL")
      printf 'Retry-eligible import failure: %s\n' "$FAILED_EMAIL"
    elif [[ -n "$FAILED_EMAIL" ]]; then
      printf 'Not queued for auto retry: %s | phase=%s | status=%s | manual_action=%s\n' \
        "$FAILED_EMAIL" "${WORKFLOW_PHASE:-unknown}" "${WORKFLOW_STATUS:-unknown}" "${MANUAL_ACTION:-none}"
    fi
  fi
  
  # Add a small delay between registrations to avoid rate limiting
  if (( i < TOTAL_ACCOUNTS )); then
    printf 'Waiting 10 seconds before next registration...\n'
    sleep 10
  fi
done

printf '\n\n========== SUMMARY ==========\n'
printf 'Total attempted: %d\n' "$TOTAL_ACCOUNTS"
printf 'Success: %d\n' "$SUCCESS_COUNT"
printf 'Failed count: %d\n' "${#FAILED_EMAILS[@]}"

if (( ${#FAILED_EMAILS[@]} > 0 )); then
  printf '\nFailed emails (retry-eligible imports only):\n'
  for email in "${FAILED_EMAILS[@]}"; do
    printf '  - %s\n' "$email"
  done
  
  printf '\n\nRetrying helper-approved import failures...\n'
  RETRY_SUCCESS=0
  RETRY_SKIPPED=0
  for email in "${FAILED_EMAILS[@]}"; do
    printf '\nRetrying import for: %s\n' "$email"
    if output="$(EMAIL_FILTER="$email" LOGIN_INTERVAL_SECS=0 "$RETRY_IMPORT_SCRIPT" 2>&1)"; then
      printf '%s\n' "$output"
      if printf '%s\n' "$output" | grep -Eq '^BATCH_IMPORTED_COUNT=[1-9][0-9]*$'; then
        printf 'Retry import for %s: SUCCESS\n' "$email"
        ((RETRY_SUCCESS++))
      else
        printf 'Retry import for %s: SKIPPED (not retry-eligible anymore)\n' "$email"
        ((RETRY_SKIPPED++))
      fi
    else
      printf '%s\n' "$output" >&2
      printf 'Retry import for %s: FAILED\n' "$email" >&2
    fi
  done
  printf '\nRetry summary: %d succeeded, %d skipped, %d total queued\n' \
    "$RETRY_SUCCESS" "$RETRY_SKIPPED" "${#FAILED_EMAILS[@]}"
fi

printf '\n========== ALL DONE ==========\n'
