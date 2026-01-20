#!/bin/bash

# Automated Backup Script - Run via Cron
# Schedule: 0 2 * * * (Daily at 2 AM)

set -e

BACKUP_DIR="/backups"
RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-7}
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$BACKUP_DIR/backup_${TIMESTAMP}.log"

echo "🔄 Starting automated backup at $(date)" | tee -a "$LOG_FILE"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Get list of all sites
SITES=$(cat /home/frappe/frappe-bench/sites/sites.txt 2>/dev/null || echo "")

if [ -z "$SITES" ]; then
    echo "⚠️  No sites found to backup" | tee -a "$LOG_FILE"
    exit 0
fi

# Backup each site
while IFS= read -r site; do
    if [ ! -z "$site" ]; then
        echo "📦 Backing up site: $site" | tee -a "$LOG_FILE"
        
        SITE_BACKUP_DIR="$BACKUP_DIR/$site"
        mkdir -p "$SITE_BACKUP_DIR"
        
        # Backup database and files
        bench --site "$site" backup \
            --with-files \
            --backup-path "$SITE_BACKUP_DIR" \
            2>&1 | tee -a "$LOG_FILE"
        
        # Compress backup
        cd "$BACKUP_DIR"
        tar -czf "${site}_${TIMESTAMP}.tar.gz" "$site" 2>&1 | tee -a "$LOG_FILE"
        
        # Upload to S3 if enabled
        if [ "$S3_BACKUP_ENABLED" = "true" ]; then
            echo "☁️  Uploading to S3: $S3_BUCKET" | tee -a "$LOG_FILE"
            aws s3 cp "${site}_${TIMESTAMP}.tar.gz" \
                "s3://$S3_BUCKET/backups/$site/" \
                2>&1 | tee -a "$LOG_FILE"
        fi
        
        echo "✅ Backup completed for $site" | tee -a "$LOG_FILE"
    fi
done <<< "$SITES"

# Cleanup old backups
echo "🧹 Cleaning up backups older than $RETENTION_DAYS days" | tee -a "$LOG_FILE"
find "$BACKUP_DIR" -name "*.tar.gz" -mtime "+$RETENTION_DAYS" -delete 2>&1 | tee -a "$LOG_FILE"

# Cleanup old logs
find "$BACKUP_DIR" -name "backup_*.log" -mtime +30 -delete

echo "✅ Automated backup completed at $(date)" | tee -a "$LOG_FILE"

# Send notification (optional - requires setup)
# curl -X POST https://your-webhook-url.com/notify \
#     -H "Content-Type: application/json" \
#     -d "{\"message\": \"Backup completed successfully\", \"timestamp\": \"$TIMESTAMP\"}"
