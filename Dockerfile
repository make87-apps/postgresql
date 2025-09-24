FROM postgres:17.6-alpine3.21

# Install tools
RUN apk add --no-cache bash jq aws-cli

# Add backup script
COPY backup-db.sh /usr/local/bin/backup-db.sh
RUN chmod +x /usr/local/bin/backup-db.sh \
    && mkdir -p /etc/periodic/daily \
    && ln -s /usr/local/bin/backup-db.sh /etc/periodic/daily/backup-db

# Start cron + postgres together
CMD ["sh", "-c", "crond -f -d 8 & exec docker-entrypoint.sh postgres"]
