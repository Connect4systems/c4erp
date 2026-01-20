#!/bin/bash

# Health Check Script for all sites
# Usage: ./health-check.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🏥 Health Check Report"
echo "======================"
echo "Time: $(date)"
echo ""

# Check Docker services
echo "📊 Docker Services Status:"
docker-compose ps

echo ""
echo "🌐 Sites Health Check:"
echo "----------------------"

if [ -f "sites/sites.txt" ]; then
    while IFS= read -r site; do
        if [ ! -z "$site" ]; then
            echo -n "Site: $site ... "
            
            # HTTP Check
            STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://$site" 2>/dev/null || echo "000")
            
            if [ "$STATUS" = "200" ] || [ "$STATUS" = "301" ] || [ "$STATUS" = "302" ]; then
                echo -e "${GREEN}✓ UP${NC} (HTTP $STATUS)"
            else
                echo -e "${RED}✗ DOWN${NC} (HTTP $STATUS)"
            fi
        fi
    done < sites/sites.txt
else
    echo "No sites configured."
fi

echo ""
echo "💾 Database Status:"
echo "-------------------"
docker-compose exec -T db mysqladmin ping -h localhost --silent && \
    echo -e "${GREEN}✓ Database is running${NC}" || \
    echo -e "${RED}✗ Database is down${NC}"

echo ""
echo "🔄 Redis Status:"
echo "----------------"
docker-compose exec -T redis-cache redis-cli ping > /dev/null 2>&1 && \
    echo -e "${GREEN}✓ Redis Cache is running${NC}" || \
    echo -e "${RED}✗ Redis Cache is down${NC}"

docker-compose exec -T redis-queue redis-cli ping > /dev/null 2>&1 && \
    echo -e "${GREEN}✓ Redis Queue is running${NC}" || \
    echo -e "${RED}✗ Redis Queue is down${NC}"

echo ""
echo "💻 Resource Usage:"
echo "------------------"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"

echo ""
echo "======================"
echo "Health check completed"
