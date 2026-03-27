#!/bin/bash
set -euo pipefail

# Prevent overlapping runs
exec 9>/var/lock/clickhouse-backup.lock
flock -n 9 || { echo "Backup already running; exiting."; exit 0; }

DATE=$(date -u +%Y-%m-%d)
DOW=$(date -u +%u) # 1=Mon ... 7=Sun

if [ "$DOW" -eq 7 ]; then
  BACKUP_NAME=clickhouse-backup_${DATE}_full
  echo "Running WEEKLY FULL backup: $BACKUP_NAME"
  clickhouse-backup create "$BACKUP_NAME"
else
  BASE=$(clickhouse-backup list remote \
    | awk '{print $1}' \
    | grep '_full$' \
    | tail -n 1 || true)

  if [ -z "${BASE:-}" ]; then
    BACKUP_NAME=clickhouse-backup_${DATE}_full
    echo "No FULL backup found — creating FULL instead: $BACKUP_NAME"
    clickhouse-backup create "$BACKUP_NAME"
  else
    BACKUP_NAME=clickhouse-backup_${DATE}_diff
    echo "Running DAILY DIFF from $BASE → $BACKUP_NAME"
    clickhouse-backup create --diff-from-remote "$BASE" "$BACKUP_NAME"
  fi
fi
