"""Normalise border stroke widths across the UI.

BorderSide / Border.all widths are currently scattered across 0.6-1.6 px, so
cards, rows, chips and dialogs do not share a stroke. Every literal width in a
BorderSide or Border.all is replaced with AppStroke.border (focus strokes with
AppStroke.focus), which makes the stroke uniform and keeps it following the
adaptive bevel path.

Dynamic widths (ternaries) are left alone.

Usage: python scripts/normalize_border_widths.py [--write]
"""

import io
import os
import re
import sys

BORDER = "AppStroke.border"
FOCUS = "AppStroke.focus"
TARGET = re.compile(r"(BorderSide|Border\.all)\(")
WIDTH = re.compile(r"width:\s*([0-9]+(?:\.[0-9]+)?)")


def match_close(text, open_index):
    depth = 0
    for i in range(open_index, len(text)):
        if text[i] == "(":
            depth += 1
        elif text[i] == ")":
            depth -= 1
            if depth == 0:
                return i
    raise ValueError("unbalanced")


def normalise(src):
    out, cursor, changed = [], 0, 0
    while True:
        match = TARGET.search(src, cursor)
        if not match:
            out.append(src[cursor:])
            break
        open_paren = match.end() - 1
        close = match_close(src, open_paren)
        body = src[open_paren + 1 : close]

        def replace_width(width_match):
            nonlocal changed
            value = float(width_match.group(1))
            if value >= 2.4:
                replacement = FOCUS
            else:
                replacement = BORDER
            changed += 1
            return f"width: {replacement}"

        new_body = WIDTH.sub(replace_width, body)
        out.append(src[cursor : open_paren + 1])
        out.append(new_body)
        cursor = close
    return "".join(out), changed


def main():
    write = "--write" in sys.argv
    root = "lib/ui"
    total = 0
    files = 0
    for directory, _, names in os.walk(root):
        for name in names:
            if not name.endswith(".dart"):
                continue
            path = os.path.join(directory, name)
            src = io.open(path, encoding="utf-8").read()
            result, changed = normalise(src)
            if changed:
                total += changed
                files += 1
                print(f"{path}: {changed}")
                if write:
                    io.open(path, "w", encoding="utf-8", newline="\n").write(result)
    print(f"total {total} widths in {files} files" + (" (written)" if write else " (dry run)"))


if __name__ == "__main__":
    main()
