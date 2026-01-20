#!/bin/bash

# Install Custom App Script
# Usage: ./install-app.sh sitename.com https://github.com/user/app-name

set -e

SITE_NAME=$1
APP_REPO=$2
APP_NAME=$(basename "$APP_REPO" .git)

if [ -z "$SITE_NAME" ] || [ -z "$APP_REPO" ]; then
    echo "Usage: $0 <sitename.com> <git-repo-url>"
    exit 1
fi

echo "📦 Installing custom app: $APP_NAME"
echo "Site: $SITE_NAME"

# Get app
docker-compose exec frappe bench get-app "$APP_REPO"

# Install app on site
docker-compose exec frappe bench --site "$SITE_NAME" install-app "$APP_NAME"

# Migrate
docker-compose exec frappe bench --site "$SITE_NAME" migrate

# Build assets
docker-compose exec frappe bench build

# Restart
docker-compose restart frappe frappe-worker

echo "✅ Custom app installed successfully!"
echo "App: $APP_NAME"
echo "Site: $SITE_NAME"
