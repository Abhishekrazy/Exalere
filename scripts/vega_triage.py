"""Classify every provider in Vega's manifest by how portable it is.

Porting rounds were spending their time rediscovering why a site cannot ship:
Turnstile tickets, 3-step "link safety" gates, dead domains, encrypted APIs.
This script does that sweep in one pass and writes docs/vega-triage.md, so the
next round starts from a sorted list instead of a hunch.

Usage:
    python scripts/vega_triage.py                  # classify from cached sources
    python scripts/vega_triage.py --probe          # also HTTP-probe each domain
    python scripts/vega_triage.py --vega-root DIR  # alternate Vega checkout
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.request

DEFAULT_VEGA_ROOT = os.path.join(".tmp_vega", "vega-providers-main")
OUTPUT = os.path.join("docs", "vega-triage.md")

GATE_MARKERS = {
    "turnstile": "Turnstile ticket (unsolvable)",
    "zipper": "3-step link-safety gate",
    "leechpro": "leechpro -> thenaukriadda gate",
    "thenaukriadda": "thenaukriadda shortlink",
    "gdflix": "GDFlix shortlink",
    "appdrive": "AppDrive shortlink",
    "driveseed": "DriveSeed shortlink",
}
CRYPTO_MARKERS = {
    "webcrypto": "WebCrypto/encrypted ids",
    "subtle.digest": "WebCrypto/encrypted ids",
    "passphrase": "decrypt API with passphrase",
    "atob(atob": "double-atob token",
}
OPEN_API_MARKERS = (
    "wp-json",
    "/api/",
    "advancedsearch",
    "api/public",
    ".json",
    "output=json",
    "metadata/",
)
DIRECT_MARKERS = ("hubcloud", "hubdrive", "nexdrive", "fastdl", "pixeldrain", "vcloud")

# Providers already shipped as native engines, with the module that implements them.
NATIVE = {
    "internetarchive": "lib/services/internet_archive_provider.dart",
    "torrentio": "lib/services/torrentio_provider.dart",
    "moviebox": "lib/plugins/moviebox",
    "4khdhub": "lib/plugins/fourkhdhub",
    "hdhub4u": "lib/services/hdhub4u_provider.dart",
    "movies4u": "lib/services/movies4u_provider.dart",
    "uhd": "lib/services/uhdmovies_provider.dart",
    "mod": "lib/services/moviesmod_provider.dart",
    "drive": "lib/services/moviesdrive_provider.dart",
    "luxmovies": "lib/services/rogmovies_provider.dart",
    "circleftp": "lib/plugins/circleftp",
    "dramacool": "lib/plugins/dramachi",
    "vidsrc": "lib/plugins/vidsrc",
    "tmdb": "lib/plugins/tmdb",
}


def read(path: str) -> str:
    try:
        with open(path, encoding="utf-8", errors="ignore") as handle:
            return handle.read()
    except OSError:
        return ""


def load_manifest(root: str) -> tuple[list[dict], dict[str, str]]:
    manifest_path = os.path.join(root, "manifest.json")
    manifest = json.loads(read(manifest_path))
    items = manifest if isinstance(manifest, list) else manifest.get("providers", [])

    urls_path = os.path.join(root, "urls.json")
    urls = json.loads(read(urls_path) or "{}")
    domain_by_name: dict[str, str] = {}
    for key, value in urls.items():
        if isinstance(value, dict):
            domain_by_name[key.lower()] = (value.get("url") or "").rstrip("/")
            domain_by_name[(value.get("name") or "").lower()] = (
                value.get("url") or ""
            ).rstrip("/")
    return items, domain_by_name


def classify(value: str, folder: str, source: str) -> tuple[str, str]:
    lower = source.lower()
    for marker, label in GATE_MARKERS.items():
        if marker in lower:
            return "gated", label
    for marker, label in CRYPTO_MARKERS.items():
        if marker in lower:
            return "encrypted", label
    if any(marker in lower for marker in DIRECT_MARKERS):
        return "direct-hub", "hubcloud/nexdrive family (scraper-shaped)"
    if any(marker in lower for marker in OPEN_API_MARKERS):
        return "open-api", "public JSON/HTML API"
    if "<article" in lower or "$(" in lower:
        return "html-scrape", "server-rendered listing"
    return "unknown", "no clear signal"


def ported_ids(repo: str) -> dict[str, str]:
    shipped: dict[str, str] = {}
    config = read(os.path.join(repo, "lib", "services", "scrapers", "vega_site_config.dart"))
    for match in re.finditer(r"id: '([a-z0-9_]+)'", config):
        shipped[match.group(1)] = "VegaSiteConfig"
    for key in NATIVE:
        shipped.setdefault(key, "Native engine")
    return shipped


def probe(url: str) -> str:
    if not url:
        return "-"
    request = urllib.request.Request(
        url, headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"}
    )
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            return str(response.status)
    except urllib.error.HTTPError as error:
        return str(error.code)
    except Exception:  # noqa: BLE001
        return "unreachable"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--vega-root", default=DEFAULT_VEGA_ROOT)
    parser.add_argument("--repo", default=".")
    parser.add_argument("--probe", action="store_true")
    parser.add_argument("--json", default=os.path.join(".tmp_shots", "vega_triage.json"))
    args = parser.parse_args()

    if not os.path.isdir(args.vega_root):
        print(f"Vega checkout not found: {args.vega_root}", file=sys.stderr)
        return 2

    items, domain_by_name = load_manifest(args.vega_root)
    shipped = ported_ids(args.repo)

    rows = []
    for item in items:
        value = item.get("value") or item.get("id") or ""
        folder = value
        display = item.get("display_name") or item.get("name") or value
        provider_dir = os.path.join(args.vega_root, "providers", folder)
        source = ""
        if os.path.isdir(provider_dir):
            for name in os.listdir(provider_dir):
                if name.endswith(".ts"):
                    source += read(os.path.join(provider_dir, name))
        domain = domain_by_name.get(value.lower()) or domain_by_name.get(display.lower()) or ""
        status = "shipped" if value.lower() in {k.lower() for k in shipped} else ""
        kind, reason = classify(value, folder, source)
        rows.append(
            {
                "id": value,
                "name": display,
                "domain": domain,
                "kind": kind,
                "reason": reason,
                "status": status,
                "http": probe(domain) if args.probe else "",
            }
        )

    os.makedirs(os.path.dirname(args.json), exist_ok=True)
    with open(args.json, "w", encoding="utf-8") as handle:
        json.dump(rows, handle, indent=2)

    groups: dict[str, list[dict]] = {}
    for row in rows:
        groups.setdefault(row["kind"], []).append(row)

    header = [
        "# Vega provider triage",
        "",
        "Generated by `python scripts/vega_triage.py --probe`.",
        "Every provider in Vega's manifest, grouped by what it would take to ship it.",
        "",
        f"Total: **{len(rows)}** · shipped: **{sum(1 for r in rows if r['status'])}**",
        "",
    ]
    titles = {
        "direct-hub": "HubCloud/nexdrive family — scraper-shaped, highest yield",
        "open-api": "Open API — JSON/HTML endpoints, no gate",
        "html-scrape": "Server-rendered pages — selector work",
        "encrypted": "Encrypted client logic — needs a port of the crypto",
        "gated": "Gated — Turnstile / link-safety / shortlinks (not solved)",
        "unknown": "Unclassified — inspect by hand",
    }
    for kind in ["direct-hub", "open-api", "html-scrape", "encrypted", "gated", "unknown"]:
        bucket = groups.get(kind, [])
        if not bucket:
            continue
        header += [f"## {titles[kind]} ({len(bucket)})", "", "| Provider | Domain | HTTP | Status | Why |", "|---|---|---|---|---|"]
        for row in sorted(bucket, key=lambda r: r["name"].lower()):
            header.append(
                f"| {row['name']} (`{row['id']}`) | {row['domain'] or '-'} | "
                f"{row['http'] or '-'} | {row['status'] or 'open'} | {row['reason']} |"
            )
        header.append("")

    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    with open(OUTPUT, "w", encoding="utf-8") as handle:
        handle.write("\n".join(header))

    counts: dict[str, int] = {}
    for row in rows:
        counts[row["kind"]] = counts.get(row["kind"], 0) + 1
    print("wrote", OUTPUT)
    print("shipped:", sum(1 for r in rows if r["status"]), "/", len(rows))
    for kind, count in sorted(counts.items(), key=lambda kv: -kv[1]):
        print(f"  {kind}: {count}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
