#!/bin/bash

# Delete Site Script
# Usage: ./delete-site.sh sitename.com

set -e

SITE_NAME=$1

if [ -z "$SITE_NAME" ]; then
    echo "Usage: $0 <sitename.com>"
    exit 1
fi

echo "⚠️  WARNING: This will permanently delete $SITE_NAME"
read -p "Are you sure? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Operation cancelled."
    exit 0
fi

echo "🔄 Creating final backup before deletion..."
./scripts/backup-site.sh "$SITE_NAME"

echo "🗑️  Deleting site: $SITE_NAME"

# Drop site
docker-compose exec frappe bench drop-site $SITE_NAME \
    --mariadb-root-password "$MYSQL_ROOT_PASSWORD" \
    --force

# Remove from sites list
sed -i "/$SITE_NAME/d" sites/sites.txt

# Reload Nginx
docker-compose exec nginx nginx -s reload

echo "✅ Site deleted successfully!"
