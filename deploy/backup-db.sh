#!/usr/bin/env bash
# Nightly pg_dump of endpoint_db, keeping the last KEEP_DAYS days.
# Installed to /usr/local/bin/endpoint-backup-db.sh and run as the postgres user
# from /etc/cron.d/endpoint-backup (see setup-server.sh).
set -euo pipefail

DB_NAME="${DB_NAME:-endpoint_db}"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/endpoint}"
KEEP_DAYS="${KEEP_DAYS:-14}"

file="$BACKUP_DIR/${DB_NAME}-$(date +%Y%m%d-%H%M).dump"
pg_dump -Fc -f "$file.partial" "$DB_NAME"
mv "$file.partial" "$file"

find "$BACKUP_DIR" -name "${DB_NAME}-*.dump" -mtime +"$KEEP_DAYS" -delete
