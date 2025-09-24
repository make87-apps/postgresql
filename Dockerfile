FROM postgres:17.6-alpine3.21

# Install needed tools
RUN apk add --no-cache bash jq aws-cli

# Add backup script
COPY backup-db.sh /usr/local/bin/backup-db.sh
RUN chmod +x /usr/local/bin/backup-db.sh \
    && mkdir -p /etc/periodic/daily \
    && ln -s /usr/local/bin/backup-db.sh /etc/periodic/daily/backup-db

# Add custom entrypoint that sets up Postgres + cron
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Always go through our wrapper
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Default command (will be passed to docker-entrypoint.sh by your script)
CMD ["postgres"]
