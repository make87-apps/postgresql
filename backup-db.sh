#!/bin/sh
set -eu

ACCESS_KEY=$(echo "$MAKE87_CONFIG" | jq -r '.storage.access_key // empty')
SECRET_KEY=$(echo "$MAKE87_CONFIG" | jq -r '.storage.secret_key // empty')

if [ -z "$ACCESS_KEY" ] || [ -z "$SECRET_KEY" ]; then
  echo "Skipping backup: no storage credentials"
  exit 0
fi

ENDPOINT_URL=$(echo "$MAKE87_CONFIG" | jq -r '.storage.endpoint_url')
BUCKET_PATH=$(echo "$MAKE87_CONFIG" | jq -r '.storage.url')
NUM_BACKUPS=$(echo "$MAKE87_CONFIG" | jq -r '.config.num_backups // 5')

BUCKET=$(echo "$BUCKET_PATH" | cut -d/ -f2)
PREFIX=$(echo "$BUCKET_PATH" | cut -d/ -f3-)

BACKUP_FILE="/tmp/db-$(date +%Y%m%d-%H%M%S).sql.gz"

pg_dump -h "$PGHOST" -U "$PGUSER" "$PGDATABASE" | gzip > "$BACKUP_FILE"

AWS_ACCESS_KEY_ID=$ACCESS_KEY \
AWS_SECRET_ACCESS_KEY=$SECRET_KEY \
aws --endpoint-url "$ENDPOINT_URL" \
    s3 cp "$BACKUP_FILE" "s3://$BUCKET/$PREFIX/$(basename "$BACKUP_FILE")"

rm -f "$BACKUP_FILE"

# Keep only N newest backups
AWS_ACCESS_KEY_ID=$ACCESS_KEY \
AWS_SECRET_ACCESS_KEY=$SECRET_KEY \
aws --endpoint-url "$ENDPOINT_URL" \
    s3 ls "s3://$BUCKET/$PREFIX/" \
  | sort \
  | awk '{print $4}' \
  | head -n -"$NUM_BACKUPS" \
  | while read -r old; do
        [ -n "$old" ] && aws --endpoint-url "$ENDPOINT_URL" \
            s3 rm "s3://$BUCKET/$PREFIX/$old"
    done
