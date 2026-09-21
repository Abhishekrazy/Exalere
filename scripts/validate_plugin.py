#!/usr/bin/env python3
"""
Exalere Plugin Manifest Validator
Validates that a plugin URL or manifest file conforms to the Exalere Plugin Protocol.

Usage:
  python scripts/validate_plugin.py --url https://my-plugin.workers.dev/manifest.json
  python scripts/validate_plugin.py --file docs/plugins.json
"""

import argparse
import json
import sys
import urllib.request
import urllib.error

REQUIRED_MANIFEST_FIELDS = ['id', 'name', 'version', 'description', 'resources', 'types']
ALLOWED_RESOURCES = {'stream', 'catalog', 'subtitles', 'meta'}
ALLOWED_TYPES = {'movie', 'series', 'anime', 'tv', 'channel', 'other'}

def validate_manifest_dict(data, source_name="Manifest"):
    errors = []
    warnings = []

    for field in REQUIRED_MANIFEST_FIELDS:
        if field not in data or not data[field]:
            errors.append(f"Missing required field: '{field}'")

    if 'id' in data and not isinstance(data['id'], str):
        errors.append("Field 'id' must be a non-empty string.")
    
    if 'resources' in data:
        raw_resources = data['resources']
        if not isinstance(raw_resources, list) or len(raw_resources) == 0:
            errors.append("Field 'resources' must be a non-empty array.")
        else:
            found_supported = False
            for res in raw_resources:
                name = res if isinstance(res, str) else res.get('name') if isinstance(res, dict) else None
                if name in ALLOWED_RESOURCES:
                    found_supported = True
            if not found_supported:
                warnings.append(f"No standard resources found in resources list: {raw_resources}")

    if 'types' in data:
        raw_types = data['types']
        if not isinstance(raw_types, list) or len(raw_types) == 0:
            warnings.append("Field 'types' is empty; recommended to specify at least ['movie'] or ['series'].")

    return errors, warnings

def validate_url(url):
    print(f"[*] Validating remote manifest URL: {url}")
    if not url.startswith("https://") and not url.startswith("http://"):
        print("[!] Error: URL must start with https:// or http://")
        return False

    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "Exalere-Plugin-Validator/1.0",
            "Accept": "application/json"
        }
    )

    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            if resp.status != 200:
                print(f"[!] HTTP error: Received status code {resp.status}")
                return False
            
            # Check CORS header
            cors = resp.headers.get("Access-Control-Allow-Origin")
            if not cors:
                print("[!] Warning: Missing 'Access-Control-Allow-Origin' header (recommended '*' for cross-origin web/client requests).")

            raw = resp.read().decode('utf-8')
            data = json.loads(raw)
    except urllib.error.URLError as e:
        print(f"[!] Network error: {e}")
        return False
    except json.JSONDecodeError as e:
        print(f"[!] JSON parse error: {e}")
        return False
    except Exception as e:
        print(f"[!] Unexpected error: {e}")
        return False

    errors, warnings = validate_manifest_dict(data, url)
    for w in warnings:
        print(f"  [~] Warning: {w}")
    if errors:
        for err in errors:
            print(f"  [X] Error: {err}")
        return False

    print(f"[OK] Manifest '{data.get('name')}' ({data.get('id')} v{data.get('version')}) is VALID!")
    return True

def validate_catalog_file(filepath):
    print(f"[*] Validating community catalog file: {filepath}")
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            catalog = json.load(f)
    except Exception as e:
        print(f"[!] Could not read file: {e}")
        return False

    if not isinstance(catalog, list):
        print("[!] Error: Catalog must be a JSON array of plugin items.")
        return False

    all_valid = True
    seen_ids = set()
    for idx, item in enumerate(catalog):
        name = item.get('name', f"Item #{idx}")
        item_id = item.get('id')
        manifest_url = item.get('manifestUrl')

        if not item_id:
            print(f"  [X] Item #{idx} ({name}) is missing 'id'.")
            all_valid = False
        elif item_id in seen_ids:
            print(f"  [X] Duplicate ID found: '{item_id}'")
            all_valid = False
        else:
            seen_ids.add(item_id)

        if not manifest_url:
            print(f"  [X] Item '{item_id}' is missing 'manifestUrl'.")
            all_valid = False

    if all_valid:
        print(f"[OK] Catalog file '{filepath}' passed with {len(catalog)} plugin entries!")
    return all_valid

def main():
    parser = argparse.ArgumentParser(description="Validate Exalere plugins and catalogs.")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--url', type=str, help="URL of the remote /manifest.json")
    group.add_argument('--file', type=str, help="Local catalog JSON file (e.g., docs/plugins.json)")

    args = parser.parse_args()
    if args.url:
        success = validate_url(args.url)
    elif args.file:
        success = validate_catalog_file(args.file)
    else:
        parser.print_help()
        sys.exit(1)

    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
