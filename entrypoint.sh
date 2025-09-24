#!/bin/sh
set -eu

resolve_secret() {
  val="$1"

  # Regex: {{ secret.NAME }}
  if echo "$val" | grep -Eq '^\s*\{\{\s*secret\.[A-Za-z0-9_]+\s*}}\s*$'; then
    # Extract NAME
    name=$(echo "$val" | sed -E 's/^\s*\{\{\s*secret\.([A-Za-z0-9_]+)\s*}}\s*$/\1/')
    path="/run/secrets/${name}.secret"
    if [ -f "$path" ]; then
      cat "$path"
    else
      echo "Missing secret file: $path" >&2
      exit 1
    fi
  else
    echo "$val"
  fi
}

# Extract Postgres creds from MAKE87_CONFIG
RAW_USER=$(echo "$MAKE87_CONFIG" | jq -r '.config.postgres_user // "postgres"')
RAW_PASS=$(echo "$MAKE87_CONFIG" | jq -r '.config.postgres_password // empty')
RAW_DB=$(echo "$MAKE87_CONFIG" | jq -r '.config.postgres_db // "postgres"')

export POSTGRES_USER=$(resolve_secret "$RAW_USER")
export POSTGRES_PASSWORD=$(resolve_secret "$RAW_PASS")
export POSTGRES_DB=$(resolve_secret "$RAW_DB")

# Check storage creds
ACCESS_KEY=$(echo "$MAKE87_CONFIG" | jq -r '.storage.access_key // empty')
SECRET_KEY=$(echo "$MAKE87_CONFIG" | jq -r '.storage.secret_key // empty')

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
