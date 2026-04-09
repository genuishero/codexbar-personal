#!/usr/bin/env bash

if [[ -n "${CODEXBAR_IMPORT_AUTH_MODE_HELPER_LOADED:-}" ]]; then
  return 0 2>/dev/null || exit 0
fi
CODEXBAR_IMPORT_AUTH_MODE_HELPER_LOADED=1

resolve_prefer_email_otp_login() {
  local explicit_value="${1-}"
  local password="${2-}"

  if [[ -n "$explicit_value" ]]; then
    printf '%s\n' "$explicit_value"
    return 0
  fi

  if [[ -n "$password" ]]; then
    printf '0\n'
  else
    printf '1\n'
  fi
}

should_use_email_otp_login() {
  local prefer_email_otp="${1-}"
  local otp_option_visible="${2-}"

  [[ "$prefer_email_otp" == "1" && "$otp_option_visible" == "1" ]]
}

resolve_import_auth_method() {
  local password="${1-}"
  local prefer_email_otp="${2-}"
  local otp_option_visible="${3-}"

  if should_use_email_otp_login "$prefer_email_otp" "$otp_option_visible"; then
    printf 'email_otp\n'
    return 0
  fi

  if [[ -n "$password" ]]; then
    printf 'password\n'
  else
    printf 'unknown\n'
  fi
}
