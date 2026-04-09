#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CREATE_AND_IMPORT_SCRIPT="$ROOT_DIR/scripts/create_and_import_openai_account.sh"
TOTAL_ACCOUNTS="${1:-100}"
SUCCESS_COUNT=0
FAILED_COUNT=0
FAILED_ROWS_FILE="$(mktemp)"

cleanup() {
  rm -f "$FAILED_ROWS_FILE"
}

trap cleanup EXIT

printf '开始注册并导入 %s 个账号\n' "$TOTAL_ACCOUNTS"
printf '注册和登录间隔: 180 秒\n'
printf '========================================\n'

for i in $(seq 1 "$TOTAL_ACCOUNTS"); do
  printf '\n[%s/%s] 开始注册账号...\n' "$i" "$TOTAL_ACCOUNTS"
  
  if output="$(REGISTRATION_SETTLE_SECS=180 "$CREATE_AND_IMPORT_SCRIPT" 2>&1)"; then
    printf '%s\n' "$output"
    printf '✅ 账号 %s 注册并导入成功\n' "$i"
    ((SUCCESS_COUNT += 1))
  else
    printf '%s\n' "$output" >&2
    printf '❌ 账号 %s 注册或导入失败\n' "$i"
    ((FAILED_COUNT += 1))
    FAILED_EMAIL="$(printf '%s\n' "$output" | sed -n 's/^REGISTERED_EMAIL=//p' | tail -n 1)"
    FAILED_PHASE="$(printf '%s\n' "$output" | sed -n 's/^WORKFLOW_PHASE=//p' | tail -n 1)"
    FAILED_STATUS="$(printf '%s\n' "$output" | sed -n 's/^WORKFLOW_STATUS=//p' | tail -n 1)"
    FAILED_MANUAL_ACTION="$(printf '%s\n' "$output" | sed -n 's/^MANUAL_ACTION=//p' | tail -n 1)"
    if [[ -n "$FAILED_EMAIL" ]]; then
      printf '%s\t%s\t%s\t%s\n' \
        "$FAILED_EMAIL" \
        "${FAILED_PHASE:-unknown}" \
        "${FAILED_STATUS:-unknown}" \
        "${FAILED_MANUAL_ACTION:-none}" >> "$FAILED_ROWS_FILE"
      printf '   失败详情: %s | phase=%s | status=%s | manual_action=%s\n' \
        "$FAILED_EMAIL" \
        "${FAILED_PHASE:-unknown}" \
        "${FAILED_STATUS:-unknown}" \
        "${FAILED_MANUAL_ACTION:-none}"
    fi
  fi
  
  # 在每次尝试之间稍微停顿,避免过快连续
  if (( i < TOTAL_ACCOUNTS )); then
    printf '等待 10 秒后继续下一个账号...\n'
    sleep 10
  fi
done

printf '\n========================================\n'
printf '任务完成!\n'
printf '成功: %s\n' "$SUCCESS_COUNT"
printf '失败: %s\n' "$FAILED_COUNT"

if (( FAILED_COUNT > 0 )) && [[ -s "$FAILED_ROWS_FILE" ]]; then
  printf '\n失败账号摘要 (email / phase / status / manual_action):\n'
  cat "$FAILED_ROWS_FILE"
fi

if (( FAILED_COUNT > 0 )); then
  exit 1
fi
