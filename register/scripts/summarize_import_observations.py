#!/usr/bin/env python3

import json
import os
import re
import sys
from collections import Counter


def load_records(path: str) -> list[dict]:
    records = []
    with open(path, "r", encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                records.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    return records


def observation_category(record: dict) -> str:
    return record.get("category") or record.get("failure_category") or "unknown"


def sanitize_detail(detail: str) -> str:
    detail = re.sub(
        r"\b(access_token|refresh_token|id_token|code)=([^&\s]+)",
        lambda match: f"{match.group(1)}=[redacted]",
        detail,
    )
    detail = re.sub(r"https?://[^\s]+", "[redacted-url]", detail)
    detail = re.sub(r"\b\d{6,8}\b", "[redacted-code]", detail)
    return detail


def main() -> int:
    import_path = os.path.expanduser(
        os.environ.get(
            "IMPORT_OBSERVATION_LOG",
            "~/.codexbar/register-import-observations.jsonl",
        )
    )
    register_path = os.path.expanduser(
        os.environ.get(
            "REGISTER_OBSERVATION_LOG",
            "~/.codexbar/register-observations.jsonl",
        )
    )

    paths = [path for path in (register_path, import_path) if os.path.exists(path)]
    if not paths:
        print(f"no observation log found at {register_path} or {import_path}")
        return 1

    records = []
    for path in paths:
        records.extend(load_records(path))

    records.sort(key=lambda item: item.get("timestamp", ""))
    failures = [r for r in records if r.get("outcome") in {"failure", "manual_required"}]
    counts = Counter(observation_category(r) for r in failures)
    phase_counts = Counter(r.get("phase", "unknown") for r in records)
    auth_method_counts = Counter((r.get("auth_method") or "unknown") for r in records)
    ordered_categories = [
        "dependency_missing",
        "path_config_error",
        "hide_my_email_failed",
        "local_browser_failure",
        "auth_url_capture_failed",
        "cdp_race",
        "mail_code_timeout",
        "invalid_state",
        "parse_failure",
        "csv_schema_mismatch",
        "captcha_challenge",
        "phone_verification",
        "about_you_block",
        "manual_review",
        "provider_timeout",
    ]

    print(f"log_paths={','.join(paths)}")
    print(f"record_count={len(records)}")
    print(f"failure_records={len(failures)}")
    for phase, count in sorted(phase_counts.items()):
        print(f"phase_{phase}={count}")
    for auth_method in ("password", "email_otp", "unknown"):
        print(f"auth_method_{auth_method}={auth_method_counts.get(auth_method, 0)}")
    for category in ordered_categories:
        print(f"{category}={counts.get(category, 0)}")

    extras = [name for name in counts if name not in ordered_categories]
    for category in sorted(extras):
        print(f"{category}={counts[category]}")

    print("--- recent_failures ---")
    for record in failures[-10:]:
        detail = sanitize_detail((record.get("detail") or "").splitlines()[0])
        print(
            f"{record.get('timestamp','')}\t"
            f"{record.get('phase','')}\t"
            f"{record.get('email','')}\t"
            f"{observation_category(record)}\t"
            f"{record.get('workflow_status','')}\t"
            f"{record.get('manual_action','')}\t"
            f"{detail}"
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
