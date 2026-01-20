#!/bin/bash

# Setup Script for C4ERP SaaS Server
# Usage: ./setup.sh

set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║        C4ERP - Frappe/ERPNext SaaS Server Setup           ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed!"
    echo "Please install Docker first: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed!"
    echo "Please install Docker Compose first: https://docs.docker.com/compose/install/"
    exit 1
fi

echo "✅ Docker and Docker Compose are installed"
echo ""

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo "📝 Creating .env file from template..."
    cp .env.example .env
    
    # Generate random secrets
    MYSQL_PASSWORD=$(openssl rand -base64 32)
    API_SECRET=$(openssl rand -base64 32)
    JWT_SECRET=$(openssl rand -base64 32)
    
    # Update .env with generated secrets
    sed -i "s/MYSQL_ROOT_PASSWORD=.*/MYSQL_ROOT_PASSWORD=$MYSQL_PASSWORD/" .env
    sed -i "s/API_SECRET_KEY=.*/API_SECRET_KEY=$API_SECRET/" .env
    sed -i "s/JWT_SECRET=.*/JWT_SECRET=$JWT_SECRET/" .env
    
    echo "✅ .env file created with secure random passwords"
else
    echo "ℹ️  .env file already exists, skipping..."
fi

# Create necessary directories
echo ""
echo "📁 Creating required directories..."
mkdir -p certs logs/nginx backups sites apps
echo "✅ Directories created"

# Make scripts executable
echo ""
echo "🔧 Making scripts executable..."
chmod +x scripts/*.sh
echo "✅ Scripts are now executable"

# Pull Docker images
echo ""
echo "📥 Pulling Docker images (this may take a while)..."
docker-compose pull
echo "✅ Docker images pulled"

# Start services
echo ""
echo "🚀 Starting services..."
docker-compose up -d
echo "✅ Services started"

# Wait for services to be ready
echo ""
echo "⏳ Waiting for services to be ready..."
sleep 10

# Check service status
echo ""
echo "📊 Service Status:"
docker-compose ps

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                  Setup Complete! 🎉                        ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Next steps:"
echo ""
echo "1. Create your first site:"
echo "   ./scripts/create-site.sh mysite.localhost admin@example.com"
echo ""
echo "2. Access API documentation:"
echo "   http://localhost:8000/docs"
echo ""
echo "3. View logs:"
echo "   docker-compose logs -f"
echo ""
echo "4. Run health check:"
echo "   ./scripts/health-check.sh"
echo ""
echo "📖 For more information, see docs/QUICKSTART.md"
echo ""
