#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUTH_URL_SCRIPT="$ROOT_DIR/scripts/get_codexbar_auth_url.swift"
COPY_AUTH_URL_SCRIPT="$ROOT_DIR/scripts/copy_codexbar_auth_url.swift"
SAFARI_AUTH_URL_SCRIPT="$ROOT_DIR/scripts/get_codexbar_safari_auth_url.applescript"
LAUNCH_CHROME_SCRIPT="$ROOT_DIR/scripts/launch_chrome_cdp.sh"
CDP_EVAL_SCRIPT="$ROOT_DIR/scripts/chrome_cdp_eval.mjs"
CDP_NAVIGATE_SCRIPT="$ROOT_DIR/scripts/chrome_cdp_navigate.mjs"
MAIL_CODE_SCRIPT="$ROOT_DIR/chatgpt-anon-register/scripts/get_latest_openai_code.applescript"
CSV_STATE_HELPER="$ROOT_DIR/scripts/codex_csv_state.py"
IMPORT_AUTH_MODE_HELPER="$ROOT_DIR/scripts/import_auth_mode.sh"
CODEXBAR_APP="${CODEXBAR_APP:-/Applications/codexbar.app}"
OPENAI_EMAIL="${OPENAI_EMAIL:-}"
OPENAI_PASSWORD="${OPENAI_PASSWORD:-}"
CODEX_AUTH_URL_FILE="${CODEX_AUTH_URL_FILE:-}"
CODEX_CSV_PATH="${CODEX_CSV_PATH:-}"
CODEX_CSV_EMAIL="${CODEX_CSV_EMAIL:-$OPENAI_EMAIL}"
ACCOUNT_NAME="${ACCOUNT_NAME:-}"
BIRTH_YEAR="${BIRTH_YEAR:-}"
BIRTH_MONTH="${BIRTH_MONTH:-}"
BIRTH_DAY="${BIRTH_DAY:-}"
AGE="${AGE:-}"
KEEP_CHROME_CDP="${KEEP_CHROME_CDP:-0}"
ALLOW_SAFARI_AUTH_URL_FALLBACK="${ALLOW_SAFARI_AUTH_URL_FALLBACK:-0}"
TEST_OAUTH_NAV_ONLY="${TEST_OAUTH_NAV_ONLY:-0}"
CDP_PORT="${CDP_PORT:-}"
CHROME_USER_DATA_DIR="${CHROME_USER_DATA_DIR:-}"
INVALID_STATE_RETRY_LIMIT="${INVALID_STATE_RETRY_LIMIT:-2}"
IMPORT_OBSERVATION_LOG="${IMPORT_OBSERVATION_LOG:-$HOME/.codexbar/register-import-observations.jsonl}"
ALLOW_ABOUT_YOU_AUTOFILL="${ALLOW_ABOUT_YOU_AUTOFILL:-0}"

source "$IMPORT_AUTH_MODE_HELPER"
PREFER_EMAIL_OTP_LOGIN="$(resolve_prefer_email_otp_login "${PREFER_EMAIL_OTP_LOGIN-}" "$OPENAI_PASSWORD")"
IMPORT_AUTH_METHOD="$(resolve_import_auth_method "$OPENAI_PASSWORD" "$PREFER_EMAIL_OTP_LOGIN" "0")"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'missing required command: %s\n' "$1" >&2
    exit 127
  }
}

extract_eval_json() {
  python3 -c '
import json
import re
import sys

text = sys.stdin.read()
payload = text
match = re.search(r"^\s*(\{.*|\[.*|\".*\")\s*$", text, re.S)
if match:
    payload = match.group(1)
decoded = json.loads(payload)
if isinstance(decoded, str):
    print(decoded)
else:
    print(json.dumps(decoded, ensure_ascii=False))
'
}

load_state_vars() {
  local json_text="$1"
  eval "$(
    python3 - "$json_text" <<'PY'
import json
import shlex
import sys

state = json.loads(sys.argv[1])
for key, value in state.items():
    name = key.upper()
    if isinstance(value, bool):
        print(f"{name}={'1' if value else '0'}")
    elif value is None:
        print(f"{name}=''")
    else:
        print(f"{name}={shlex.quote(str(value))}")
PY
  )"
}

latest_code() {
  osascript "$MAIL_CODE_SCRIPT" 2>/dev/null | tr -d '\r\n'
}

wait_for_new_code() {
  local baseline="$1"
  local timeout_secs="${2:-60}"
  local code=""
  local deadline=$((SECONDS + timeout_secs))

  while (( SECONDS < deadline )); do
    code="$(latest_code || true)"
    if [[ "$code" =~ ^[0-9]{6}$ && "$code" != "$baseline" ]]; then
      printf '%s\n' "$code"
      return 0
    fi
    sleep 3
  done

  return 1
}

wait_for_auth_url() {
  swift "$AUTH_URL_SCRIPT" 2>/dev/null
}

copy_auth_url() {
  swift "$COPY_AUTH_URL_SCRIPT" 2>/dev/null
}

wait_for_safari_auth_url() {
  osascript "$SAFARI_AUTH_URL_SCRIPT" 2>/dev/null
}

wait_for_account_import() {
  local email="$1"
  local timeout_secs="${2:-120}"
  local deadline=$((SECONDS + timeout_secs))
  local config_path="${HOME}/.codexbar/config.json"

  while (( SECONDS < deadline )); do
    if python3 - "$email" "$config_path" <<'PY'
import json, sys

target = sys.argv[1]
config_path = sys.argv[2]

with open(config_path, 'r', encoding='utf-8') as fh:
    config = json.load(fh)

for provider in config.get("providers", []):
    for item in provider.get("accounts", []):
        if item.get("email") == target:
            raise SystemExit(0)
raise SystemExit(1)
PY
    then
      return 0
    fi
    sleep 1
  done

  printf 'timed out waiting for Codexbar to import account %s\n' "$email" >&2
  return 1
}

update_codex_csv_url() {
  [[ -n "$CODEX_CSV_PATH" && -n "$CODEX_CSV_EMAIL" ]] || return 0
  python3 "$CSV_STATE_HELPER" set-url "$CODEX_CSV_PATH" --email "$CODEX_CSV_EMAIL" --url "$1"
}

find_free_port() {
  python3 - <<'PY'
import socket
s = socket.socket()
s.bind(("127.0.0.1", 0))
print(s.getsockname()[1])
s.close()
PY
}

cdp_eval_json() {
  local expr="$1"
  CDP_PORT="$CDP_PORT" CDP_JS_EXPR="$expr" node "$CDP_EVAL_SCRIPT" | extract_eval_json
}

run_cdp() {
  local expr="$1"
  CDP_PORT="$CDP_PORT" CDP_JS_EXPR="$expr" node "$CDP_EVAL_SCRIPT" >/dev/null
}

navigate_cdp() {
  local url="$1"
  CDP_PORT="$CDP_PORT" CDP_NAV_URL="$url" node "$CDP_NAVIGATE_SCRIPT"
}

current_state_json() {
  cdp_eval_json "$(cat <<'JS'
() => {
  const bodyText = (document.body?.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 7000);
  const lowered = bodyText.toLowerCase();
  const visible = (el) => {
    if (!el) return false;
    const style = window.getComputedStyle(el);
    const rect = el.getBoundingClientRect();
    return style.display !== 'none' && style.visibility !== 'hidden' && rect.width > 0 && rect.height > 0;
  };
  const inputs = [...document.querySelectorAll('input, textarea, [role="spinbutton"]')].filter(visible);
  const attrs = (el) => [
    el.getAttribute('aria-label') || '',
    el.getAttribute('placeholder') || '',
    el.getAttribute('name') || '',
    el.getAttribute('autocomplete') || '',
    el.id || '',
    el.textContent || '',
    el.value || '',
  ].join(' ').toLowerCase();

  return {
    href: location.href,
    urlHostPath: `${location.origin}${location.pathname}`,
    title: document.title,
    bodyText,
    emailInput: inputs.some((el) => /电子邮件地址|email/.test(attrs(el))),
    passwordInput: inputs.some((el) => /密码|password/.test(attrs(el)) || (el.matches && el.matches('input[type="password"]'))),
    codeInput: inputs.some((el) => /验证码|code/.test(attrs(el)) || String(el.maxLength) === '6' || String(el.maxLength) === '1' || (el.matches && el.matches('input[autocomplete="one-time-code"]'))),
    otpLoginOption: /使用一次性验证码登录|one-time passcode|one-time code|email code/.test(lowered),
    consentContinue: /sign-in-with-chatgpt\/codex\/consent/.test(location.href) || ((/允许|授权|继续/.test(lowered)) && /codex|openai/.test(lowered)),
    callbackPage: /localhost:1455\/auth\/callback/.test(location.href),
    addPhone: /\/add-phone/.test(location.href) || /电话号码是必填项|添加电话号码|phone number is required|verify phone/.test(lowered),
    invalidStateError: /invalid_state/.test(location.href + ' ' + lowered) || /验证过程中出错/.test(lowered),
    captchaChallenge: /captcha|verify you are human|robot|真人验证|人机验证/.test(lowered),
    manualReview: /manual review|review your request|suspicious|unusual activity|我们需要进一步审核|需要进一步审核|可疑|异常活动/.test(lowered),
    aboutYouBlock: inputs.some((el) => /全名|姓名|full name|name|年龄|(^|[^a-z])age([^a-z]|$)|(^|[^a-z])year([^a-z]|$)|(^|[^a-z])month([^a-z]|$)|(^|[^a-z])day([^a-z]|$)|年, |月, |日, /.test(attrs(el))),
    ageInput: inputs.some((el) => /年龄|(^|[^a-z])age([^a-z]|$)/.test(attrs(el))),
    yearInput: inputs.some((el) => /(^|[^a-z])year([^a-z]|$)|年, /.test(attrs(el))),
    monthInput: inputs.some((el) => /(^|[^a-z])month([^a-z]|$)|月, /.test(attrs(el))),
    dayInput: inputs.some((el) => /(^|[^a-z])day([^a-z]|$)|日, /.test(attrs(el))),
    nameInput: inputs.some((el) => /全名|姓名|full name|name/.test(attrs(el)))
  };
}
JS
)"
}

cleanup_chrome_cdp() {
  if [[ "$KEEP_CHROME_CDP" == "1" ]]; then
    return
  fi

  if [[ -n "${CDP_PORT:-}" ]]; then
    lsof -ti tcp:"$CDP_PORT" | xargs kill >/dev/null 2>&1 || true
  fi
  if [[ -n "${CHROME_USER_DATA_DIR:-}" ]]; then
    for _ in 1 2 3; do
      rm -rf "$CHROME_USER_DATA_DIR" >/dev/null 2>&1 || true
      [[ ! -e "$CHROME_USER_DATA_DIR" ]] && break
      sleep 1
    done
  fi
}

classify_import_failure() {
  local detail="$1"
  local reason="${2:-$stop_reason}"
  local combined=""

  combined="${reason}"$'\n'"${detail}"

  if [[ "$combined" == *"phone_verification_required"* || "$combined" == *"/add-phone"* || "$combined" == *"phone verification"* || "$combined" == *"verify phone"* ]]; then
    printf 'phone_verification\n'
    return
  fi

  if [[ "$combined" == *"captcha_challenge"* || "$combined" == *"verify you are human"* || "$combined" == *"真人验证"* || "$combined" == *"人机验证"* ]]; then
    printf 'captcha_challenge\n'
    return
  fi

  if [[ "$combined" == *"invalid_state"* || "$combined" == *"验证过程中出错"* ]]; then
    printf 'invalid_state\n'
    return
  fi

  if [[ "$combined" == *"manual_review"* || "$combined" == *"review your request"* || "$combined" == *"异常活动"* ]]; then
    printf 'manual_review\n'
    return
  fi

  if [[ "$combined" == *"mail_code_timeout"* || "$combined" == *"waiting for a new openai email code"* ]]; then
    printf 'mail_code_timeout\n'
    return
  fi

  if [[ "$combined" == *"about_you_block"* || "$combined" == *"full name"* || "$combined" == *"年龄"* ]]; then
    printf 'about_you_block\n'
    return
  fi

  if [[ "$combined" == *"failed to read the Codexbar OAuth URL"* ]]; then
    printf 'auth_url_capture_failed\n'
    return
  fi

  if [[ "$combined" == *"No page target found for CDP evaluation"* || "$combined" == *"Couldn't connect to server"* || "$combined" == *"Failed to connect to 127.0.0.1 port"* || "$combined" == *"remote-debugging-port"* || "$combined" == *"CDP evaluation"* || "$combined" == *"CDP navigation"* ]]; then
    printf 'cdp_race\n'
    return
  fi

  printf 'provider_timeout\n'
}

record_import_observation() {
  local outcome="$1"
  local category="$2"
  local workflow_status="$3"
  local manual_action="$4"
  local current_url_host_path="$5"
  local detail="${6:-}"

  python3 - "$IMPORT_OBSERVATION_LOG" "$OPENAI_EMAIL" "$outcome" "$category" "$AUTH_URL_SOURCE" "$stop_reason" "$workflow_status" "$manual_action" "$current_url_host_path" "$detail" "$SECONDS" "$IMPORT_AUTH_METHOD" <<'PY'
import datetime as dt
import json
import os
import re
import sys

(
    path,
    email,
    outcome,
    category,
    auth_url_source,
    stop_reason,
    workflow_status,
    manual_action,
    current_url_host_path,
    detail,
    duration,
    auth_method,
) = sys.argv[1:]
parent = os.path.dirname(path)
if parent:
    os.makedirs(parent, exist_ok=True)

redacted_detail = re.sub(r"https?://[^\s]+", "[redacted-url]", detail)
record = {
    "timestamp": dt.datetime.now(dt.timezone.utc).isoformat(),
    "email": email,
    "phase": "import",
    "outcome": outcome,
    "category": category,
    "auth_url_source": auth_url_source,
    "stop_reason": stop_reason,
    "workflow_status": workflow_status,
    "auth_method": auth_method,
    "manual_action": manual_action,
    "last_seen_url_host_path": current_url_host_path,
    "control_path": "cdp",
    "duration_secs": duration,
    "detail": redacted_detail[:1000],
}

with open(path, "a", encoding="utf-8") as fh:
    fh.write(json.dumps(record, ensure_ascii=False) + "\n")
PY
}

exit_with_classified_failure() {
  local detail="$1"
  local category=""
  local workflow_status="${2:-retryable_failure}"
  local manual_action="${3:-retry_after_local_fix}"
  local current_url_host_path="${4:-}"

  category="$(classify_import_failure "$detail")"
  printf 'IMPORT_FAILURE_CATEGORY=%s\n' "$category" >&2
  printf 'AUTH_METHOD=%s\n' "$IMPORT_AUTH_METHOD" >&2
  printf 'WORKFLOW_PHASE=import\n' >&2
  printf 'WORKFLOW_STATUS=%s\n' "$workflow_status" >&2
  printf 'MANUAL_ACTION=%s\n' "$manual_action" >&2
  if [[ -n "$current_url_host_path" ]]; then
    printf 'LAST_SEEN_URL_HOST_PATH=%s\n' "$current_url_host_path" >&2
  fi
  record_import_observation "failure" "$category" "$workflow_status" "$manual_action" "$current_url_host_path" "$detail"
  printf '%s\n' "$detail" >&2
  exit 1
}

run_cdp_or_fail() {
  local expr="$1"
  local context="$2"
  local output=""

  if ! output="$(CDP_PORT="$CDP_PORT" CDP_JS_EXPR="$expr" node "$CDP_EVAL_SCRIPT" 2>&1 >/dev/null)"; then
    exit_with_classified_failure "$context"$'\n'"$output"
  fi
}

trap cleanup_chrome_cdp EXIT

if [[ -z "$OPENAI_EMAIL" ]]; then
  printf 'usage: OPENAI_EMAIL=<email> [OPENAI_PASSWORD=<password>] %s\n' "$0" >&2
  exit 64
fi

require_cmd node
require_cmd open
require_cmd swift
require_cmd osascript
require_cmd python3

if [[ -z "$AGE" && "$BIRTH_YEAR" =~ ^[0-9]{4}$ ]]; then
  AGE="$(( $(date +%Y) - BIRTH_YEAR ))"
fi

ACCOUNT_NAME_JS="${ACCOUNT_NAME//\\/\\\\}"
ACCOUNT_NAME_JS="${ACCOUNT_NAME_JS//\"/\\\"}"
BIRTH_YEAR_JS="${BIRTH_YEAR//\\/\\\\}"
BIRTH_YEAR_JS="${BIRTH_YEAR_JS//\"/\\\"}"
BIRTH_MONTH_JS="${BIRTH_MONTH//\\/\\\\}"
BIRTH_MONTH_JS="${BIRTH_MONTH_JS//\"/\\\"}"
BIRTH_DAY_JS="${BIRTH_DAY//\\/\\\\}"
BIRTH_DAY_JS="${BIRTH_DAY_JS//\"/\\\"}"
AGE_JS="${AGE//\\/\\\\}"
AGE_JS="${AGE_JS//\"/\\\"}"
EMAIL_JS="${OPENAI_EMAIL//\\/\\\\}"
EMAIL_JS="${EMAIL_JS//\"/\\\"}"
PASSWORD_JS="${OPENAI_PASSWORD//\\/\\\\}"
PASSWORD_JS="${PASSWORD_JS//\"/\\\"}"

osascript -e 'tell application id "lzhl.codexAppBar" to activate' >/dev/null 2>&1 || open -a "$CODEXBAR_APP"
sleep 1
open 'com.codexbar.oauth://login'

AUTH_URL=""
AUTH_URL_SOURCE=""
for _ in $(seq 1 80); do
  AUTH_URL="$(copy_auth_url || true)"
  if [[ -n "$AUTH_URL" ]]; then
    AUTH_URL_SOURCE="popup_copy"
    break
  fi
  AUTH_URL="$(wait_for_auth_url || true)"
  if [[ -n "$AUTH_URL" ]]; then
    AUTH_URL_SOURCE="popup_ax"
    break
  fi
  if [[ "$ALLOW_SAFARI_AUTH_URL_FALLBACK" == "1" ]]; then
    AUTH_URL="$(wait_for_safari_auth_url || true)"
    if [[ -n "$AUTH_URL" ]]; then
      AUTH_URL_SOURCE="safari_fallback"
      break
    fi
  fi
  sleep 0.5
done

if [[ -z "$AUTH_URL" ]]; then
  if [[ "$ALLOW_SAFARI_AUTH_URL_FALLBACK" == "1" ]]; then
    exit_with_classified_failure 'failed to read the Codexbar OAuth URL from the popup or Safari fallback'
  else
    exit_with_classified_failure 'failed to read the Codexbar OAuth URL from the popup'
  fi
fi

AUTH_URL="$(printf '%s' "$AUTH_URL" | tr -d '\r\n')"

printf 'AUTH_URL_SOURCE=%s\n' "$AUTH_URL_SOURCE"
if [[ -n "$CODEX_AUTH_URL_FILE" ]]; then
  printf '%s\n' "$AUTH_URL" >"$CODEX_AUTH_URL_FILE"
fi
update_codex_csv_url "$AUTH_URL"

if [[ -z "$CDP_PORT" ]]; then
  CDP_PORT="$(find_free_port)"
fi
if [[ -z "$CHROME_USER_DATA_DIR" ]]; then
  CHROME_USER_DATA_DIR="/tmp/codexbar-cdp-${CDP_PORT}"
fi

if ! launch_output="$(PORT="$CDP_PORT" USER_DATA_DIR="$CHROME_USER_DATA_DIR" "$LAUNCH_CHROME_SCRIPT" 2>&1 >/dev/null)"; then
  exit_with_classified_failure "failed to launch Chrome CDP session"$'\n'"$launch_output"
fi

if ! NAVIGATION_JSON="$(navigate_cdp "$AUTH_URL" 2>&1)"; then
  exit_with_classified_failure "failed to navigate Chrome CDP to the Codexbar OAuth URL"$'\n'"$NAVIGATION_JSON"
fi

if [[ "$TEST_OAUTH_NAV_ONLY" == "1" ]]; then
  NAVIGATION_REQUEST_URL="$(
    python3 - "$NAVIGATION_JSON" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
print(payload.get("requestedURL", ""))
PY
  )"
  printf 'OAUTH_NAVIGATION_VERIFIED=1\n'
  printf 'AUTH_URL=%s\n' "$AUTH_URL"
  printf 'NAVIGATION_REQUEST_URL=%s\n' "$NAVIGATION_REQUEST_URL"
  exit 0
fi

mail_code_baseline="$(latest_code || true)"
code_attempts=0
resend_attempts=0
code_wait_phase="initial_wait"
invalid_state_retries=0
deadline=$((SECONDS + 360))
status="IN_PROGRESS"
stop_reason=""
last_seen_url_host_path=""
manual_action="none"
code_wait_timed_out=0
used_email_otp_login=0

while (( SECONDS < deadline )); do
  if ! STATE_JSON="$(current_state_json 2>&1)"; then
    exit_with_classified_failure "failed to read current browser state from Chrome CDP"$'\n'"$STATE_JSON"
  fi
  load_state_vars "$STATE_JSON"
  last_seen_url_host_path="$URLHOSTPATH"

  if [[ "$CAPTCHACHALLENGE" == "1" ]]; then
    status="BLOCKED"
    stop_reason="captcha_challenge"
    manual_action="complete_provider_challenge"
    break
  fi

  if [[ "$MANUALREVIEW" == "1" ]]; then
    status="BLOCKED"
    stop_reason="manual_review"
    manual_action="complete_provider_challenge"
    break
  fi

  if [[ "$ABOUTYOUBLOCK" == "1" ]]; then
    if [[ "$ALLOW_ABOUT_YOU_AUTOFILL" != "1" || -z "$ACCOUNT_NAME" || -z "$BIRTH_YEAR" || -z "$BIRTH_MONTH" || -z "$BIRTH_DAY" ]]; then
      status="BLOCKED"
      stop_reason="about_you_block"
      manual_action="finish_about_you"
      break
    fi
  fi

  if [[ "$CALLBACKPAGE" == "1" ]]; then
    if wait_for_account_import "$OPENAI_EMAIL" 120; then
      status="IMPORTED"
      break
    fi
  fi

  if [[ "$ADDPHONE" == "1" ]]; then
    status="BLOCKED"
    stop_reason="phone_verification_required"
    break
  fi

  if [[ "$INVALIDSTATEERROR" == "1" ]]; then
    if (( invalid_state_retries < INVALID_STATE_RETRY_LIMIT )); then
      run_cdp_or_fail "$(cat <<'JS'
() => {
  const btn = [...document.querySelectorAll('button, a')].find((el) => /^(重试|Retry)$/i.test((el.innerText || '').trim()));
  if (!btn) throw new Error('invalid_state retry button not found');
  btn.click();
  return true;
}
JS
)" 'failed to click the invalid_state retry action'
      ((invalid_state_retries += 1))
      sleep 3
      continue
    fi

    status="BLOCKED"
    stop_reason="invalid_state"
    break
  fi

  if [[ "$CONSENTCONTINUE" == "1" ]]; then
    run_cdp_or_fail "$(cat <<'JS'
() => {
  const text = ['继续', 'Continue', 'Allow', '允许', 'Authorize'];
  const buttons = [...document.querySelectorAll('button')];
  const btn = buttons.find((el) => text.includes((el.innerText || '').trim()));
  if (btn) btn.click();
  return true;
}
JS
)" 'failed to click the Codex consent continue action'
    sleep 2
    if wait_for_account_import "$OPENAI_EMAIL" 120; then
      status="IMPORTED"
      break
    fi
    continue
  fi

  if should_use_email_otp_login "$PREFER_EMAIL_OTP_LOGIN" "$OTPLOGINOPTION"; then
    used_email_otp_login=1
    IMPORT_AUTH_METHOD="$(resolve_import_auth_method "$OPENAI_PASSWORD" "$PREFER_EMAIL_OTP_LOGIN" "$OTPLOGINOPTION")"
    run_cdp_or_fail "$(cat <<'JS'
() => {
  const buttons = [...document.querySelectorAll('button')];
  const btn = buttons.find((el) => /使用一次性验证码登录|one-time passcode|one-time code/i.test((el.innerText || '').trim()));
  if (!btn) throw new Error('otp login option not found');
  btn.click();
  return true;
}
JS
)" 'failed to switch the OpenAI login flow to email OTP'
    sleep 2
    continue
  fi

  if [[ "$CODEINPUT" == "1" ]]; then
    wait_timeout=60
    if [[ "$code_wait_phase" == "resent_wait" ]]; then
      wait_timeout=75
    fi

    CODE="$(wait_for_new_code "$mail_code_baseline" "$wait_timeout" || true)"
    if [[ "$CODE" =~ ^[0-9]{6}$ ]]; then
      mail_code_baseline="$CODE"
      ((code_attempts += 1))
      CODE_JS="${CODE//\\/\\\\}"
      CODE_JS="${CODE_JS//\"/\\\"}"

      run_cdp_or_fail "$(cat <<JS
() => {
  const code = "$CODE_JS";
  const inputs = [...document.querySelectorAll('input')];
  const multi = inputs.filter((el) => el.maxLength === 1);
  const setInputValue = (input, value) => {
    const proto = input instanceof HTMLTextAreaElement ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
    const setter = Object.getOwnPropertyDescriptor(proto, 'value')?.set;
    if (!setter) throw new Error('missing native value setter');
    setter.call(input, value);
    input.dispatchEvent(new InputEvent('input', { bubbles: true, data: value, inputType: 'insertText' }));
    input.dispatchEvent(new Event('change', { bubbles: true }));
  };
  let verified = false;
  if (multi.length >= 6) {
    for (let i = 0; i < 6; i++) {
      setInputValue(multi[i], code[i]);
    }
    verified = multi.slice(0, 6).map((el) => el.value).join('') === code;
  } else {
    const field = inputs.find((el) => /验证码|code/.test([el.placeholder, el.getAttribute('aria-label'), el.name].join(' ')));
    const target = field || inputs[0];
    if (target) {
      setInputValue(target, code);
      verified = target.value === code;
    }
  }
  if (!verified) {
    throw new Error('verification code was not written into the page before submit');
  }
  const btn = [...document.querySelectorAll('button')].find((el) => /^(继续|Continue|Verify|提交|Submit)$/.test((el.innerText || '').trim()));
  if (btn) btn.click();
  return true;
}
JS
)" 'failed while writing or submitting the OpenAI email verification code'
      sleep 3
      code_wait_phase="initial_wait"
      continue
    fi

    if (( resend_attempts < 2 )); then
      if ! resend_output="$(CDP_PORT="$CDP_PORT" CDP_JS_EXPR="$(cat <<'JS'
() => {
  const btn = [...document.querySelectorAll('button, a')].find((el) => /重新发送|resend/i.test((el.innerText || '').trim()));
  if (btn) btn.click();
  return true;
}
JS
)" node "$CDP_EVAL_SCRIPT" 2>&1 >/dev/null)"; then
        printf 'IMPORT_RETRY_NOTE=resend_click_failed\n' >&2
        printf '%s\n' "$resend_output" >&2
      fi
      ((resend_attempts += 1))
      code_wait_phase="resent_wait"
      sleep 5
      continue
    fi
    code_wait_timed_out=1
    sleep 3
    continue
  fi

  if [[ "$PASSWORDINPUT" == "1" && -n "$OPENAI_PASSWORD" ]]; then
    run_cdp_or_fail "$(cat <<JS
() => {
  const field = [...document.querySelectorAll('input')].find((el) => el.type === 'password');
  if (field) {
    field.value = "$PASSWORD_JS";
    field.dispatchEvent(new Event('input', { bubbles: true }));
    field.dispatchEvent(new Event('change', { bubbles: true }));
  }
  const btn = [...document.querySelectorAll('button')].find((el) => /^(继续|Continue)$/.test((el.innerText || '').trim()));
  if (btn) btn.click();
  return true;
}
JS
)" 'failed to fill or submit the OpenAI password form'
    sleep 2
    continue
  fi

  if [[ "$EMAILINPUT" == "1" ]]; then
    run_cdp_or_fail "$(cat <<JS
() => {
  const inputs = [...document.querySelectorAll('input')];
  const field = inputs.find((el) => /电子邮件地址|email/.test([el.placeholder, el.getAttribute('aria-label'), el.name, el.value].join(' ')));
  const target = field || inputs[0];
  if (!target) throw new Error('email input not found');
  target.focus();
  target.value = "$EMAIL_JS";
  target.dispatchEvent(new Event('input', { bubbles: true }));
  target.dispatchEvent(new Event('change', { bubbles: true }));
  const btn = [...document.querySelectorAll('button')].find((el) => /^(继续|Continue|Next|下一步)$/.test((el.innerText || '').trim()));
  if (btn) {
    btn.click();
    return true;
  }
  throw new Error('continue button not found on codexbar email step');
}
JS
)" 'failed to fill or submit the OpenAI email form'
    sleep 2
    continue
  fi

  if [[ "$ALLOW_ABOUT_YOU_AUTOFILL" == "1" && ( "$AGEINPUT" == "1" || "$YEARINPUT" == "1" || "$NAMEINPUT" == "1" ) ]]; then
    run_cdp_or_fail "$(cat <<JS
() => {
  const fullName = "$ACCOUNT_NAME_JS";
  const age = "$AGE_JS";
  const year = "$BIRTH_YEAR_JS";
  const month = "$BIRTH_MONTH_JS";
  const day = "$BIRTH_DAY_JS";

  const inputs = [...document.querySelectorAll('input, [role=\"spinbutton\"]')];
  const findVisible = (pred) => inputs.find((el) => {
    const style = window.getComputedStyle(el);
    const rect = el.getBoundingClientRect();
    return style.display !== 'none' && style.visibility !== 'hidden' && rect.width > 0 && rect.height > 0 && pred(el);
  });

  const nameField = findVisible((el) => /全名|姓名|full name|name/.test([el.placeholder, el.getAttribute('aria-label'), el.name].join(' ')));
  if (nameField) {
    nameField.value = fullName;
    nameField.dispatchEvent(new Event('input', { bubbles: true }));
    nameField.dispatchEvent(new Event('change', { bubbles: true }));
  }

  const ageField = findVisible((el) => /年龄|(^|[^a-z])age([^a-z]|$)/.test([el.placeholder, el.getAttribute('aria-label'), el.name].join(' ')));
  if (ageField) {
    ageField.value = age;
    ageField.dispatchEvent(new Event('input', { bubbles: true }));
    ageField.dispatchEvent(new Event('change', { bubbles: true }));
  } else {
    const yearSeg = findVisible((el) => /(^|[^a-z])year([^a-z]|$)|年, /.test([el.getAttribute('aria-label'), el.textContent, el.getAttribute('role')].join(' ')));
    if (yearSeg) {
      yearSeg.focus();
      document.execCommand && document.execCommand('selectAll', false, null);
      const hidden = document.querySelector('input[name=\"birthday\"]');
      if (hidden) {
        hidden.value = year + '-' + month + '-' + day;
        hidden.dispatchEvent(new Event('input', { bubbles: true }));
        hidden.dispatchEvent(new Event('change', { bubbles: true }));
      }
    }
  }

  const btn = [...document.querySelectorAll('button')].find((el) => /完成帐户创建|完成账户创建|create account|continue|继续/i.test((el.innerText || '').trim()));
  if (btn) btn.click();
  return true;
}
JS
)" 'failed to fill the OpenAI about-you form'
    sleep 3
    continue
  fi

  sleep 2
done

if [[ "$status" != "IMPORTED" ]]; then
  if [[ "$stop_reason" == "phone_verification_required" ]]; then
    exit_with_classified_failure "Codexbar import blocked by OpenAI phone verification for $OPENAI_EMAIL" "manual_required" "complete_provider_challenge" "$last_seen_url_host_path"
  elif [[ "$stop_reason" == "invalid_state" ]]; then
    exit_with_classified_failure "Codexbar import hit an OpenAI invalid_state error for $OPENAI_EMAIL" "retryable_failure" "retry_after_local_fix" "$last_seen_url_host_path"
  elif [[ "$stop_reason" == "captcha_challenge" ]]; then
    exit_with_classified_failure "Codexbar import blocked by captcha challenge for $OPENAI_EMAIL" "manual_required" "complete_provider_challenge" "$last_seen_url_host_path"
  elif [[ "$stop_reason" == "manual_review" ]]; then
    exit_with_classified_failure "Codexbar import requires manual review for $OPENAI_EMAIL" "manual_required" "complete_provider_challenge" "$last_seen_url_host_path"
  elif [[ "$stop_reason" == "about_you_block" ]]; then
    exit_with_classified_failure "Codexbar import requires about-you completion for $OPENAI_EMAIL" "manual_required" "finish_about_you" "$last_seen_url_host_path"
  elif [[ "$code_wait_timed_out" == "1" ]]; then
    stop_reason="mail_code_timeout"
    exit_with_classified_failure "timed out waiting for a new OpenAI email code while importing $OPENAI_EMAIL" "retryable_failure" "retry_after_local_fix" "$last_seen_url_host_path"
  else
    exit_with_classified_failure "timed out while importing $OPENAI_EMAIL into Codexbar" "manual_required" "complete_provider_challenge" "$last_seen_url_host_path"
  fi
fi

printf 'IMPORTED_EMAIL=%s\n' "$OPENAI_EMAIL"
printf 'CDP_PORT=%s\n' "$CDP_PORT"
printf 'AUTH_METHOD=%s\n' "$IMPORT_AUTH_METHOD"
printf 'WORKFLOW_PHASE=import\n'
printf 'WORKFLOW_STATUS=completed\n'
printf 'MANUAL_ACTION=none\n'
printf 'FAILURE_CATEGORY=\n'
if [[ -n "$last_seen_url_host_path" ]]; then
  printf 'LAST_SEEN_URL_HOST_PATH=%s\n' "$last_seen_url_host_path"
fi
record_import_observation "success" "imported" "completed" "none" "$last_seen_url_host_path" "Codexbar import completed successfully"
python3 - <<'PY'
import json
import os

with open(os.path.expanduser('~/.codexbar/config.json'), 'r', encoding='utf-8') as fh:
    config = json.load(fh)

active_provider = config.get("active", {}).get("providerId")
active_account = config.get("active", {}).get("accountId")
accounts = []

for provider in config.get("providers", []):
    if provider.get("kind") != "openai_oauth":
        continue
    for item in provider.get("accounts", []):
        accounts.append({
            "account_id": item.get("openAIAccountId") or item.get("id"),
            "email": item.get("email"),
            "active": provider.get("id") == active_provider and item.get("id") == active_account,
        })

print(json.dumps(accounts, ensure_ascii=False, indent=2))
PY
