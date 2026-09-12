#!/usr/bin/env python3
"""
Automated SVG Repository Card Badge Updater for Exalere.

Extracts target version from CLI argument or pubspec.yaml and updates
.github/assets/repo-card.svg with the proper version badge and geometry.
"""

import argparse
import os
import re
import sys
from pathlib import Path


def get_repo_root() -> Path:
    script_path = Path(__file__).resolve()
    return script_path.parent.parent


def get_version_from_pubspec(repo_root: Path) -> str:
    pubspec_path = repo_root / "pubspec.yaml"
    if not pubspec_path.exists():
        raise FileNotFoundError(f"pubspec.yaml not found at {pubspec_path}")

    with open(pubspec_path, "r", encoding="utf-8") as f:
        for line in f:
            match = re.match(r"^version:\s*([0-9]+\.[0-9]+\.[0-9]+(?:\+[0-9]+)?)", line.strip())
            if match:
                raw_ver = match.group(1)
                return raw_ver.split("+")[0]

    raise ValueError("Could not extract valid version from pubspec.yaml")


def update_repo_card_svg(repo_root: Path, version: str) -> bool:
    svg_path = repo_root / ".github" / "assets" / "repo-card.svg"
    if not svg_path.exists():
        raise FileNotFoundError(f"repo-card.svg not found at {svg_path}")

    version = version.lstrip("v")
    badge_text = f"v{version}"

    with open(svg_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Calculate badge width and x-position to keep right alignment at x=527
    # (Leaving 6px gap before the star badge at x=533)
    char_len = len(badge_text)
    badge_width = max(52, char_len * 7 + 10)
    badge_x = 527 - badge_width
    text_x = round(badge_x + (badge_width / 2.0), 1)
    if text_x.is_integer():
        text_x = int(text_x)

    # Regex patterns for the status badge rect and text inside repo-card.svg
    rect_pattern = re.compile(
        r'(<rect\s+x=")\d+(?:\.\d+)?("\s+y="22"\s+width=")\d+(?:\.\d+)?("\s+rx="10"\s+fill="#1f242c"\s+stroke="#30363d"\s+stroke-width="1"\s*/>)'
    )
    text_pattern = re.compile(
        r'(<text\s+x=")\d+(?:\.\d+)?("\s+y="36"\s+class="badge-text"\s+text-anchor="middle">)v[^<]+(</text>)'
    )

    new_content = rect_pattern.sub(rf'\g<1>{badge_x}\g<2>{badge_width}\g<3>', content)
    new_content = text_pattern.sub(rf'\g<1>{text_x}\g<2>{badge_text}\g<3>', new_content)

    if new_content == content:
        print(f"[SVG Updater] repo-card.svg is already up to date with {badge_text}.")
        return False

    with open(svg_path, "w", encoding="utf-8") as f:
        f.write(new_content)

    print(f"[SVG Updater] Successfully updated repo-card.svg badge to {badge_text} (width={badge_width}px, x={badge_x}, center={text_x}).")
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description="Update version badge in .github/assets/repo-card.svg")
    parser.add_argument("--version", "-v", help="Target version string (e.g. 0.7.1 or v0.7.1)", default=None)
    args = parser.parse_args()

    repo_root = get_repo_root()

    if args.version:
        version = args.version
    else:
        version = get_version_from_pubspec(repo_root)

    try:
        update_repo_card_svg(repo_root, version)
        return 0
    except Exception as e:
        print(f"[ERROR] Failed to update repo-card.svg: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
