#!/usr/bin/env python3
"""Validate the public CI dart-defines fixture (F30)."""
from __future__ import annotations

import json
import sys

FORBIDDEN_NONEMPTY = (
    "SHOPIFY_STOREFRONT_ACCESS_TOKEN",
    "CUSTOMER_ACCOUNT_CLIENT_ID",
    "FIREBASE_API_KEY",
    "FIREBASE_ANDROID_API_KEY",
    "FIREBASE_IOS_API_KEY",
    "NOTIFICATIONS_API_BASE_URL",
)
SECRETISH = ("shpat" + "_", "shpss" + "_", "shpca" + "_", "shppa" + "_", "BEGIN " + "PRIVATE KEY")


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: validate_ci_dart_defines.py config/dart_defines.ci.json", file=sys.stderr)
        return 2
    path = argv[1]
    data = json.load(open(path, encoding="utf-8"))
    for key in FORBIDDEN_NONEMPTY:
        value = data.get(key, "")
        if isinstance(value, str) and value.strip() != "":
            print(f"CI fixture {path} has non-empty {key}", file=sys.stderr)
            return 1
    if data.get("ENABLE_EXTERNAL_CATALOG") != "false":
        print(f"CI fixture {path} must keep ENABLE_EXTERNAL_CATALOG=false", file=sys.stderr)
        return 1
    blob = json.dumps(data)
    for token in SECRETISH:
        if token in blob:
            print(f"CI fixture {path} contains private-looking token {token}", file=sys.stderr)
            return 1
    print(f"OK: public CI dart-defines fixture validated: {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
