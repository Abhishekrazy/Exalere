"""Scan triaged providers for one whose post pages expose resolvable hosts.

Reads .tmp_shots/vega_triage.json (from scripts/vega_triage.py), fetches each
candidate's home page, follows the first content-looking link, and reports which
stream hosts the post page mentions. A post page with hubcloud/nexdrive/fastdl/
pixeldrain/m3u8 hits is a candidate for a HubCloud-family port; anything else is
gated, JS-rendered, or dead.

Usage:
    python scripts/vega_find_portable.py
"""

from __future__ import annotations

import json
import os
import re
import sys
import urllib.error
import urllib.request

UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120"
TRIAGE = os.path.join(".tmp_shots", "vega_triage.json")

HOST_MARKERS = [
    "hubcloud",
    "hubdrive",
    "nexdrive",
    "fastdl",
    "pixeldrain",
    "m3u8",
    "drive.google",
]
SHIPPED = {"internetarchive", "torrentio", "moviebox", "4khdhub", "hdhub4u",
           "movies4u", "uhd", "mod", "drive", "luxmovies", "kisskh",
           "kickassanime", "zeefliz", "multimovies", "circleftp", "dramacool",
           "vidsrc", "tmdb"}


def get(url: str) -> str:
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": UA,
            "Accept": "text/html,application/xhtml+xml",
            "Accept-Language": "en-US,en;q=0.9",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=25) as response:
            return response.read().decode("utf-8", "ignore")
    except Exception:  # noqa: BLE001
        return ""


def first_post_link(html: str, domain: str) -> str | None:
    links = []
    for href in re.findall(r'href="([^"]+)"', html):
        if href.startswith("/"):
            href = domain + href
        if not href.startswith("http"):
            continue
        if not href.startswith(domain):
            continue
        if re.search(r"\.(css|js|png|jpg|webp|svg|ico)", href):
            continue
        if re.search(r"category|/tag|/page/|#|feed|wp-|login|register|contact", href):
            continue
        if href.rstrip("/") == domain.rstrip("/"):
            continue
        links.append(href)
    return links[0] if links else None


def main() -> int:
    if not os.path.exists(TRIAGE):
        print("run scripts/vega_triage.py --probe first", file=sys.stderr)
        return 2
    rows = json.load(open(TRIAGE, encoding="utf-8"))

    for row in rows:
        pid = (row.get("id") or "").lower()
        if pid in SHIPPED or row.get("status") == "shipped":
            continue
        domain = (row.get("domain") or "").rstrip("/")
        if not domain or row.get("http") != "200":
            continue
        if row.get("kind") not in ("direct-hub", "open-api", "html-scrape"):
            continue

        home = get(domain)
        post = first_post_link(home, domain)
        marker = ""
        if post:
            body = get(post)
            hits = [
                f"{host}={len(re.findall(re.escape(host), body, re.I))}"
                for host in HOST_MARKERS
                if re.search(re.escape(host), body, re.I)
            ]
            marker = f"{post} :: {', '.join(hits) if hits else 'no hosts'}"
        print(f"{row['id']:<14} {domain:<34} {marker}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
