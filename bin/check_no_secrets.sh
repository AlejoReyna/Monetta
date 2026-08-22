#!/usr/bin/env bash
# Fail if tracked files look like they contain private credentials.
# Public Storefront tokens and public client IDs are allowed in example
# templates only as placeholders — real filled dart-define files must stay
# gitignored.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

fail=0

# Real env files must never be tracked.
if git ls-files --error-unmatch .env >/dev/null 2>&1; then
  echo "FAIL: .env is tracked by git"
  fail=1
fi
while IFS= read -r f; do
  case "$f" in
    *.example) ;;
    *)
      echo "FAIL: env file is tracked: $f"
      fail=1
      ;;
  esac
done < <(git ls-files | grep -E '(^|/)\.env(\.|$)' || true)

# Filled dart-define files must not be tracked.
while IFS= read -r f; do
  case "$f" in
    *.example) ;;
    config/dart_defines*.json)
      echo "FAIL: dart-define file is tracked (should be gitignored): $f"
      fail=1
      ;;
  esac
done < <(git ls-files 'config/dart_defines*.json' || true)

# Scan tracked text for high-confidence private patterns (not public tokens).
# Length floors avoid fixture strings like shpss_test_secret in unit tests.
# Still excludes docs, examples, and this script.
patterns=(
  'shpss_[A-Za-z0-9]{20,}'
  'shpat_[A-Za-z0-9]{20,}'
  'shpca_[A-Za-z0-9]{20,}'
  'shppa_[A-Za-z0-9]{20,}'
  '-----BEGIN (RSA |OPENSSH |EC )?PRIVATE KEY-----'
  'BEGIN PRIVATE KEY'
)

for pat in "${patterns[@]}"; do
  # git grep exits 1 when no match — that is success for us.
  if matches=$(git grep -nE "$pat" -- \
      ':!bin/check_no_secrets.sh' \
      ':!docs/**' \
      ':!**/*.md' \
      ':!**/*.example' \
      ':!**/test/**' \
      2>/dev/null || true); then
    if [[ -n "${matches}" ]]; then
      echo "FAIL: private-looking secret pattern /$pat/ in tracked files:"
      echo "$matches"
      fail=1
    fi
  fi
done

if [[ "$fail" -ne 0 ]]; then
  echo
  echo "Secret check failed. Remove the files/values from git history if they were committed."
  exit 1
fi

echo "OK: no private secret patterns found in tracked files."
