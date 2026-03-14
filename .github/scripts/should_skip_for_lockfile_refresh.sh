#!/usr/bin/env bash
set -euo pipefail

skip=false
reason="head commit is not lockfile-refresh-only"

if [ "${GITHUB_EVENT_NAME:-}" = "pull_request" ]; then
  last_subject="$(git log -1 --pretty=%s)"

  if git rev-parse --verify HEAD^ >/dev/null 2>&1; then
    changed_files="$(git diff --name-only HEAD^ HEAD | sed '/^$/d')"
  else
    changed_files="$(git show --pretty='' --name-only HEAD | sed '/^$/d')"
  fi

  non_lockfile_count=0
  if [ -n "$changed_files" ]; then
    while IFS= read -r file; do
      if [ "$file" != "priv_signal.lockfile.json" ]; then
        non_lockfile_count=$((non_lockfile_count + 1))
      fi
    done <<< "$changed_files"
  fi

  case "$last_subject" in
    "chore(privsignal): refresh lockfile"*)
      if [ -n "$changed_files" ] && [ "$non_lockfile_count" = "0" ]; then
        skip=true
        reason="head commit is lockfile refresh only"
      fi
      ;;
  esac
fi

echo "skip=$skip" >> "$GITHUB_OUTPUT"
echo "reason=$reason" >> "$GITHUB_OUTPUT"
