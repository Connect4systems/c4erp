# Quick Start Guide

## What is C4ERP?

C4ERP is a complete multi-tenant SaaS infrastructure for hosting Frappe, ERPNext, and custom apps. It provides:

- Automated site provisioning
- Multi-tenant architecture
- Built-in backups and monitoring
- REST API for management
- SSL/TLS support
- Scalable Docker-based deployment

## Installation

### 1. Prerequisites

Ensure you have installed:
- Docker (20.10+)
- Docker Compose (1.29+)
- Git

**Windows:**
```powershell
# Install Docker Desktop from https://www.docker.com/products/docker-desktop
# Install Git from https://git-scm.com/download/win
```

**Linux:**
```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo apt install docker-compose git -y
```

### 2. Clone & Setup

```bash
# Clone repository
git clone <your-repository-url>
cd c4erp

# Copy environment file
cp .env.example .env

# Edit configuration (important!)
nano .env  # or use any text editor
```

**Required changes in `.env`:**
```env
MYSQL_ROOT_PASSWORD=ChangeToSecurePassword
API_SECRET_KEY=YourRandomSecretKey123
JWT_SECRET=AnotherRandomSecret456
SMTP_USER=your.email@gmail.com
SMTP_PASSWORD=your-app-password
```

### 3. Start Services

```bash
# Start all services
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f
```

Wait 2-3 minutes for all services to start.

### 4. Create Your First Site

**Linux/Mac:**
```bash
chmod +x scripts/*.sh
./scripts/create-site.sh mysite.localhost admin@example.com
```

**Windows (PowerShell):**
```powershell
docker-compose exec frappe bench new-site mysite.localhost `
  --admin-password admin `
  --install-app erpnext
```

**Save the credentials shown!**

### 5. Access Your Site

Open browser: `http://mysite.localhost:8080`

Login with:
- Email: admin@example.com
- Password: (shown in terminal)

## Common Tasks

### Create Another Site

```bash
./scripts/create-site.sh site2.localhost admin@site2.com
```

### List All Sites

```bash
./scripts/list-sites.sh
```

### Backup a Site

```bash
./scripts/backup-site.sh mysite.localhost
```

### Install Custom App

```bash
./scripts/install-app.sh mysite.localhost https://github.com/user/custom-app
```

### Delete a Site

```bash
./scripts/delete-site.sh mysite.localhost
```

## Using the API

### Get Access Token

```bash
curl -X POST http://localhost:8000/api/auth/token \
  -H "Content-Type: application/json" \
  -d '{"api_key": "YourRandomSecretKey123"}'
```

### Create Site via API

```bash
curl -X POST http://localhost:8000/api/sites \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "site_name": "api-site.localhost",
    "admin_email": "admin@api-site.com",
    "apps": ["erpnext"]
  }'
```

### List Sites via API

```bash
curl http://localhost:8000/api/sites \
  -H "Authorization: Bearer YOUR_TOKEN"
```

## Monitoring

### Health Check

```bash
./scripts/health-check.sh
```

### Access Monitoring (Optional)

```bash
# Start monitoring stack
docker-compose --profile monitoring up -d
```

- Grafana: `http://localhost:3000`
- Prometheus: `http://localhost:9090`

## Troubleshooting

### Services not starting?

```bash
# Check logs
docker-compose logs

# Restart services
docker-compose restart
```

### Site not accessible?

```bash
# Check Nginx logs
docker-compose logs nginx

# Reload Nginx
docker-compose exec nginx nginx -s reload
```

### Database issues?

```bash
# Access database
docker-compose exec db mysql -u root -p

# Enter password from .env file
```

### Reset everything

```bash
# Stop and remove all containers
docker-compose down -v

# Start fresh
docker-compose up -d
```

## Next Steps

1. **Production Setup**: See [DEPLOYMENT.md](DEPLOYMENT.md) for production deployment guide
2. **API Integration**: Check [API.md](API.md) for complete API documentation
3. **Custom Apps**: Learn to install custom Frappe apps
4. **Scaling**: Configure horizontal scaling for high traffic

## Architecture Overview

```
┌─────────────────────┐
│   Nginx (Port 80)   │ ← Entry point
└──────────┬──────────┘
           │
    ┌──────┴──────┐
    │             │
┌───▼───┐    ┌───▼───┐
│ Site1 │    │ Site2 │ ← Frappe Sites
└───┬───┘    └───┬───┘
    │            │
    └──────┬─────┘
           │
     ┌─────▼─────┐
     │  MariaDB  │ ← Shared Database
     └───────────┘
```

## Configuration Files

- [.env](.env) - Environment variables
- [docker-compose.yml](docker-compose.yml) - Service definitions
- `config/nginx/` - Nginx configuration
- `config/mariadb/` - Database configuration
- `scripts/` - Management scripts

## Support

- Documentation: [Frappe Framework](https://frappeframework.com/docs)
- Community: [Frappe Forum](https://discuss.frappe.io)
- Issues: GitHub Issues

## Tips

💡 **Development Mode**: Add to site config for development:
```bash
docker-compose exec frappe bench --site mysite.localhost set-config developer_mode 1
```

💡 **Enable Debugging**:
```bash
docker-compose exec frappe bench --site mysite.localhost console
```

💡 **Build Assets** after code changes:
```bash
docker-compose exec frappe bench build
```

💡 **Clear Cache**:
```bash
docker-compose exec frappe bench --site mysite.localhost clear-cache
```

---

**Ready to deploy in production?** Check out [DEPLOYMENT.md](DEPLOYMENT.md)!
