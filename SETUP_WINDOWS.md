# C4ERP Setup Guide for Windows

## Prerequisites Check

Before starting, ensure you have:
- [ ] Docker Desktop installed and running
- [ ] At least 8GB RAM available
- [ ] 20GB free disk space
- [ ] Internet connection

## Step 1: Verify Docker

Open PowerShell and run:
```powershell
# Check Docker is running
docker --version
docker-compose --version

# Start Docker Desktop if not running
# Open Docker Desktop from Start Menu
```

## Step 2: Navigate to Project

```powershell
# Go to your project directory
cd D:\2026\Apps\c4erp
```

## Step 3: Configure Environment

```powershell
# Copy the example environment file (if not already done)
if (!(Test-Path .env)) {
    Copy-Item .env.example .env
    Write-Host "✅ .env file created" -ForegroundColor Green
}

# Open .env file to edit
notepad .env
```

**Edit these values in .env:**
```env
MYSQL_ROOT_PASSWORD=MySecurePassword123!
API_SECRET_KEY=RandomSecretKey$(Get-Random)
JWT_SECRET=JWTSecret$(Get-Random)
ERPNEXT_VERSION=v15.0.0
```

Save and close the file.

## Step 4: Run Setup Script

```powershell
# Run the automated setup
.\setup.ps1
```

**This will:**
- ✅ Check prerequisites
- ✅ Create directories
- ✅ Pull Docker images (~5-10 minutes)
- ✅ Start all services

## Step 5: Wait for Services to Start

```powershell
# Check service status
docker-compose ps

# Watch logs (press Ctrl+C to exit)
docker-compose logs -f
```

**Wait until you see:**
- "Frappe server started"
- "MariaDB ready for connections"
- All services showing as "healthy"

## Step 6: Create Your Main Site

### Method A: Using Docker Command
```powershell
# Create main site (recommended for first site)
docker-compose exec frappe bench new-site main.localhost `
  --admin-password "admin123" `
  --db-name "main_site" `
  --install-app erpnext `
  --set-default

# This takes 5-10 minutes
```

### Method B: Using API (after main site exists)
```powershell
# First, get API token
$apiKey = "RandomSecretKey$(Get-Random)"  # Use the one from .env
$body = @{ api_key = $apiKey } | ConvertTo-Json

$response = Invoke-RestMethod -Uri "http://localhost:8000/api/auth/token" `
  -Method Post -ContentType "application/json" -Body $body

$token = $response.access_token

# Create site via API
$siteData = @{
    site_name = "tenant1.localhost"
    admin_email = "admin@tenant1.com"
    apps = @("erpnext")
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:8000/api/sites" `
  -Method Post `
  -Headers @{ "Authorization" = "Bearer $token" } `
  -ContentType "application/json" -Body $siteData
```

## Step 7: Configure Site

```powershell
# Set as default site
docker-compose exec frappe bench use main.localhost

# Enable scheduler
docker-compose exec frappe bench --site main.localhost set-config enable_scheduler 1

# Build assets
docker-compose exec frappe bench build

# Clear cache
docker-compose exec frappe bench --site main.localhost clear-cache

# Restart services
docker-compose restart frappe frappe-worker
```

## Step 8: Access Your Site

Open your browser:
- **Main Site:** http://localhost:8080
- **API Documentation:** http://localhost:8000/docs
- **Grafana (optional):** http://localhost:3000

**Login Credentials:**
- Username: `Administrator`
- Password: `admin123` (or what you set)

## Step 9: Verify Everything Works

```powershell
# Check all services
docker-compose ps

# List installed apps
docker-compose exec frappe bench --site main.localhost list-apps

# Check site status
docker-compose exec frappe bench --site main.localhost doctor
```

## Create Additional Tenant Sites

```powershell
# Create second site
docker-compose exec frappe bench new-site tenant2.localhost `
  --admin-password "tenant2pass" `
  --install-app erpnext

# Access at: http://tenant2.localhost:8080
```

## Common Commands

### View Logs
```powershell
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f frappe
docker-compose logs -f db
```

### Restart Services
```powershell
# Restart all
docker-compose restart

# Restart specific service
docker-compose restart frappe
```

### Stop Everything
```powershell
# Stop services (keeps data)
docker-compose stop

# Stop and remove (keeps data)
docker-compose down

# Stop and remove everything including data (CAREFUL!)
docker-compose down -v
```

### Backup Site
```powershell
# Create backup
docker-compose exec frappe bench --site main.localhost backup --with-files

# List backups
docker-compose exec frappe ls /home/frappe/frappe-bench/sites/main.localhost/private/backups
```

## Troubleshooting

### Services won't start
```powershell
# Check Docker Desktop is running
docker ps

# Restart Docker Desktop, then:
docker-compose down
docker-compose up -d
```

### Port conflicts
If port 80, 443, 3306, or 8000 are in use:

Edit docker-compose.yml:
```yaml
nginx:
  ports:
    - "8080:80"  # Change to 8080
    - "8443:443" # Change to 8443
```

### Database connection issues
```powershell
# Check database
docker-compose exec db mysql -u root -p
# Enter password from .env

# Test connection
docker-compose exec db mysqladmin ping -u root -p
```

### Site not accessible
```powershell
# Check site exists
docker-compose exec frappe bench --site main.localhost list-apps

# Rebuild assets
docker-compose exec frappe bench build

# Clear cache
docker-compose exec frappe bench clear-cache

# Restart
docker-compose restart nginx frappe
```

## Next Steps

1. ✅ **Customize your main site** - Configure company, users, etc.
2. ✅ **Test creating tenant sites** - Create multiple sites for testing
3. ✅ **Try the API** - Test tenant provisioning via API
4. ✅ **Install custom apps** - Add your own Frappe apps
5. ✅ **Plan production deployment** - Follow DEPLOYMENT.md

## Development Tips

### Enable Developer Mode
```powershell
docker-compose exec frappe bench --site main.localhost set-config developer_mode 1
docker-compose restart frappe
```

### Access Frappe Console
```powershell
docker-compose exec frappe bench --site main.localhost console
```

### Install Custom App from GitHub
```powershell
# Clone your custom app
docker-compose exec frappe bench get-app https://github.com/your-org/your-app

# Install on site
docker-compose exec frappe bench --site main.localhost install-app your-app

# Build
docker-compose exec frappe bench build
```

## Support

- 📖 Full docs: docs/QUICKSTART.md
- 🚀 Production: docs/DEPLOYMENT.md
- 🔌 API: docs/API.md
- 💬 Issues: GitHub Issues
