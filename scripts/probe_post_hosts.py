"""Follow each site's first content page and report which stream hosts it uses.

The point is evidence, not guesses: a provider is only worth porting when a post
page actually exposes hubcloud/fastdl/nexdrive/pixeldrain/direct-file/m3u8 links.
Gated sites show a shortlink or a challenge page instead.

Usage:
    python scripts/probe_post_hosts.py https://example.com https://other.tld
"""

from __future__ import annotations

import re
import sys
import urllib.error
import urllib.request

UA = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
)

HOST_MARKERS = [
    "hubcloud",
    "fastdl",
    "nexdrive",
    "pixeldrain",
    "m3u8",
    "gdtot",
    "filepress",
    "streamtape",
    "leechpro",
    "thenaukriadda",
    "gdfllix",
    "driveseed",
    ".mkv",
    ".mp4",
]
ASSET = re.compile(r"\.(css|js|png|jpe?g|webp|gif|svg|ico|woff2?)(\?|$)", re.I)
SKIP = re.compile(
    r"/(category|tag|page|dmca|contact|privacy|about|feed|wp-|xmlrpc|rss|"
    r"search|login|register|author|comment)",
    re.I,
)


def fetch(url: str) -> tuple[int, str]:
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
            return response.status, response.read().decode("utf-8", "ignore")
    except urllib.error.HTTPError as error:
        return error.code, ""
    except Exception:  # noqa: BLE001
        return 0, ""


def candidates(home: str, base: str) -> list[str]:
    links = []
    for href in re.findall(r'href="([^"]+)"', home):
        if href.startswith("/"):
            href = base.rstrip("/") + href
        if not href.startswith(base):
            continue
        if ASSET.search(href) or SKIP.search(href):
            continue
        if href.rstrip("/") == base.rstrip("/"):
            continue
        links.append(href)
    # A post slug carries a year or several words; a section index does not.
    def score(link: str) -> int:
        tail = link.rstrip("/").rsplit("/", 1)[-1]
        points = 0
        if re.search(r"20\d\d", tail):
            points += 3
        points += min(3, tail.count("-"))
        if re.search(r"/(genre|ott|language|category|collection)/", link):
            points -= 5
        return points

    links.sort(key=score, reverse=True)
    return links[:3]


def main() -> int:
    for site in sys.argv[1:]:
        base = site.rstrip("/")
        status, home = fetch(base)
        print(f"== {base} home={status} chars={len(home)}")
        if not home:
            continue
        for link in candidates(home, base):
            status, body = fetch(link)
            hits = [
                f"{marker}={len(re.findall(re.escape(marker), body, re.I))}"
                for marker in HOST_MARKERS
                if re.search(re.escape(marker), body, re.I)
            ]
            print(
                f"   {status} {len(body):>7} {link}\n      "
                f"{', '.join(hits) if hits else 'no stream hosts'}"
            )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
