# C4ERP - Frappe/ERPNext SaaS Server

Multi-tenant SaaS infrastructure for hosting Frappe, ERPNext, and custom apps.

## Features

- 🚀 Multi-tenant architecture with automatic site provisioning
- 🐳 Dockerized deployment for easy scaling
- 🔒 SSL/TLS support with automatic certificate management
- 📊 Monitoring and health checks
- 💾 Automated backup and restore
- 🌐 Reverse proxy with Nginx for routing multiple sites
- 🔑 API for tenant management and billing
- 📦 Support for custom Frappe apps

## Architecture

```
┌─────────────────────────────────────────────────┐
│           Nginx Reverse Proxy (SSL)             │
│      (Routes traffic to tenant sites)           │
└────────────────┬────────────────────────────────┘
                 │
    ┌────────────┴────────────┐
    │                         │
┌───▼────┐  ┌────────┐  ┌────▼────┐
│ Site 1 │  │ Site 2 │  │ Site N  │
│ (ERPNext)│ │(Custom)│ │(Frappe) │
└───┬────┘  └───┬────┘  └────┬────┘
    │           │             │
    └───────────┴─────────────┘
                │
        ┌───────▼────────┐
        │   MariaDB      │
        │ (Multi-tenant) │
        └────────────────┘
```

## Quick Start

### Prerequisites

- Docker & Docker Compose
- Domain name with DNS configured
- Minimum 4GB RAM, 2 CPU cores
- 50GB+ storage

### Installation

1. Clone this repository:
```bash
git clone <repository-url>
cd c4erp
```

2. Configure environment:
```bash
cp .env.example .env
# Edit .env with your settings
```

3. Start the services:
```bash
docker-compose up -d
```

4. Create your first site:
```bash
./scripts/create-site.sh mysite.example.com admin@example.com
```

## Configuration

Edit [.env](.env) file:

```env
# Database
MYSQL_ROOT_PASSWORD=your_secure_password
DB_HOST=db

# Email
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your_email@gmail.com
SMTP_PASSWORD=your_password

# Sites
SITES_DIR=/home/frappe/frappe-bench/sites
```

## Management

### Create a New Site
```bash
./scripts/create-site.sh sitename.com admin@email.com
```

### Backup a Site
```bash
./scripts/backup-site.sh sitename.com
```

### Restore a Site
```bash
./scripts/restore-site.sh sitename.com backup-file.sql.gz
```

### List All Sites
```bash
./scripts/list-sites.sh
```

### Delete a Site
```bash
./scripts/delete-site.sh sitename.com
```

## API Server

The API server provides REST endpoints for automated tenant management:

- `POST /api/sites` - Create new site
- `GET /api/sites` - List all sites
- `GET /api/sites/:name` - Get site details
- `DELETE /api/sites/:name` - Delete site
- `POST /api/sites/:name/backup` - Backup site
- `GET /api/sites/:name/health` - Health check

See [API Documentation](docs/API.md) for details.

## Monitoring

Access monitoring dashboard:
- Grafana: `http://your-server:3000`
- Prometheus: `http://your-server:9090`

## Custom Apps

Add custom Frappe apps in `apps/` directory:

```bash
bench get-app https://github.com/your-org/your-custom-app
bench --site sitename.com install-app your-custom-app
```

## Security

- All sites run in isolated containers
- Database credentials are site-specific
- SSL/TLS certificates via Let's Encrypt
- Regular security updates via automated builds

## Backup Strategy

- Automated daily backups at 2 AM
- Database and files backed up separately
- Retention: 7 daily, 4 weekly, 12 monthly
- Off-site backup support (S3/Backblaze)

## Scaling

For horizontal scaling:
1. Set up load balancer
2. Configure shared storage (NFS/S3)
3. Use external database cluster
4. Enable Redis cluster

## Troubleshooting

### Site not accessible
```bash
docker-compose logs nginx
docker-compose logs frappe-worker
```

### Database connection issues
```bash
docker-compose exec db mysql -u root -p
```

### Reset a site
```bash
bench --site sitename.com reinstall
```

## License

MIT

## Support

For issues and questions, please use the issue tracker or contact support@example.com.