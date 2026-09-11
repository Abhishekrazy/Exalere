#!/usr/bin/env python3
"""
detect_hardcoded_styles.py
Scans Flutter Dart source files in the Exalere project to detect hardcoded
colors (e.g., Colors.white, Colors.black, Color(0x...), hardcoded styling)
and flags them for replacement with `context.tokens` or `Theme.of(context)`.

Usage:
    python scripts/detect_hardcoded_styles.py [options]

Options:
    --path DIR        Root directory to scan (default: lib/)
    --exclude FILES   Comma-separated substrings/paths to exclude
    --summary-only    Only print the summary count table
    --json            Output results in JSON format
"""

import os
import sys
import re
import argparse
import json
from typing import List, Dict, Any

# Excluded by default: Theme and design token definition files, and vendored dpad engine
DEFAULT_EXCLUDES = [
    os.path.normpath("lib/ui/theme/app_themes.dart"),
    os.path.normpath("lib/ui/theme/app_tokens.dart"),
    os.path.normpath("lib/ui/widgets/dpad"),
]

# Patterns for hardcoded colors
COLOR_PATTERNS = [
    (
        re.compile(r'\bColors\.(white\d*|black\d*|amber\w*|red\w*|green\w*|blue\w*|grey\w*|yellow\w*|purple\w*|orange\w*|teal\w*|indigo\w*|pink\w*|cyan\w*)\b'),
        "Colors.<named>",
    ),
    (
        re.compile(r'\bColor\s*\(\s*0x[0-9a-fA-F]{6,8}\s*\)'),
        "Color(0xHEX)",
    ),
    (
        re.compile(r'\bconst\s+Color\s*\(\s*0x[0-9a-fA-F]{6,8}\s*\)'),
        "const Color(0xHEX)",
    ),
]

# Token recommendations for common hardcoded colors
SUGGESTIONS = {
    "Colors.white": "context.tokens.textPrimary / context.tokens.surfaceBackground",
    "Colors.white70": "context.tokens.textSecondary",
    "Colors.white60": "context.tokens.textSecondary",
    "Colors.white54": "context.tokens.textSecondary / context.tokens.textMuted",
    "Colors.white38": "context.tokens.textMuted",
    "Colors.white24": "context.tokens.borderSubtle / context.tokens.textMuted",
    "Colors.white12": "context.tokens.borderSubtle",
    "Colors.white10": "context.tokens.borderSubtle",
    "Colors.black": "theme.colorScheme.onPrimary (on buttons) / context.tokens.shadowColor",
    "Colors.black26": "context.tokens.surfaceElevated",
    "Colors.black54": "Colors.black.withValues(alpha: 0.54) (for scrims) or tokens.surfaceCard",
    "Colors.amber": "context.tokens.vipColor",
    "Colors.amberAccent": "context.tokens.vipColor",
    "Colors.red": "context.tokens.liveColor / theme.colorScheme.error",
    "Colors.redAccent": "context.tokens.liveColor",
    "Colors.transparent": "Colors.transparent (acceptable if used for zero-bleed background)",
}

def scan_file(filepath: str) -> List[Dict[str, Any]]:
    issues = []
    try:
        with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
            lines = f.readlines()
    except Exception as e:
        print(f"Error reading {filepath}: {e}", file=sys.stderr)
        return issues

    for line_idx, raw_line in enumerate(lines, start=1):
        line = raw_line.strip()

        # Ignore comments
        if line.startswith("//") or line.startswith("/*") or line.startswith("*"):
            continue

        for pattern, kind in COLOR_PATTERNS:
            matches = pattern.finditer(raw_line)
            for m in matches:
                matched_text = m.group(0)

                # Special case: Colors.transparent inside appBar backgroundColor: Colors.transparent is acceptable
                # but flag it if used as a general placeholder
                if matched_text == "Colors.transparent" and "backgroundColor: Colors.transparent" in raw_line:
                    continue

                suggestion = SUGGESTIONS.get(matched_text, "context.tokens.<token> / theme.colorScheme.<color>")

                issues.append({
                    "file": filepath,
                    "line": line_idx,
                    "column": m.start() + 1,
                    "match": matched_text,
                    "kind": kind,
                    "line_content": raw_line.rstrip(),
                    "suggestion": suggestion,
                })
    return issues

def main():
    parser = argparse.ArgumentParser(
        description="Scan Exalere Dart files for hardcoded colors and static styling."
    )
    parser.add_argument(
        "--path",
        default="lib",
        help="Root folder to scan (default: lib/)",
    )
    parser.add_argument(
        "--exclude",
        default="",
        help="Comma-separated file paths or names to exclude",
    )
    parser.add_argument(
        "--summary-only",
        action="store_true",
        help="Only output the summary table",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output raw JSON array of issues",
    )

    args = parser.parse_args()

    root_dir = os.path.abspath(args.path)
    if not os.path.exists(root_dir):
        print(f"Error: Path '{root_dir}' does not exist.", file=sys.stderr)
        sys.exit(2)

    extra_excludes = [
        os.path.normpath(e.strip()) for e in args.exclude.split(",") if e.strip()
    ]
    all_excludes = [os.path.abspath(e) for e in DEFAULT_EXCLUDES + extra_excludes]

    total_issues: List[Dict[str, Any]] = []
    scanned_files = 0

    if os.path.isfile(root_dir):
        if root_dir.endswith(".dart") and not any(root_dir == exc for exc in all_excludes):
            scanned_files = 1
            total_issues.extend(scan_file(root_dir))
    else:
        for dirpath, _, filenames in os.walk(root_dir):
            for fname in sorted(filenames):
                if not fname.endswith(".dart"):
                    continue

                full_path = os.path.abspath(os.path.join(dirpath, fname))

                # Check if excluded
                if any(full_path == exc or exc in full_path for exc in all_excludes):
                    continue

                scanned_files += 1
                file_issues = scan_file(full_path)
                total_issues.extend(file_issues)

    if args.json:
        print(json.dumps(total_issues, indent=2))
        sys.exit(1 if total_issues else 0)

    # Force utf-8 stdout if supported
    if hasattr(sys.stdout, "reconfigure"):
        try:
            sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass

    # Pretty output
    rel_root = os.path.relpath(root_dir)
    print("=" * 80)
    print(f"[AUDIT] EXALERE HARDCODED STYLES & STATIC VALUES AUDIT")
    print(f"        Root scanned: {rel_root} ({scanned_files} Dart files)")
    print("=" * 80)

    if not total_issues:
        print("[SUCCESS] Zero hardcoded colors found! All components are using theme/tokens.")
        sys.exit(0)

    # Group by file
    issues_by_file: Dict[str, List[Dict[str, Any]]] = {}
    for issue in total_issues:
        rel_file = os.path.relpath(issue["file"])
        issues_by_file.setdefault(rel_file, []).append(issue)

    if not args.summary_only:
        for rel_file, issues in issues_by_file.items():
            print(f"\n[FILE] {rel_file} ({len(issues)} violations):")
            for iss in issues:
                print(f"   Line {iss['line']:4d} | {iss['match']:<20} -> Suggestion: {iss['suggestion']}")
                print(f"           Snippet: {iss['line_content'].strip()}")

    print("\n" + "-" * 80)
    print(f"SUMMARY BY FILE:")
    print("-" * 80)
    for rel_file, issues in sorted(issues_by_file.items(), key=lambda x: len(x[1]), reverse=True):
        print(f"  {len(issues):3d} issues : {rel_file}")

    print("-" * 80)
    print(f"[FAIL] TOTAL: {len(total_issues)} hardcoded color violation(s) found across {len(issues_by_file)} file(s).")
    print("       Rule: Components MUST use `context.tokens` or `Theme.of(context).colorScheme`.")
    print("=" * 80)

    sys.exit(1)

if __name__ == "__main__":
    main()
