set -euo pipefail

: "${POSTGRES_HOST?Need POSTGRES_HOST}"
: "${POSTGRES_DB?Need POSTGRES_DB}"
: "${POSTGRES_USER?Need POSTGRES_USER}"

BACKUP_DIR="${BACKUP_DIR:-/backups}"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"

mkdir -p "$BACKUP_DIR"
if [ ! -w "$BACKUP_DIR" ]; then
  echo "Backup directory $BACKUP_DIR is not writable" >&2
  exit 1
fi

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_FILE="${BACKUP_DIR%/}/${POSTGRES_DB}-${TIMESTAMP}.sql.gz"

echo "Starting backup to ${BACKUP_FILE}"

pg_dump \
  -h "$POSTGRES_HOST" \
  -U "$POSTGRES_USER" \
  "$POSTGRES_DB" \
| gzip > "$BACKUP_FILE"

echo "Backup completed."

# Simple retention: delete files older than BACKUP_RETENTION_DAYS
echo "Deleting backups older than ${BACKUP_RETENTION_DAYS} days..."
find "$BACKUP_DIR" -type f -mtime +${BACKUP_RETENTION_DAYS} -print -delete || true

echo "Done."
