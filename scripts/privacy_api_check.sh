#!/usr/bin/env bash
# Fails if runtime code starts using APIs that would violate LayoutLight's
# geometry-only, no-text-capture, no-telemetry privacy invariant.

set -euo pipefail

cd "$(dirname "$0")/.."

forbidden_patterns=(
  'URLSession'
  'NSPasteboard'
  '\bProcess\('
  '\bProcess\.'
  'SecItem(Add|Copy|Update|Delete)'
  '\bKeychain\b'
  'CFSocket'
  'NWConnection'
  'NWListener'
  'Network\.framework'
  'kAXValueAttribute'
  '"AXValue"'
)

status=0
for pattern in "${forbidden_patterns[@]}"; do
  if matches=$(rg -n -I --pcre2 "$pattern" LayoutLight); then
    echo "Forbidden privacy-sensitive API pattern found: $pattern" >&2
    echo "$matches" >&2
    status=1
  fi
done

exit "$status"
