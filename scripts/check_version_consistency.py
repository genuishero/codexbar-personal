#!/usr/bin/env python3
"""Validate codexbar release metadata stays on one version."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from urllib.parse import urlparse


ROOT = Path(__file__).resolve().parent.parent
VERSION_PATH = ROOT / "VERSION"
PBXPROJ_PATH = ROOT / "codexbar.xcodeproj" / "project.pbxproj"
FEED_PATH = ROOT / "release-feed" / "stable.json"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def load_feed(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def read_version(path: Path) -> str:
    version = path.read_text(encoding="utf-8").strip()
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        raise SystemExit(f"VERSION 文件格式非法: {version!r}")
    return version


def parse_marketing_versions(project_text: str) -> set[str]:
    return set(re.findall(r"MARKETING_VERSION = ([^;]+);", project_text))


def ensure(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def path_contains_version(url: str, version: str) -> bool:
    path = urlparse(url).path
    return f"/v{version}" in path or version in path


def main() -> int:
    errors: list[str] = []

    expected_version = read_version(VERSION_PATH)
    project_text = read_text(PBXPROJ_PATH)
    feed = load_feed(FEED_PATH)

    marketing_versions = parse_marketing_versions(project_text)
    ensure(marketing_versions, "未在 project.pbxproj 中找到 MARKETING_VERSION", errors)
    ensure(
        len(marketing_versions) == 1,
        f"检测到多个 MARKETING_VERSION: {sorted(marketing_versions)}",
        errors,
    )

    release = feed.get("release")
    ensure(isinstance(release, dict), "stable.json 缺少 release 对象", errors)
    if not isinstance(release, dict):
        for error in errors:
            print(error, file=sys.stderr)
        return 1

    feed_version = release.get("version")
    ensure(isinstance(feed_version, str) and feed_version.strip(), "stable.json 缺少 release.version", errors)
    if not isinstance(feed_version, str) or not feed_version.strip():
        for error in errors:
            print(error, file=sys.stderr)
        return 1

    project_version = next(iter(marketing_versions)) if marketing_versions else None
    ensure(
        project_version == expected_version,
        f"Xcode MARKETING_VERSION ({project_version}) 与 VERSION ({expected_version}) 不一致",
        errors,
    )
    ensure(
        feed_version == expected_version,
        f"stable.json release.version ({feed_version}) 与 VERSION ({expected_version}) 不一致",
        errors,
    )

    release_notes_url = release.get("releaseNotesURL")
    download_page_url = release.get("downloadPageURL")
    ensure(
        isinstance(release_notes_url, str) and path_contains_version(release_notes_url, expected_version),
        f"releaseNotesURL 未指向 v{expected_version}: {release_notes_url}",
        errors,
    )
    ensure(
        isinstance(download_page_url, str) and path_contains_version(download_page_url, expected_version),
        f"downloadPageURL 未指向 v{expected_version}: {download_page_url}",
        errors,
    )

    artifacts = release.get("artifacts")
    ensure(isinstance(artifacts, list) and artifacts, "stable.json release.artifacts 为空", errors)
    if isinstance(artifacts, list):
        for index, artifact in enumerate(artifacts, start=1):
            if not isinstance(artifact, dict):
                errors.append(f"artifacts[{index}] 不是对象")
                continue
            download_url = artifact.get("downloadURL")
            ensure(
                isinstance(download_url, str) and path_contains_version(download_url, expected_version),
                f"artifacts[{index}].downloadURL 未包含版本 {expected_version}: {download_url}",
                errors,
            )

    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1

    print(f"版本一致性检查通过: {expected_version}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
