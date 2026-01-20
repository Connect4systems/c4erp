# API Documentation

## Authentication

All API endpoints (except `/health` and `/`) require JWT authentication.

### Get Access Token

```bash
curl -X POST http://localhost:8000/api/auth/token \
  -H "Content-Type: application/json" \
  -d '{"api_key": "your-api-secret-key"}'
```

Response:
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIs...",
  "token_type": "bearer"
}
```

Use the token in subsequent requests:
```bash
curl -H "Authorization: Bearer <token>" http://localhost:8000/api/sites
```

## Endpoints

### Sites Management

#### Create New Site

```http
POST /api/sites
```

**Headers:**
- `Authorization: Bearer <token>`
- `Content-Type: application/json`

**Body:**
```json
{
  "site_name": "example.com",
  "admin_email": "admin@example.com",
  "admin_password": "SecurePassword123",
  "apps": ["erpnext"]
}
```

**Response (201):**
```json
{
  "site_name": "example.com",
  "admin_email": "admin@example.com",
  "created_at": "2026-01-20T10:30:00",
  "status": "active",
  "apps": ["erpnext"]
}
```

#### List All Sites

```http
GET /api/sites
```

**Response (200):**
```json
[
  "site1.com",
  "site2.com",
  "site3.com"
]
```

#### Get Site Details

```http
GET /api/sites/{site_name}
```

**Response (200):**
```json
{
  "site_name": "example.com",
  "apps": ["frappe", "erpnext"],
  "status": "active"
}
```

#### Delete Site

```http
DELETE /api/sites/{site_name}
```

**Response (204):** No content

### Site Operations

#### Backup Site

```http
POST /api/sites/{site_name}/backup
```

**Body:**
```json
{
  "site_name": "example.com",
  "include_files": true
}
```

**Response (200):**
```json
{
  "site_name": "example.com",
  "backup_created": "2026-01-20T10:30:00",
  "status": "success"
}
```

#### Health Check

```http
GET /api/sites/{site_name}/health
```

**Response (200):**
```json
{
  "site_name": "example.com",
  "status": "healthy",
  "http_status": 200,
  "database_status": "online",
  "last_checked": "2026-01-20T10:30:00"
}
```

#### Run Migrations

```http
POST /api/sites/{site_name}/migrate
```

**Response (200):**
```json
{
  "site_name": "example.com",
  "migration_completed": "2026-01-20T10:30:00",
  "status": "success"
}
```

### Platform Statistics

#### Get Stats

```http
GET /api/stats
```

**Response (200):**
```json
{
  "total_sites": 15,
  "running_containers": 8,
  "databases": 15,
  "timestamp": "2026-01-20T10:30:00"
}
```

## Example Usage

### Python

```python
import requests

# Get token
response = requests.post(
    'http://localhost:8000/api/auth/token',
    json={'api_key': 'your-api-secret-key'}
)
token = response.json()['access_token']

# Create site
headers = {'Authorization': f'Bearer {token}'}
site_data = {
    'site_name': 'newsite.com',
    'admin_email': 'admin@newsite.com',
    'apps': ['erpnext']
}

response = requests.post(
    'http://localhost:8000/api/sites',
    json=site_data,
    headers=headers
)

print(response.json())
```

### cURL

```bash
# Get token
TOKEN=$(curl -X POST http://localhost:8000/api/auth/token \
  -H "Content-Type: application/json" \
  -d '{"api_key": "your-api-secret-key"}' | jq -r '.access_token')

# Create site
curl -X POST http://localhost:8000/api/sites \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "site_name": "newsite.com",
    "admin_email": "admin@newsite.com",
    "apps": ["erpnext"]
  }'

# List sites
curl http://localhost:8000/api/sites \
  -H "Authorization: Bearer $TOKEN"

# Backup site
curl -X POST http://localhost:8000/api/sites/newsite.com/backup \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"site_name": "newsite.com", "include_files": true}'
```

## Error Responses

### 401 Unauthorized
```json
{
  "detail": "Invalid authentication credentials"
}
```

### 404 Not Found
```json
{
  "detail": "Site not found: example.com"
}
```

### 500 Internal Server Error
```json
{
  "detail": "Site creation failed: [error message]"
}
```
