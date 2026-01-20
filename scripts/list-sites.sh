#!/bin/bash

# List All Sites Script

set -e

echo "📋 Listing all Frappe/ERPNext sites"
echo "=================================="

if [ -f "sites/sites.txt" ]; then
    cat sites/sites.txt | while read site; do
        if [ ! -z "$site" ]; then
            echo ""
            echo "Site: $site"
            docker-compose exec frappe bench --site $site list-apps 2>/dev/null || echo "  Status: Offline"
        fi
    done
else
    echo "No sites found."
fi

echo ""
echo "=================================="
echo "Total Sites: $(wc -l < sites/sites.txt 2>/dev/null || echo 0)"
