#!/bin/bash

# Restore Site Script
# Usage: ./restore-site.sh sitename.com backup-file.tar.gz

set -e

SITE_NAME=$1
BACKUP_FILE=$2

if [ -z "$SITE_NAME" ] || [ -z "$BACKUP_FILE" ]; then
    echo "Usage: $0 <sitename.com> <backup-file.tar.gz>"
    exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
    echo "Error: Backup file not found: $BACKUP_FILE"
    exit 1
fi

echo "🔄 Restoring site: $SITE_NAME from $BACKUP_FILE"

# Extract backup
TEMP_DIR=$(mktemp -d)
tar -xzf "$BACKUP_FILE" -C "$TEMP_DIR"

# Copy backups to container
docker cp "$TEMP_DIR/$SITE_NAME/." $(docker-compose ps -q frappe):/home/frappe/restore/

# Restore database and files
docker-compose exec frappe bench --site $SITE_NAME restore \
    --mariadb-root-password "$MYSQL_ROOT_PASSWORD" \
    /home/frappe/restore/

# Cleanup
rm -rf "$TEMP_DIR"

echo "✅ Site restored successfully!"
echo "Site URL: https://$SITE_NAME"
