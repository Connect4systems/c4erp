#!/bin/bash

# Backup Site Script
# Usage: ./backup-site.sh sitename.com

set -e

SITE_NAME=$1
BACKUP_DIR="./backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

if [ -z "$SITE_NAME" ]; then
    echo "Usage: $0 <sitename.com>"
    exit 1
fi

mkdir -p "$BACKUP_DIR/$SITE_NAME"

echo "🔄 Backing up site: $SITE_NAME"

# Backup database
docker-compose exec frappe bench --site $SITE_NAME backup \
    --with-files \
    --backup-path "/home/frappe/backups"

# Copy backups to local directory
docker cp $(docker-compose ps -q frappe):/home/frappe/backups/. "$BACKUP_DIR/$SITE_NAME/"

# Create timestamped archive
cd "$BACKUP_DIR"
tar -czf "${SITE_NAME}_${TIMESTAMP}.tar.gz" "$SITE_NAME"
cd -

echo "✅ Backup completed: $BACKUP_DIR/${SITE_NAME}_${TIMESTAMP}.tar.gz"

# Clean old backups (keep last 7 days)
find "$BACKUP_DIR" -name "${SITE_NAME}_*.tar.gz" -mtime +7 -delete

echo "🧹 Old backups cleaned (retention: 7 days)"
