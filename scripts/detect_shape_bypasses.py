#!/usr/bin/env python3
"""Find UI that bypasses the theme's corner style (rounded / sharp / cut-bevel).

The design tokens expose two kinds of corner API:

* `tokens.shapeXs/Sm/Md/Lg` + `tokens.getShapeDecoration(...)` — a shape-aware
  `OutlinedBorder`. In the **Cut (bevel)** theme this paints chamfered corners.
* `tokens.borderRadiusXs/Sm/Md/Lg` — only a `BorderRadius`. Sharp maps it to
  zero, but **Cut silently renders rounded corners**, because a BorderRadius
  cannot express a bevel.

So any widget that draws its own `BoxDecoration(borderRadius: tokens.borderRadius*)`,
or hardcodes a radius/shape, keeps round corners while the rest of the app is
bevelled. This script reports those places so they can be migrated to
`getShapeDecoration` / `tokens.shape*` (or `clipShape`).

Usage:
    python scripts/detect_shape_bypasses.py [--path DIR] [--summary-only]
Exit code 1 when findings exist, 0 when clean.
"""

import argparse
import os
import re
import sys

DEFAULT_PATH = "lib/ui"

# Files that legitimately define corner geometry.
EXEMPT_FILES = {
    "app_tokens.dart",
    "app_themes.dart",
}

# A radius at or above this is a circle/stadium (avatars, dots, pills): the
# corner style does not apply, so it is not reported as a bypass.
CIRCLE_RADIUS = 500.0

TOKEN_RADIUS = re.compile(r"borderRadius(?:Xs|Sm|Md|Lg|Pill)\b")
HARD_RADIUS = re.compile(r"BorderRadius\.circular\(([^)]*)\)")
BORDER_RADIUS_ALL = re.compile(r"BorderRadius\.all\(")
RAW_SHAPES = re.compile(
    r"\b(RoundedRectangleBorder|StadiumBorder|BeveledRectangleBorder)\("
)
CLIP_RRECT = re.compile(r"ClipRRect\(")


def numeric_value(expression):
    match = re.fullmatch(r"\s*([0-9]+(?:\.[0-9]+)?)\s*", expression)
    if match:
        return float(match.group(1))
    return None


def scan_file(path):
    findings = []
    name = os.path.basename(path)
    if name in EXEMPT_FILES:
        return findings

    with open(path, encoding="utf-8") as handle:
        lines = handle.readlines()

    for number, line in enumerate(lines, start=1):
        stripped = line.strip()
        if stripped.startswith("//"):
            continue

        # Rounded-only token used where a shape is required.
        if TOKEN_RADIUS.search(line) and "borderRadius:" in line:
            findings.append(
                (
                    number,
                    "token-radius-bypass",
                    "borderRadius: tokens.* renders round corners in Cut/bevel",
                    stripped,
                )
            )
            continue

        if BORDER_RADIUS_ALL.search(line):
            findings.append(
                (number, "hardcoded-radius", "BorderRadius.all(...) bypasses the theme", stripped)
            )
            continue

        match = HARD_RADIUS.search(line)
        if match:
            radius = numeric_value(match.group(1))
            if radius is not None and radius >= CIRCLE_RADIUS:
                continue
            if radius is None and re.search(r"\*\s*[0-9.]+$", match.group(1)):
                # tokens.cardRadius * n — still hardcoded geometry.
                pass
            findings.append(
                (
                    number,
                    "hardcoded-radius",
                    "literal BorderRadius.circular bypasses the theme",
                    stripped,
                )
            )
            continue

        if RAW_SHAPES.search(line) and "tokens.shape" not in line:
            findings.append(
                (number, "raw-shape", "hardcoded shape bypasses tokens.shape*", stripped)
            )
            continue

        if CLIP_RRECT.search(line):
            findings.append(
                (
                    number,
                    "clip-rrect",
                    "ClipRRect ignores Cut/bevel (use tokens.clipShape)",
                    stripped,
                )
            )

    return findings


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--path", default=DEFAULT_PATH)
    parser.add_argument("--summary-only", action="store_true")
    args = parser.parse_args()

    targets = []
    if os.path.isfile(args.path):
        targets = [args.path]
    else:
        for root, _, files in os.walk(args.path):
            for file in files:
                if file.endswith(".dart"):
                    targets.append(os.path.join(root, file))

    per_file = {}
    by_kind = {}
    for path in sorted(targets):
        findings = scan_file(path)
        if findings:
            per_file[path] = findings
            for finding in findings:
                by_kind[finding[1]] = by_kind.get(finding[1], 0) + 1

    print("=" * 80)
    print(f"Theme corner-style bypasses under {args.path}")
    print("=" * 80)
    print("Root scanned:", args.path, f"({len(targets)} Dart files)")
    print()

    if not per_file:
        print("[SUCCESS] No corner-style bypasses found.")
        return 0

    for path, findings in per_file.items():
        print(f"{path}  ({len(findings)})")
        if not args.summary_only:
            for number, kind, message, line in findings:
                print(f"  L{number}: [{kind}] {message}")
                print(f"       {line[:140]}")
        print()

    print("-" * 80)
    print("Summary by kind:")
    for kind, count in sorted(by_kind.items(), key=lambda pair: -pair[1]):
        print(f"  {kind}: {count}")
    print(f"  files affected: {len(per_file)}")
    print()
    print(
        "Fix: draw with tokens.getShapeDecoration(...) / tokens.shapeXs..Lg and "
        "tokens.clipShape(...) instead of BorderRadius / raw shapes."
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())
