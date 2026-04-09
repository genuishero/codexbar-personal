#!/usr/bin/env python3

from __future__ import annotations

import argparse
import csv
import json
import os
import shutil
import sys
import tempfile
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable

SCHEMA_VERSION = "v2"
HEADER = [
    "schema_version",
    "email",
    "password",
    "status",
    "url",
    "auth_method",
    "phase",
    "failure_category",
    "manual_action",
    "retry_count",
    "updated_at",
]

KEEP = "__KEEP__"

AUTO_IMPORT_AUTH_METHODS = {"password"}
REGISTER_RETRY_LIMITS = {
    "mail_code_timeout": 1,
    "local_browser_failure": 1,
    "hide_my_email_failed": 1,
    "legacy_register_failure": 1,
}
IMPORT_RETRY_LIMITS = {
    "auth_url_capture_failed": 2,
    "cdp_race": 2,
    "invalid_state": 1,
    "mail_code_timeout": 1,
    "legacy_import_failure": 1,
}


@dataclass
class ImportedAccounts:
    emails: set[str]


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def normalize_text(value: str | None) -> str:
    return (value or "").strip()


def default_row() -> dict[str, str]:
    return {
        "schema_version": SCHEMA_VERSION,
        "email": "",
        "password": "",
        "status": "pending",
        "url": "",
        "auth_method": "unknown",
        "phase": "register",
        "failure_category": "",
        "manual_action": "none",
        "retry_count": "0",
        "updated_at": now_iso(),
    }


def normalize_retry_count(value: str | None) -> str:
    text = normalize_text(value)
    if not text:
        return "0"
    if not text.isdigit():
        return "0"
    return text


def legacy_status_to_row(email: str, password: str, legacy_status: str, url: str) -> dict[str, str]:
    row = default_row()
    row["email"] = email
    row["password"] = password
    row["url"] = url

    if legacy_status == "registered":
        row["phase"] = "register"
        row["status"] = "completed"
        if password:
            row["auth_method"] = "password"
            row["manual_action"] = "none"
        else:
            row["auth_method"] = "email_otp"
            row["manual_action"] = "review_passwordless_account"
        return row

    if legacy_status == "success":
        row["phase"] = "import"
        row["status"] = "completed"
        row["auth_method"] = "password" if password else "unknown"
        row["manual_action"] = "none"
        return row

    if legacy_status == "import_failed":
        row["phase"] = "import"
        row["status"] = "retryable_failure"
        row["auth_method"] = "password" if password else "unknown"
        row["failure_category"] = "legacy_import_failure"
        row["manual_action"] = "retry_after_local_fix"
        row["retry_count"] = "0"
        return row

    if legacy_status == "invalid":
        row["phase"] = "import"
        row["status"] = "terminal_failure"
        row["failure_category"] = "legacy_import_failure"
        row["manual_action"] = "mark_invalid_or_recreate"
        return row

    if legacy_status == "hme_failed":
        row["phase"] = "register"
        row["status"] = "retryable_failure"
        row["failure_category"] = "hide_my_email_failed"
        row["manual_action"] = "retry_after_local_fix"
        return row

    if legacy_status == "registration_failed":
        row["phase"] = "register"
        row["status"] = "retryable_failure"
        row["failure_category"] = "legacy_register_failure"
        row["manual_action"] = "retry_after_local_fix"
        return row

    row["status"] = "manual_required"
    row["failure_category"] = "legacy_register_failure"
    row["manual_action"] = "review_legacy_row"
    return row


def normalize_row(raw: dict[str, str]) -> dict[str, str]:
    if raw.get("schema_version") == SCHEMA_VERSION:
        row = default_row()
        for key in HEADER:
            if key == "retry_count":
                row[key] = normalize_retry_count(raw.get(key))
            elif key == "updated_at":
                row[key] = normalize_text(raw.get(key)) or now_iso()
            else:
                row[key] = normalize_text(raw.get(key)) or row[key]
        return row

    legacy_keys = set(raw.keys())
    if legacy_keys.issuperset({"email", "password", "status"}):
        return legacy_status_to_row(
            email=normalize_text(raw.get("email")),
            password=normalize_text(raw.get("password")),
            legacy_status=normalize_text(raw.get("status")).lower(),
            url=normalize_text(raw.get("url")),
        )

    return default_row()


def load_rows(path: str) -> list[dict[str, str]]:
    csv_path = Path(path)
    if not csv_path.exists():
        return []

    with csv_path.open("r", encoding="utf-8", newline="") as fh:
        reader = csv.DictReader(fh)
        if reader.fieldnames is None:
            return []
        return [normalize_row(row) for row in reader]


def atomic_write_rows(path: str, rows: list[dict[str, str]]) -> None:
    csv_path = Path(path)
    csv_path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_path = tempfile.mkstemp(prefix=f"{csv_path.name}.", suffix=".tmp", dir=str(csv_path.parent))
    os.close(fd)
    try:
        with open(tmp_path, "w", encoding="utf-8", newline="") as fh:
            writer = csv.DictWriter(fh, fieldnames=HEADER)
            writer.writeheader()
            writer.writerows(rows)
        os.replace(tmp_path, csv_path)
    finally:
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)


def ensure_file(path: str) -> list[dict[str, str]]:
    rows = load_rows(path)
    atomic_write_rows(path, rows)
    return rows


def get_imported_accounts(config_path: str | None) -> ImportedAccounts:
    path = Path(config_path or os.path.expanduser("~/.codexbar/config.json"))
    if not path.exists():
        return ImportedAccounts(emails=set())

    with path.open("r", encoding="utf-8") as fh:
        config = json.load(fh)

    emails = {
        normalize_text(account.get("email"))
        for provider in config.get("providers", [])
        if provider.get("kind") == "openai_oauth"
        for account in provider.get("accounts", [])
        if normalize_text(account.get("email"))
    }
    return ImportedAccounts(emails=emails)


def normalize_failure_category(value: str | None) -> str:
    return normalize_text(value).lower().replace(" ", "_")


def manual_action_for_completed(auth_method: str) -> str:
    if auth_method == "password":
        return "none"
    if auth_method == "email_otp":
        return "review_passwordless_account"
    return "review_legacy_row"


def apply_updates(row: dict[str, str], args: argparse.Namespace) -> dict[str, str]:
    updated = dict(row)

    for key in ("email", "password", "status", "url", "auth_method", "phase", "failure_category", "manual_action"):
        incoming = getattr(args, key)
        if incoming != KEEP:
            updated[key] = normalize_text(incoming)

    if args.failure_category != KEEP:
        updated["failure_category"] = normalize_failure_category(args.failure_category)

    if args.updated_at != KEEP:
        updated["updated_at"] = normalize_text(args.updated_at) or now_iso()
    else:
        updated["updated_at"] = now_iso()

    if args.retry_count != KEEP:
        updated["retry_count"] = normalize_retry_count(args.retry_count)

    if args.increment_retry_count:
        updated["retry_count"] = str(int(normalize_retry_count(updated.get("retry_count"))) + 1)

    updated["schema_version"] = SCHEMA_VERSION
    if updated["status"] == "completed" and updated["manual_action"] in {"", KEEP}:
        updated["manual_action"] = manual_action_for_completed(updated["auth_method"])

    if not updated["manual_action"]:
        updated["manual_action"] = "none"

    return updated


def upsert_row(path: str, email: str, args: argparse.Namespace) -> dict[str, str]:
    rows = ensure_file(path)
    target_index = None
    if email:
        for idx in range(len(rows) - 1, -1, -1):
            if rows[idx]["email"] == email:
                target_index = idx
                break

    if target_index is None:
        row = default_row()
        row["email"] = normalize_text(email)
        updated = apply_updates(row, args)
        rows.append(updated)
    else:
        updated = apply_updates(rows[target_index], args)
        rows[target_index] = updated

    atomic_write_rows(path, rows)
    return updated


def is_auto_import_eligible(row: dict[str, str]) -> bool:
    return (
        row["phase"] == "register"
        and row["status"] == "completed"
        and row["auth_method"] in AUTO_IMPORT_AUTH_METHODS
        and not row["failure_category"]
        and row["manual_action"] == "none"
        and bool(row["email"])
        and bool(row["password"])
    )


def is_retry_eligible(row: dict[str, str]) -> bool:
    category = row["failure_category"]
    retry_count = int(normalize_retry_count(row.get("retry_count")))

    if row["phase"] == "register" and row["status"] == "retryable_failure":
        limit = REGISTER_RETRY_LIMITS.get(category)
        # retry_count is incremented when a failed run is recorded, so
        # "max retries = N" means rows remain eligible while count <= N.
        return limit is not None and retry_count <= limit

    if row["phase"] == "import" and row["status"] == "retryable_failure":
        limit = IMPORT_RETRY_LIMITS.get(category)
        return limit is not None and retry_count <= limit

    return False


def emit_candidates(rows: Iterable[dict[str, str]], imported: ImportedAccounts, email_filter: str, mode: str) -> None:
    for row in rows:
        email = row["email"]
        if not email:
            continue
        if email_filter and email != email_filter:
            continue
        if email in imported.emails:
            continue
        if mode == "import" and not is_auto_import_eligible(row):
            continue
        if mode == "retry" and not is_retry_eligible(row):
            continue
        print(email)
        print(row["password"])


def reconcile_imported(path: str, config_path: str | None, email_filter: str) -> int:
    rows = ensure_file(path)
    imported = get_imported_accounts(config_path)
    updated = 0

    for row in rows:
        email = row["email"]
        if not email:
            continue
        if email_filter and email != email_filter:
            continue
        if email not in imported.emails:
            continue
        if row["phase"] == "import" and row["status"] == "completed":
            continue
        row["schema_version"] = SCHEMA_VERSION
        row["phase"] = "import"
        row["status"] = "completed"
        row["failure_category"] = ""
        row["manual_action"] = "none"
        row["retry_count"] = "0"
        row["updated_at"] = now_iso()
        updated += 1

    atomic_write_rows(path, rows)
    return updated


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)

    ensure_parser = subparsers.add_parser("ensure")
    ensure_parser.add_argument("csv_path")

    upsert_parser = subparsers.add_parser("upsert")
    upsert_parser.add_argument("csv_path")
    upsert_parser.add_argument("--email", default="")
    upsert_parser.add_argument("--password", default=KEEP)
    upsert_parser.add_argument("--status", default=KEEP)
    upsert_parser.add_argument("--url", default=KEEP)
    upsert_parser.add_argument("--auth-method", dest="auth_method", default=KEEP)
    upsert_parser.add_argument("--phase", default=KEEP)
    upsert_parser.add_argument("--failure-category", dest="failure_category", default=KEEP)
    upsert_parser.add_argument("--manual-action", dest="manual_action", default=KEEP)
    upsert_parser.add_argument("--retry-count", dest="retry_count", default=KEEP)
    upsert_parser.add_argument("--updated-at", dest="updated_at", default=KEEP)
    upsert_parser.add_argument("--increment-retry-count", action="store_true")

    set_url_parser = subparsers.add_parser("set-url")
    set_url_parser.add_argument("csv_path")
    set_url_parser.add_argument("--email", required=True)
    set_url_parser.add_argument("--url", required=True)

    list_import_parser = subparsers.add_parser("list-import-candidates")
    list_import_parser.add_argument("csv_path")
    list_import_parser.add_argument("--email-filter", default="")
    list_import_parser.add_argument("--config-path", default="")

    list_retry_parser = subparsers.add_parser("list-retry-candidates")
    list_retry_parser.add_argument("csv_path")
    list_retry_parser.add_argument("--email-filter", default="")
    list_retry_parser.add_argument("--config-path", default="")

    reconcile_parser = subparsers.add_parser("reconcile-imported")
    reconcile_parser.add_argument("csv_path")
    reconcile_parser.add_argument("--email-filter", default="")
    reconcile_parser.add_argument("--config-path", default="")

    return parser


def main(argv: list[str]) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.command == "ensure":
        ensure_file(args.csv_path)
        return 0

    if args.command == "upsert":
        upsert_row(args.csv_path, normalize_text(args.email), args)
        return 0

    if args.command == "set-url":
        fake_args = argparse.Namespace(
            email=args.email,
            password=KEEP,
            status=KEEP,
            url=args.url,
            auth_method=KEEP,
            phase=KEEP,
            failure_category=KEEP,
            manual_action=KEEP,
            retry_count=KEEP,
            updated_at=KEEP,
            increment_retry_count=False,
        )
        upsert_row(args.csv_path, normalize_text(args.email), fake_args)
        return 0

    if args.command == "list-import-candidates":
        rows = ensure_file(args.csv_path)
        emit_candidates(
            rows=rows,
            imported=get_imported_accounts(args.config_path or None),
            email_filter=normalize_text(args.email_filter),
            mode="import",
        )
        return 0

    if args.command == "list-retry-candidates":
        rows = ensure_file(args.csv_path)
        emit_candidates(
            rows=rows,
            imported=get_imported_accounts(args.config_path or None),
            email_filter=normalize_text(args.email_filter),
            mode="retry",
        )
        return 0

    if args.command == "reconcile-imported":
        count = reconcile_imported(
            path=args.csv_path,
            config_path=args.config_path or None,
            email_filter=normalize_text(args.email_filter),
        )
        print(count)
        return 0

    parser.error(f"unsupported command: {args.command}")
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
