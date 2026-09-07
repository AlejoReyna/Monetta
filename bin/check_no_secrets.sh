#!/usr/bin/env bash
# Fail if tracked or non-ignored untracked files look like they contain
# private credentials. This is the same set `git add --all` could stage.
# Public Storefront tokens and public client IDs are allowed in example
# templates only as placeholders — real filled dart-define files must stay
# gitignored.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

fail=0
candidate_files=()
while IFS= read -r -d '' file; do
  candidate_files+=("$file")
done < <(git ls-files --cached --others --exclude-standard -z)

# Real env files must never be candidates for a commit.
for f in "${candidate_files[@]}"; do
  if [[ "$f" =~ (^|/)\.env(\.|$) ]]; then
    case "$f" in
      *.example) ;;
      *)
        echo "FAIL: env file is tracked or untracked-and-visible: $f"
        fail=1
        ;;
    esac
  fi
done

# Filled dart-define files must not be candidates for a commit.
# Narrow exception: config/dart_defines.ci.json is the public CI compile fixture
# (empty tokens / flags only). Still validate its contents below; never widen
# this to staging/production dart-defines (F30).
for f in "${candidate_files[@]}"; do
  case "$f" in
    *.example) ;;
    config/dart_defines.ci.json)
      if ! python3 bin/validate_ci_dart_defines.py "$f"; then
        echo "FAIL: public CI dart-defines fixture failed content validation: $f"
        fail=1
      fi
      ;;
    config/dart_defines*.json)
      echo "FAIL: dart-define file is tracked or untracked-and-visible: $f"
      fail=1
      ;;
  esac
done

# Scan candidate text for high-confidence private patterns (not public tokens).
# Length floors avoid fixture strings like shpss_test_secret in unit tests.
# Every candidate is scanned, including docs, examples, and tests. Only this
# script is excluded because it necessarily contains the patterns themselves.
patterns=(
  'shpss_[A-Za-z0-9]{20,}'
  'shpat_[A-Za-z0-9]{20,}'
  'shpca_[A-Za-z0-9]{20,}'
  'shppa_[A-Za-z0-9]{20,}'
  '-----BEGIN (RSA |OPENSSH |EC )?PRIVATE KEY-----'
  'BEGIN PRIVATE KEY'
)

scan_files=()
for f in "${candidate_files[@]}"; do
  case "$f" in bin/check_no_secrets.sh|bin/validate_ci_dart_defines.py) ;; *) scan_files+=("$f") ;; esac
done

for pat in "${patterns[@]}"; do
  # Print filenames only. A failed check must not echo the credential itself.
  if matches=$(grep -IEl -- "$pat" "${scan_files[@]}" 2>/dev/null || true); then
    if [[ -n "$matches" ]]; then
      echo "FAIL: private-looking secret pattern /$pat/ in commit candidates:"
      echo "$matches"
      fail=1
    fi
  fi
done

if [[ "$fail" -ne 0 ]]; then
  echo
  echo "Secret check failed. Remove the files/values before staging or committing."
  exit 1
fi

echo "OK: no private secret patterns found in tracked or commit-candidate files."
