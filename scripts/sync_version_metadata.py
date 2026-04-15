#!/usr/bin/env python3
"""Sync codexbar version metadata from the single VERSION source."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from urllib.parse import urlparse


ROOT = Path(__file__).resolve().parent.parent
VERSION_PATH = ROOT / "VERSION"
PBXPROJ_PATH = ROOT / "codexbar.xcodeproj" / "project.pbxproj"
FEED_PATH = ROOT / "release-feed" / "stable.json"

SEMVER_RE = re.compile(r"\b\d+\.\d+\.\d+\b")
TAG_RE = re.compile(r"/releases/tag/v\d+\.\d+\.\d+$")
DOWNLOAD_RE = re.compile(r"/releases/download/v\d+\.\d+\.\d+/")


def read_version(path: Path) -> str:
    version = path.read_text(encoding="utf-8").strip()
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        raise SystemExit(f"VERSION 文件格式非法: {version!r}")
    return version


def infer_repo_slug(url: str) -> str:
    parsed = urlparse(url)
    match = re.search(r"^/([^/]+/[^/]+)/releases/", parsed.path)
    if not match:
        raise SystemExit(f"无法从 URL 推导 GitHub 仓库: {url}")
    return match.group(1)


def update_project(project_text: str, version: str) -> str:
    return re.sub(r"MARKETING_VERSION = [^;]+;", f"MARKETING_VERSION = {version};", project_text)


def update_filename_version(filename: str, version: str) -> str:
    if SEMVER_RE.search(filename):
        return SEMVER_RE.sub(version, filename, count=1)
    return filename


def make_release_url(repo_slug: str, version: str) -> str:
    return f"https://github.com/{repo_slug}/releases/tag/v{version}"


def make_download_url(current_url: str, repo_slug: str, version: str) -> str:
    parsed = urlparse(current_url)
    filename = Path(parsed.path).name
    filename = update_filename_version(filename, version)
    return f"https://github.com/{repo_slug}/releases/download/v{version}/{filename}"


def update_feed(feed: dict, version: str) -> dict:
    release = feed.get("release")
    if not isinstance(release, dict):
        raise SystemExit("stable.json 缺少 release 对象")

    reference_url = release.get("releaseNotesURL") or release.get("downloadPageURL")
    if not isinstance(reference_url, str) or not reference_url:
        raise SystemExit("stable.json 缺少可推导仓库的 release URL")

    repo_slug = infer_repo_slug(reference_url)
    release["version"] = version
    release["releaseNotesURL"] = make_release_url(repo_slug, version)
    release["downloadPageURL"] = make_release_url(repo_slug, version)

    artifacts = release.get("artifacts")
    if not isinstance(artifacts, list) or not artifacts:
        raise SystemExit("stable.json release.artifacts 为空")

    normalized_artifacts: list[dict] = []
    for artifact in artifacts:
        if not isinstance(artifact, dict):
            raise SystemExit("stable.json artifacts 中存在非对象条目")

        normalized = dict(artifact)
        download_url = normalized.get("downloadURL")
        if not isinstance(download_url, str) or not download_url:
            raise SystemExit("artifact.downloadURL 缺失")
        normalized["downloadURL"] = make_download_url(download_url, repo_slug, version)
        normalized_artifacts.append(normalized)

    release["artifacts"] = normalized_artifacts
    feed["release"] = release
    return feed


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Sync Xcode MARKETING_VERSION and release feed from the VERSION file."
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="只检查是否已同步，不写回文件",
    )
    args = parser.parse_args()

    version = read_version(VERSION_PATH)
    original_project = PBXPROJ_PATH.read_text(encoding="utf-8")
    original_feed = json.loads(FEED_PATH.read_text(encoding="utf-8"))

    updated_project = update_project(original_project, version)
    updated_feed = update_feed(json.loads(json.dumps(original_feed)), version)
    rendered_feed = json.dumps(updated_feed, ensure_ascii=False, indent=2, sort_keys=False) + "\n"
    original_feed_rendered = json.dumps(original_feed, ensure_ascii=False, indent=2, sort_keys=False) + "\n"

    has_changes = updated_project != original_project or rendered_feed != original_feed_rendered

    if args.check:
        if has_changes:
            print("版本元数据未从 VERSION 同步，请先运行: python3 scripts/sync_version_metadata.py", file=sys.stderr)
            return 1
        print(f"版本元数据已与 VERSION 对齐: {version}")
        return 0

    if updated_project != original_project:
        PBXPROJ_PATH.write_text(updated_project, encoding="utf-8")
    if rendered_feed != original_feed_rendered:
        FEED_PATH.write_text(rendered_feed, encoding="utf-8")

    print(f"已同步版本元数据到 {version}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
