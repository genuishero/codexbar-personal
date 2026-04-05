#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AX_CREATE_SWIFT="$ROOT_DIR/scripts/create_hide_my_email_ax.swift"
HIDE_MY_EMAIL_LABEL="${HIDE_MY_EMAIL_LABEL:-Codex}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'missing required command: %s\n' "$1" >&2
    exit 127
  }
}

require_cmd swift

exec env HIDE_MY_EMAIL_LABEL="$HIDE_MY_EMAIL_LABEL" swift "$AX_CREATE_SWIFT"
