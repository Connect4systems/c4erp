#!/bin/bash

# Create Site Script for Frappe/ERPNext SaaS
# Usage: ./create-site.sh sitename.com admin@email.com [admin-password]

set -e

SITE_NAME=$1
ADMIN_EMAIL=$2
ADMIN_PASSWORD=${3:-$(openssl rand -base64 12)}

if [ -z "$SITE_NAME" ] || [ -z "$ADMIN_EMAIL" ]; then
    echo "Usage: $0 <sitename.com> <admin@email.com> [admin-password]"
    exit 1
fi

echo "Creating new site: $SITE_NAME"
echo "Admin Email: $ADMIN_EMAIL"

# Create site using bench
docker-compose exec frappe bench new-site $SITE_NAME \
    --admin-password "$ADMIN_PASSWORD" \
    --db-name "${SITE_NAME//./_}" \
    --mariadb-root-password "$MYSQL_ROOT_PASSWORD" \
    --install-app erpnext \
    --set-default

# Set site configuration
docker-compose exec frappe bench --site $SITE_NAME set-config developer_mode 0
docker-compose exec frappe bench --site $SITE_NAME set-config enable_scheduler 1
docker-compose exec frappe bench --site $SITE_NAME set-config auto_email_id "$ADMIN_EMAIL"

# Add to sites list
echo "$SITE_NAME" >> sites/sites.txt

# Reload Nginx configuration
docker-compose exec nginx nginx -s reload

echo "✅ Site created successfully!"
echo ""
echo "Site URL: https://$SITE_NAME"
echo "Administrator Email: $ADMIN_EMAIL"
echo "Administrator Password: $ADMIN_PASSWORD"
echo ""
echo "⚠️  Please save these credentials securely!"
