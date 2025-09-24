#!/bin/sh
set -eu

# Extract storage creds
ACCESS_KEY=$(echo "$MAKE87_CONFIG" | jq -r '.storage.access_key // empty')
SECRET_KEY=$(echo "$MAKE87_CONFIG" | jq -r '.storage.secret_key // empty')

# Only set up cron if creds exist
if [ -n "$ACCESS_KEY" ] && [ -n "$SECRET_KEY" ]; then
  NUM_BACKUPS=$(echo "$MAKE87_CONFIG" | jq -r '.config.num_backups // 5')
  BACKUP_TIME=$(echo "$MAKE87_CONFIG" | jq -r '.config.backup_time // "02:00"')

  HOUR=$(echo "$BACKUP_TIME" | cut -d: -f1)
  MIN=$(echo "$BACKUP_TIME" | cut -d: -f2)

  mkdir -p /etc/crontabs
  echo "$MIN $HOUR * * * /usr/local/bin/backup-db.sh" > /etc/crontabs/root

  echo "Configured backup: keep $NUM_BACKUPS backups, run daily at $BACKUP_TIME"
  crond -f -d 8 &
else
  echo "No storage credentials in MAKE87_CONFIG → skipping backup cron"
fi

# Always start postgres
exec docker-entrypoint.sh postgres
