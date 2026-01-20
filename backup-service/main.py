#!/usr/bin/env python3
"""
Backup Service for Frappe/ERPNext SaaS
Runs scheduled backups and manages retention
"""

import os
import sys
import subprocess
import logging
from datetime import datetime
from pathlib import Path
import schedule
import time

# Configuration
BACKUP_DIR = os.getenv('BACKUP_DIR', '/backups')
RETENTION_DAYS = int(os.getenv('BACKUP_RETENTION_DAYS', 7))
S3_ENABLED = os.getenv('S3_BACKUP_ENABLED', 'false').lower() == 'true'
S3_BUCKET = os.getenv('S3_BUCKET', '')

# Logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def get_all_sites():
    """Get list of all Frappe sites"""
    sites_file = Path('/home/frappe/frappe-bench/sites/sites.txt')
    if not sites_file.exists():
        logger.warning("No sites.txt found")
        return []
    
    with open(sites_file, 'r') as f:
        sites = [line.strip() for line in f if line.strip()]
    
    return sites


def backup_site(site_name):
    """Backup a single site"""
    logger.info(f"Starting backup for site: {site_name}")
    
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    site_backup_dir = Path(BACKUP_DIR) / site_name
    site_backup_dir.mkdir(parents=True, exist_ok=True)
    
    try:
        # Run bench backup
        cmd = [
            'bench', '--site', site_name, 'backup',
            '--with-files',
            '--backup-path', str(site_backup_dir)
        ]
        
        subprocess.run(cmd, check=True, capture_output=True)
        
        # Compress backup
        backup_archive = Path(BACKUP_DIR) / f"{site_name}_{timestamp}.tar.gz"
        subprocess.run([
            'tar', '-czf', str(backup_archive),
            '-C', BACKUP_DIR, site_name
        ], check=True)
        
        logger.info(f"Backup created: {backup_archive}")
        
        # Upload to S3 if enabled
        if S3_ENABLED and S3_BUCKET:
            upload_to_s3(backup_archive, site_name)
        
        return True
        
    except subprocess.CalledProcessError as e:
        logger.error(f"Backup failed for {site_name}: {e}")
        return False


def upload_to_s3(backup_file, site_name):
    """Upload backup to S3"""
    try:
        import boto3
        
        s3 = boto3.client('s3')
        s3_key = f"backups/{site_name}/{backup_file.name}"
        
        logger.info(f"Uploading to S3: {S3_BUCKET}/{s3_key}")
        s3.upload_file(str(backup_file), S3_BUCKET, s3_key)
        logger.info("S3 upload successful")
        
    except Exception as e:
        logger.error(f"S3 upload failed: {e}")


def cleanup_old_backups():
    """Remove backups older than retention period"""
    logger.info(f"Cleaning up backups older than {RETENTION_DAYS} days")
    
    backup_path = Path(BACKUP_DIR)
    cutoff_time = time.time() - (RETENTION_DAYS * 86400)
    
    for backup_file in backup_path.glob("*.tar.gz"):
        if backup_file.stat().st_mtime < cutoff_time:
            logger.info(f"Deleting old backup: {backup_file.name}")
            backup_file.unlink()


def run_backup_job():
    """Main backup job"""
    logger.info("=" * 50)
    logger.info("Starting automated backup job")
    logger.info("=" * 50)
    
    sites = get_all_sites()
    
    if not sites:
        logger.warning("No sites found to backup")
        return
    
    success_count = 0
    failed_count = 0
    
    for site in sites:
        if backup_site(site):
            success_count += 1
        else:
            failed_count += 1
    
    cleanup_old_backups()
    
    logger.info("=" * 50)
    logger.info(f"Backup job completed. Success: {success_count}, Failed: {failed_count}")
    logger.info("=" * 50)


def main():
    """Main entry point"""
    logger.info("Backup Service Started")
    logger.info(f"Backup Directory: {BACKUP_DIR}")
    logger.info(f"Retention: {RETENTION_DAYS} days")
    logger.info(f"S3 Backup: {'Enabled' if S3_ENABLED else 'Disabled'}")
    
    # Schedule daily backup at 2 AM
    schedule.every().day.at("02:00").do(run_backup_job)
    
    # Run immediately on startup (optional)
    # run_backup_job()
    
    logger.info("Scheduler started. Waiting for scheduled tasks...")
    
    while True:
        schedule.run_pending()
        time.sleep(60)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        logger.info("Backup service stopped")
        sys.exit(0)
