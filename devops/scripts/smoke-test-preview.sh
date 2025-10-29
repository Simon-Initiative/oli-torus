#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -lt 1 ]]; then
  echo "usage: $0 <url> [additional urls...]" >&2
  exit 1
fi

RESULT=0

for url in "$@"; do
  echo "Checking ${url}..."
  if ! curl -fsSL --max-time 10 "${url}"; then
    echo "ERROR: probe failed for ${url}" >&2
    RESULT=1
  else
    echo "OK: ${url}"
  fi
done

exit "${RESULT}"
