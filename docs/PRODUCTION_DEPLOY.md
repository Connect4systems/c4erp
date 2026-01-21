# Production Deployment to Cloud Server

## When to Deploy to Production Server

Deploy to a production server when you:
- ✅ Have tested locally and everything works
- ✅ Need to serve real users/customers
- ✅ Want your sites accessible from the internet
- ✅ Need high availability and performance

## Server Requirements

### Minimum Specs
- **OS:** Ubuntu 20.04/22.04 or Debian 11
- **RAM:** 8GB (16GB+ recommended)
- **CPU:** 4 cores (8+ recommended)
- **Storage:** 100GB SSD
- **Bandwidth:** Unmetered or high allowance

### Recommended Providers
- **DigitalOcean:** $48/month (4GB RAM, 2 CPUs)
- **Linode:** $48/month (4GB RAM, 2 CPUs)
- **Vultr:** $48/month (4GB RAM, 2 CPUs)
- **AWS EC2:** t3.medium or larger
- **Azure:** B2s or larger
- **Hetzner:** CX31 or larger (cost-effective)

## Pre-Deployment Checklist

- [ ] Server provisioned and accessible
- [ ] Domain name purchased and ready
- [ ] SSH access to server
- [ ] GitHub repository ready
- [ ] Email SMTP credentials ready
- [ ] Backup strategy planned

---

## Step-by-Step Production Deployment

### Step 1: Prepare Your Server

```bash
# SSH into your server
ssh root@your-server-ip

# Update system
apt update && apt upgrade -y

# Install required packages
apt install -y curl git ufw

# Set hostname (optional)
hostnamectl set-hostname your-domain.com
```

### Step 2: Install Docker & Docker Compose

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Verify installation
docker --version
docker-compose --version
```

### Step 3: Configure Firewall

```bash
# Configure UFW firewall
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable

# Verify
ufw status
```

### Step 4: Clone Your Repository

```bash
# Create directory
mkdir -p /opt/apps
cd /opt/apps

# Clone from GitHub
git clone https://github.com/YOUR_USERNAME/c4erp.git
cd c4erp

# Set proper permissions
chmod +x scripts/*.sh
```

### Step 5: Configure Environment

```bash
# Copy environment template
cp .env.example .env

# Generate secure passwords
MYSQL_PASS=$(openssl rand -base64 32)
API_KEY=$(openssl rand -base64 32)
JWT_SECRET=$(openssl rand -base64 32)

# Edit .env file
nano .env
```

**Update these values:**
```env
# Database
MYSQL_ROOT_PASSWORD=<paste-generated-password>

# API Security
API_SECRET_KEY=<paste-generated-api-key>
JWT_SECRET=<paste-generated-jwt-secret>

# Email Configuration
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASSWORD=your-app-password
DEFAULT_EMAIL_SENDER=noreply@yourdomain.com

# SSL/TLS
LETSENCRYPT_EMAIL=admin@yourdomain.com
ENABLE_SSL=true

# Frappe/ERPNext Version
ERPNEXT_VERSION=v15.0.0
```

Save with `Ctrl+X`, `Y`, `Enter`

### Step 6: Configure DNS

Before starting, configure your domain DNS:

**Add these DNS records:**
```
Type    Name                Value               TTL
A       @                   YOUR_SERVER_IP      300
A       *.yourdomain.com    YOUR_SERVER_IP      300
A       main                YOUR_SERVER_IP      300
CNAME   www                 yourdomain.com      300
```

Wait 5-10 minutes for DNS propagation.

### Step 7: Start Services

```bash
# Create directories
mkdir -p certs logs/nginx backups sites apps

# Start services
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f
```

Wait for all services to start (2-3 minutes).

### Step 8: Create Main Site

```bash
# Create your main site with your domain
docker-compose exec frappe bench new-site main.yourdomain.com \
  --admin-password "YourSecurePassword123!" \
  --db-name "main_yourdomain_com" \
  --install-app erpnext \
  --set-default

# Configure site
docker-compose exec frappe bench --site main.yourdomain.com set-config enable_scheduler 1
docker-compose exec frappe bench --site main.yourdomain.com set-config mail_server "smtp.gmail.com"
docker-compose exec frappe bench --site main.yourdomain.com set-config mail_port 587
docker-compose exec frappe bench --site main.yourdomain.com set-config use_tls 1

# Build and restart
docker-compose exec frappe bench build
docker-compose restart frappe frappe-worker
```

### Step 9: Configure Nginx for Your Domain

```bash
# Create site-specific Nginx config
cat > config/nginx/conf.d/main.conf << 'EOF'
server {
    listen 80;
    server_name main.yourdomain.com;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name main.yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/main.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/main.yourdomain.com/privkey.pem;

    root /home/frappe/frappe-bench/sites;

    location /assets {
        try_files $uri =404;
    }

    location ~ ^/files/(.*)$ {
        try_files /main.yourdomain.com/public/$1 @frappe;
    }

    location /socket.io {
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header X-Frappe-Site-Name main.yourdomain.com;
        proxy_set_header Origin $scheme://$http_host;
        proxy_set_header Host $host;
        proxy_pass http://frappe-socketio:9000/socket.io;
    }

    location @frappe {
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Frappe-Site-Name main.yourdomain.com;
        proxy_set_header Host $host;
        proxy_pass http://frappe:8000;
    }

    location / {
        try_files /main.yourdomain.com/public/$uri @frappe;
    }
}
EOF

# Reload Nginx
docker-compose exec nginx nginx -s reload
```

### Step 10: Set Up SSL with Let's Encrypt

```bash
# Install certbot
apt install -y certbot

# Get SSL certificate
certbot certonly --standalone \
  --preferred-challenges http \
  -d main.yourdomain.com \
  --email admin@yourdomain.com \
  --agree-tos \
  --no-eff-email

# Copy certificates to Docker volume
mkdir -p certs/main.yourdomain.com
cp /etc/letsencrypt/live/main.yourdomain.com/* certs/main.yourdomain.com/

# Set up auto-renewal
echo "0 3 * * * certbot renew --quiet && docker-compose exec nginx nginx -s reload" | crontab -

# Reload Nginx
docker-compose exec nginx nginx -s reload
```

### Step 11: Set Up Automated Backups

```bash
# Create backup cron job
cat > /etc/cron.d/c4erp-backup << 'EOF'
# Daily backup at 2 AM
0 2 * * * root cd /opt/apps/c4erp && ./scripts/automated-backup.sh >> /var/log/c4erp-backup.log 2>&1
EOF

# Test backup manually
./scripts/backup-site.sh main.yourdomain.com
```

### Step 12: Configure Monitoring (Optional)

```bash
# Start monitoring stack
docker-compose --profile monitoring up -d

# Configure firewall for monitoring access (if needed)
ufw allow from YOUR_IP to any port 3000  # Grafana
ufw allow from YOUR_IP to any port 9090  # Prometheus
```

### Step 13: Verify Production Setup

```bash
# Check all services
docker-compose ps

# Test site access
curl -I https://main.yourdomain.com

# Check SSL
curl -vI https://main.yourdomain.com 2>&1 | grep -i ssl

# Run health check
./scripts/health-check.sh

# Check logs
docker-compose logs --tail=50 frappe
```

### Step 14: Access Your Production Site

Open browser:
- **Main Site:** https://main.yourdomain.com
- **API:** http://your-server-ip:8000/docs

**Login:**
- Username: `Administrator`
- Password: (the one you set in Step 8)

---

## Post-Deployment Tasks

### 1. Configure ERPNext

- [ ] Set up company information
- [ ] Configure email accounts
- [ ] Set up users and permissions
- [ ] Configure domain settings
- [ ] Set up payment gateways (if needed)

### 2. Create Tenant Sites (SaaS)

```bash
# Create additional tenant sites
./scripts/create-site.sh tenant1.com admin@tenant1.com

# Or use API for automation
curl -X POST http://your-server-ip:8000/api/sites \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "site_name": "tenant1.com",
    "admin_email": "admin@tenant1.com",
    "apps": ["erpnext"]
  }'
```

### 3. Set Up Monitoring Alerts

Configure alerts in Grafana:
- CPU usage > 80%
- Memory usage > 90%
- Disk usage > 85%
- Site response time > 5s

### 4. Regular Maintenance

```bash
# Create maintenance script
cat > /opt/apps/c4erp/scripts/maintenance.sh << 'EOF'
#!/bin/bash
cd /opt/apps/c4erp

# Update Docker images
docker-compose pull

# Restart services with new images
docker-compose down
docker-compose up -d

# Run migrations
docker-compose exec frappe bench --site all migrate

# Clean old Docker images
docker image prune -af

# Clean logs older than 30 days
find logs/ -name "*.log" -mtime +30 -delete
EOF

chmod +x /opt/apps/c4erp/scripts/maintenance.sh

# Schedule monthly maintenance
echo "0 4 1 * * root /opt/apps/c4erp/scripts/maintenance.sh" >> /etc/crontab
```

---

## Security Best Practices

1. **Keep system updated:**
   ```bash
   apt update && apt upgrade -y
   ```

2. **Use strong passwords** for all services

3. **Enable fail2ban:**
   ```bash
   apt install fail2ban -y
   systemctl enable fail2ban
   ```

4. **Regular backups** - verify they work!

5. **Monitor logs:**
   ```bash
   tail -f logs/nginx/access.log
   tail -f logs/nginx/error.log
   ```

6. **Limit SSH access:**
   ```bash
   # Use SSH keys only, disable password auth
   nano /etc/ssh/sshd_config
   # Set: PasswordAuthentication no
   systemctl restart sshd
   ```

---

## Scaling for Growth

### Horizontal Scaling (Multiple Servers)

1. **Set up load balancer** (Nginx or cloud LB)
2. **Use external database** (managed MariaDB)
3. **Use shared storage** (NFS, S3, or cloud storage)
4. **Use Redis cluster** for caching
5. **Deploy multiple app servers**

### Vertical Scaling (Bigger Server)

Upgrade server resources and adjust docker-compose.yml:

```yaml
frappe:
  deploy:
    resources:
      limits:
        memory: 8g
        cpus: '4'
```

---

## Rollback Plan

If something goes wrong:

```bash
# Stop services
docker-compose down

# Restore from backup
./scripts/restore-site.sh main.yourdomain.com /path/to/backup.tar.gz

# Start services
docker-compose up -d
```

---

## Support & Resources

- 📖 Frappe Docs: https://frappeframework.com/docs
- 💬 Forum: https://discuss.frappe.io
- 🐛 Issues: Your GitHub repo
- 📧 Email: your-support-email

## Cost Estimate

**Monthly Costs for Small SaaS (10-50 sites):**
- Server: $50-100/month
- Domain: $10-15/year
- Email (SendGrid/Mailgun): $10-50/month
- Backups (S3): $5-20/month
- SSL: Free (Let's Encrypt)
- **Total: ~$70-180/month**

---

**Need help?** Check logs, run health-check.sh, or review troubleshooting in DEPLOYMENT.md
