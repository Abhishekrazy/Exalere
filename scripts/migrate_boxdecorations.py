"""Convert BoxDecoration(borderRadius: ...) to shape-aware ShapeDecoration.

BoxDecoration can only hold a BorderRadius, so under the Cut (bevel) corner
style it silently paints rounded corners. ShapeDecoration with
tokens.getShapeBorder() follows all three corner styles.

Handles the subset used in this codebase:
    color: <expr>
    borderRadius: tokens.borderRadiusXs|Sm|Md|Lg | BorderRadius.circular(<expr>)
    border: Border.all(color: ..., width: ...)
    boxShadow: <expr>

Blocks with gradient/image/shape are left untouched.
"""

import io
import re
import sys

RADIUS_TOKENS = {
    "borderRadiusXs": "(tokens.cardRadius * 0.35).clamp(2.0, 12.0)",
    "borderRadiusSm": "(tokens.cardRadius * 0.65).clamp(4.0, 20.0)",
    "borderRadiusMd": "tokens.cardRadius",
    "borderRadiusLg": "tokens.cardRadius * 1.35",
    "borderRadiusPill": "8.0",
}


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


def split_top_level(body):
    """Split 'a: x, b: y(...), c: z' on commas at paren depth 0."""
    parts, depth, start = [], 0, 0
    for i, ch in enumerate(body):
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        elif ch == "," and depth == 0:
            parts.append(body[start:i])
            start = i + 1
    parts.append(body[start:])
    return [p for p in parts if p.strip()]


def parse_fields(body):
    fields = {}
    for part in split_top_level(body):
        key, _, value = part.partition(":")
        fields[key.strip()] = value.strip()
    return fields


def radius_expr(value):
    match = re.fullmatch(r"tokens\.(borderRadius\w+)", value)
    if match:
        return RADIUS_TOKENS.get(match.group(1))
    match = re.fullmatch(r"BorderRadius\.all\(\s*Radius\.circular\((.+)\)\s*\)", value, re.S)
    if match:
        return match.group(1).strip()
    match = re.fullmatch(r"BorderRadius\.circular\((.+)\)", value, re.S)
    if match:
        return match.group(1).strip()
    if value.startswith("BorderRadius.zero"):
        return "0.0"
    return None


def side_expr(value):
    if value.startswith("Border.all("):
        inner = value[len("Border.all(") : -1]
        fields = parse_fields(inner)
        color = fields.get("color")
        width = fields.get("width", "1.0")
        if color:
            return f"BorderSide(color: {color}, width: {width})"
    if value.startswith("BorderSide("):
        return value
    return None


def convert_block(body):
    fields = parse_fields(body)
    if "borderRadius" not in fields:
        return None
    if any(k in fields for k in ("gradient", "image", "shape")):
        return None

    radius = radius_expr(fields["borderRadius"])
    if radius is None:
        return None
    side = side_expr(fields["border"]) if "border" in fields else None
    color = fields.get("color", "tokens.surfaceCard")
    shadows = fields.get("boxShadow", "const []")

    lines = [
        "ShapeDecoration(",
        f"color: {color},",
        "shape: tokens.getShapeBorder(",
        f"radius: {radius},",
        f"side: {side or 'BorderSide.none'},",
        "),",
        f"shadows: {shadows},",
        ")",
    ]
    return "".join(line if line.endswith(("(",)) else line for line in []) or "\n".join(lines)


def process(path, write):
    src = io.open(path, encoding="utf-8").read()
    out, cursor, converted = [], 0, 0
    while True:
        start = src.find("BoxDecoration(", cursor)
        if start == -1:
            out.append(src[cursor:])
            break
        open_paren = start + len("BoxDecoration") 
        close = match_close(src, open_paren)
        body = src[open_paren + 1 : close]
        replacement = convert_block(body)
        out.append(src[cursor:start])
        if replacement is None:
            out.append(src[start : close + 1])
        else:
            out.append(replacement)
            converted += 1
        cursor = close + 1
    result = "".join(out)
    if write and converted:
        io.open(path, "w", encoding="utf-8", newline="\n").write(result)
    return converted


if __name__ == "__main__":
    write = "--write" in sys.argv
    files = [a for a in sys.argv[1:] if not a.startswith("--")]
    total = 0
    for path in files:
        count = process(path, write)
        total += count
        print(f"{path}: {count} converted")
    print("total", total, "(written)" if write else "(dry run)")
