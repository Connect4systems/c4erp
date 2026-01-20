# Deployment Guide

## Production Deployment

### Prerequisites

- Server with Ubuntu 20.04+ or Debian 11+
- Minimum 4GB RAM, 2 CPU cores, 50GB storage
- Domain name with DNS configured
- Root/sudo access

### Step 1: Initial Server Setup

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Logout and login again for group changes
```

### Step 2: Clone Repository

```bash
git clone <your-repository>
cd c4erp
```

### Step 3: Configure Environment

```bash
# Copy environment template
cp .env.example .env

# Edit configuration
nano .env
```

Required changes:
```env
MYSQL_ROOT_PASSWORD=YourSecurePasswordHere
API_SECRET_KEY=RandomSecretKey123
JWT_SECRET=AnotherRandomSecret456
LETSENCRYPT_EMAIL=your@email.com
```

### Step 4: DNS Configuration

Point your domain to your server's IP address:

```
A    @              -> YOUR_SERVER_IP
A    *.yourdomain.com -> YOUR_SERVER_IP
```

### Step 5: Start Services

```bash
# Create necessary directories
mkdir -p certs logs/nginx backups sites

# Start the stack
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f
```

### Step 6: SSL/TLS Setup (Let's Encrypt)

```bash
# Install certbot
sudo apt install certbot python3-certbot-nginx -y

# Get certificate for your domain
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com

# Auto-renewal is configured automatically
```

### Step 7: Create First Site

```bash
# Make scripts executable
chmod +x scripts/*.sh

# Create site
./scripts/create-site.sh mysite.yourdomain.com admin@yourdomain.com
```

### Step 8: Configure Firewall

```bash
# UFW firewall
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

## Performance Optimization

### Database Tuning

Edit `config/mariadb/my.cnf`:

```ini
innodb_buffer_pool_size = 4G  # 70% of available RAM
max_connections = 1000
innodb_log_file_size = 1G
```

### Nginx Optimization

Add to `config/nginx/nginx.conf`:

```nginx
worker_processes auto;
worker_rlimit_nofile 65535;

events {
    worker_connections 4096;
    use epoll;
    multi_accept on;
}
```

### Redis Configuration

For high traffic sites:

```yaml
# In docker-compose.yml
redis-cache:
  command: redis-server --maxmemory 2gb --maxmemory-policy allkeys-lru
```

## Scaling

### Horizontal Scaling

1. **Load Balancer Setup:**

```nginx
upstream frappe-cluster {
    least_conn;
    server frappe-1:8000;
    server frappe-2:8000;
    server frappe-3:8000;
}
```

2. **Shared Storage:**

Use NFS or S3 for shared files:

```yaml
volumes:
  sites:
    driver: local
    driver_opts:
      type: nfs
      o: addr=nfs-server.local,rw
      device: ":/export/sites"
```

3. **Database Clustering:**

Use MariaDB Galera Cluster or external managed database.

### Vertical Scaling

Increase resources in `docker-compose.yml`:

```yaml
frappe:
  deploy:
    resources:
      limits:
        memory: 4g
        cpus: '2'
      reservations:
        memory: 2g
        cpus: '1'
```

## Monitoring

### Enable Monitoring Stack

```bash
docker-compose --profile monitoring up -d
```

Access:
- Grafana: `http://your-server:3000`
- Prometheus: `http://your-server:9090`

### Log Management

Centralized logging with ELK stack:

```yaml
# Add to docker-compose.yml
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
```

## Backup Strategy

### Automated Backups

```bash
# Add to crontab
crontab -e

# Daily backup at 2 AM
0 2 * * * cd /path/to/c4erp && ./scripts/automated-backup.sh
```

### Off-site Backup

Configure S3 in `.env`:

```env
S3_BACKUP_ENABLED=true
S3_BUCKET=your-backup-bucket
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
```

## Security Hardening

### 1. Secure Database

```sql
-- Remove default users
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
FLUSH PRIVILEGES;
```

### 2. Nginx Security Headers

Already configured in `config/nginx/conf.d/default.conf`:
- HSTS
- X-Frame-Options
- X-Content-Type-Options
- CSP headers

### 3. Rate Limiting

Configured in Nginx for:
- General requests: 10 req/s
- Login attempts: 5 req/min

### 4. Docker Security

```bash
# Run Docker in rootless mode (recommended)
dockerd-rootless-setuptool.sh install

# Scan images for vulnerabilities
docker scan frappe/erpnext:v15
```

## Troubleshooting

### Site Not Accessible

```bash
# Check Nginx logs
docker-compose logs nginx

# Check site status
./scripts/health-check.sh

# Restart services
docker-compose restart nginx frappe
```

### Database Connection Issues

```bash
# Check database
docker-compose exec db mysql -u root -p
SHOW DATABASES;

# Check connections
SHOW PROCESSLIST;
```

### High Memory Usage

```bash
# Check resource usage
docker stats

# Restart workers
docker-compose restart frappe-worker
```

### Backup Restoration

```bash
# Restore from backup
./scripts/restore-site.sh sitename.com /path/to/backup.tar.gz
```

## Maintenance

### Update Frappe/ERPNext

```bash
# Pull latest images
docker-compose pull

# Restart services
docker-compose down
docker-compose up -d

# Run migrations
docker-compose exec frappe bench --site all migrate
```

### Clean Docker Resources

```bash
# Remove unused images
docker image prune -a

# Remove unused volumes
docker volume prune

# Full cleanup
docker system prune -a --volumes
```

## Support

For issues and support:
- Documentation: [Frappe Docs](https://frappeframework.com/docs)
- Community: [Frappe Forum](https://discuss.frappe.io)
- GitHub Issues: [Project Issues](https://github.com/your-repo/issues)
