# C4ERP - Frappe/ERPNext SaaS Server Setup Script
# Usage: .\setup.ps1

Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║        C4ERP - Frappe/ERPNext SaaS Server Setup           ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Check if Docker is installed
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Docker is not installed!" -ForegroundColor Red
    Write-Host "Please install Docker Desktop: https://www.docker.com/products/docker-desktop" -ForegroundColor Yellow
    exit 1
}

# Check if Docker Compose is available
if (-not (Get-Command docker-compose -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Docker Compose is not installed!" -ForegroundColor Red
    Write-Host "Please install Docker Desktop with Compose: https://www.docker.com/products/docker-desktop" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ Docker and Docker Compose are installed" -ForegroundColor Green
Write-Host ""

# Create .env file if it doesn't exist
if (-not (Test-Path .env)) {
    Write-Host "📝 Creating .env file from template..." -ForegroundColor Yellow
    Copy-Item .env.example .env
    
    # Generate random secrets
    function Get-RandomString {
        param([int]$Length = 32)
        $bytes = New-Object byte[] $Length
        [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($bytes)
        return [Convert]::ToBase64String($bytes)
    }
    
    $mysqlPassword = Get-RandomString
    $apiSecret = Get-RandomString
    $jwtSecret = Get-RandomString
    
    # Update .env with generated secrets
    (Get-Content .env) | ForEach-Object {
        $_ -replace 'MYSQL_ROOT_PASSWORD=.*', "MYSQL_ROOT_PASSWORD=$mysqlPassword" `
           -replace 'API_SECRET_KEY=.*', "API_SECRET_KEY=$apiSecret" `
           -replace 'JWT_SECRET=.*', "JWT_SECRET=$jwtSecret"
    } | Set-Content .env
    
    Write-Host "✅ .env file created with secure random passwords" -ForegroundColor Green
} else {
    Write-Host "ℹ️  .env file already exists, skipping..." -ForegroundColor Gray
}

# Create necessary directories
Write-Host ""
Write-Host "📁 Creating required directories..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path certs, logs\nginx, backups, sites, apps | Out-Null
Write-Host "✅ Directories created" -ForegroundColor Green

# Pull Docker images
Write-Host ""
Write-Host "📥 Pulling Docker images (this may take a while)..." -ForegroundColor Yellow
docker-compose pull
Write-Host "✅ Docker images pulled" -ForegroundColor Green

# Start services
Write-Host ""
Write-Host "🚀 Starting services..." -ForegroundColor Yellow
docker-compose up -d
Write-Host "✅ Services started" -ForegroundColor Green

# Wait for services to be ready
Write-Host ""
Write-Host "⏳ Waiting for services to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Check service status
Write-Host ""
Write-Host "📊 Service Status:" -ForegroundColor Cyan
docker-compose ps

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                  Setup Complete! 🎉                        ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Create your first site:" -ForegroundColor White
Write-Host "   docker-compose exec frappe bench new-site mysite.localhost --admin-password admin --install-app erpnext" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Access API documentation:" -ForegroundColor White
Write-Host "   http://localhost:8000/docs" -ForegroundColor Gray
Write-Host ""
Write-Host "3. View logs:" -ForegroundColor White
Write-Host "   docker-compose logs -f" -ForegroundColor Gray
Write-Host ""
Write-Host "4. Access your site:" -ForegroundColor White
Write-Host "   http://mysite.localhost:8080" -ForegroundColor Gray
Write-Host ""
Write-Host "📖 For more information, see docs\QUICKSTART.md" -ForegroundColor Cyan
Write-Host ""
