"""
Tenant Management API for Frappe/ERPNext SaaS
Provides REST endpoints for site provisioning, management, and monitoring
"""

from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, EmailStr
from typing import List, Optional
from datetime import datetime, timedelta
import subprocess
import os
import logging
import mysql.connector
from jose import JWTError, jwt
from passlib.context import CryptContext
import docker

# Configuration
API_SECRET_KEY = os.getenv("API_SECRET_KEY", "your-secret-key-change-me")
JWT_SECRET = os.getenv("JWT_SECRET", "your-jwt-secret-change-me")
JWT_ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

DB_HOST = os.getenv("DB_HOST", "db")
DB_USER = "root"
DB_PASSWORD = os.getenv("MYSQL_ROOT_PASSWORD")

# Logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Security
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
security = HTTPBearer()

# FastAPI app
app = FastAPI(
    title="Frappe SaaS API",
    description="Multi-tenant management API for Frappe/ERPNext",
    version="1.0.0"
)

# Docker client
docker_client = docker.from_env()


# Models
class SiteCreate(BaseModel):
    site_name: str
    admin_email: EmailStr
    admin_password: Optional[str] = None
    apps: List[str] = ["erpnext"]


class SiteResponse(BaseModel):
    site_name: str
    admin_email: str
    created_at: str
    status: str
    apps: List[str]


class SiteHealth(BaseModel):
    site_name: str
    status: str
    http_status: int
    database_status: str
    last_checked: str


class BackupRequest(BaseModel):
    site_name: str
    include_files: bool = True


class Token(BaseModel):
    access_token: str
    token_type: str


# Helper Functions
def get_db_connection():
    """Get MySQL connection"""
    return mysql.connector.connect(
        host=DB_HOST,
        user=DB_USER,
        password=DB_PASSWORD
    )


def create_access_token(data: dict):
    """Create JWT access token"""
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, JWT_SECRET, algorithm=JWT_ALGORITHM)
    return encoded_jwt


def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """Verify JWT token"""
    try:
        payload = jwt.decode(credentials.credentials, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        return payload
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )


def run_bench_command(command: List[str]) -> tuple:
    """Execute bench command in Frappe container"""
    try:
        container = docker_client.containers.get("frappe")
        result = container.exec_run(
            cmd=["bash", "-c", " ".join(command)],
            workdir="/home/frappe/frappe-bench"
        )
        return result.exit_code, result.output.decode()
    except Exception as e:
        logger.error(f"Bench command failed: {e}")
        return 1, str(e)


# API Endpoints

@app.get("/")
async def root():
    """API root endpoint"""
    return {
        "message": "Frappe/ERPNext SaaS API",
        "version": "1.0.0",
        "docs": "/docs"
    }


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat()
    }


@app.post("/api/auth/token", response_model=Token)
async def login(api_key: str):
    """Authenticate and get access token"""
    if api_key != API_SECRET_KEY:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid API key"
        )
    
    access_token = create_access_token(data={"sub": "api_user"})
    return {"access_token": access_token, "token_type": "bearer"}


@app.post("/api/sites", response_model=SiteResponse, status_code=status.HTTP_201_CREATED)
async def create_site(site: SiteCreate, token: dict = Depends(verify_token)):
    """Create a new Frappe site"""
    logger.info(f"Creating new site: {site.site_name}")
    
    # Generate password if not provided
    admin_password = site.admin_password or os.urandom(16).hex()
    
    # Create site using bench
    command = [
        "bench", "new-site", site.site_name,
        "--admin-password", admin_password,
        f"--db-name={site.site_name.replace('.', '_')}",
        f"--mariadb-root-password={DB_PASSWORD}",
        "--no-mariadb-socket"
    ]
    
    exit_code, output = run_bench_command(command)
    
    if exit_code != 0:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Site creation failed: {output}"
        )
    
    # Install apps
    for app in site.apps:
        install_cmd = ["bench", "--site", site.site_name, "install-app", app]
        run_bench_command(install_cmd)
    
    # Add to sites.txt
    with open("/home/frappe/frappe-bench/sites/sites.txt", "a") as f:
        f.write(f"{site.site_name}\n")
    
    logger.info(f"Site created successfully: {site.site_name}")
    
    return SiteResponse(
        site_name=site.site_name,
        admin_email=site.admin_email,
        created_at=datetime.utcnow().isoformat(),
        status="active",
        apps=site.apps
    )


@app.get("/api/sites", response_model=List[str])
async def list_sites(token: dict = Depends(verify_token)):
    """List all sites"""
    try:
        with open("/home/frappe/frappe-bench/sites/sites.txt", "r") as f:
            sites = [line.strip() for line in f if line.strip()]
        return sites
    except FileNotFoundError:
        return []


@app.get("/api/sites/{site_name}")
async def get_site(site_name: str, token: dict = Depends(verify_token)):
    """Get site details"""
    command = ["bench", "--site", site_name, "list-apps"]
    exit_code, output = run_bench_command(command)
    
    if exit_code != 0:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Site not found: {site_name}"
        )
    
    apps = [app.strip() for app in output.split('\n') if app.strip()]
    
    return {
        "site_name": site_name,
        "apps": apps,
        "status": "active"
    }


@app.delete("/api/sites/{site_name}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_site(site_name: str, token: dict = Depends(verify_token)):
    """Delete a site"""
    logger.info(f"Deleting site: {site_name}")
    
    command = [
        "bench", "drop-site", site_name,
        f"--mariadb-root-password={DB_PASSWORD}",
        "--force"
    ]
    
    exit_code, output = run_bench_command(command)
    
    if exit_code != 0:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Site deletion failed: {output}"
        )
    
    # Remove from sites.txt
    try:
        with open("/home/frappe/frappe-bench/sites/sites.txt", "r") as f:
            sites = f.readlines()
        
        with open("/home/frappe/frappe-bench/sites/sites.txt", "w") as f:
            for site in sites:
                if site.strip() != site_name:
                    f.write(site)
    except Exception as e:
        logger.error(f"Error updating sites.txt: {e}")
    
    logger.info(f"Site deleted: {site_name}")
    return None


@app.post("/api/sites/{site_name}/backup")
async def backup_site(site_name: str, backup: BackupRequest, token: dict = Depends(verify_token)):
    """Create a backup of the site"""
    logger.info(f"Backing up site: {site_name}")
    
    command = ["bench", "--site", site_name, "backup"]
    if backup.include_files:
        command.append("--with-files")
    
    exit_code, output = run_bench_command(command)
    
    if exit_code != 0:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Backup failed: {output}"
        )
    
    return {
        "site_name": site_name,
        "backup_created": datetime.utcnow().isoformat(),
        "status": "success"
    }


@app.get("/api/sites/{site_name}/health", response_model=SiteHealth)
async def check_site_health(site_name: str, token: dict = Depends(verify_token)):
    """Check site health"""
    # Check if site exists
    command = ["bench", "--site", site_name, "list-apps"]
    exit_code, _ = run_bench_command(command)
    
    site_status = "healthy" if exit_code == 0 else "unhealthy"
    
    # Check database
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        db_name = site_name.replace('.', '_')
        cursor.execute(f"SHOW DATABASES LIKE '{db_name}'")
        db_exists = cursor.fetchone() is not None
        cursor.close()
        conn.close()
        db_status = "online" if db_exists else "offline"
    except Exception as e:
        db_status = f"error: {str(e)}"
    
    return SiteHealth(
        site_name=site_name,
        status=site_status,
        http_status=200 if site_status == "healthy" else 503,
        database_status=db_status,
        last_checked=datetime.utcnow().isoformat()
    )


@app.post("/api/sites/{site_name}/migrate")
async def migrate_site(site_name: str, token: dict = Depends(verify_token)):
    """Run migrations for a site"""
    logger.info(f"Running migrations for: {site_name}")
    
    command = ["bench", "--site", site_name, "migrate"]
    exit_code, output = run_bench_command(command)
    
    if exit_code != 0:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Migration failed: {output}"
        )
    
    return {
        "site_name": site_name,
        "migration_completed": datetime.utcnow().isoformat(),
        "status": "success"
    }


@app.get("/api/stats")
async def get_stats(token: dict = Depends(verify_token)):
    """Get platform statistics"""
    # Count sites
    try:
        with open("/home/frappe/frappe-bench/sites/sites.txt", "r") as f:
            total_sites = len([line for line in f if line.strip()])
    except:
        total_sites = 0
    
    # Get container stats
    try:
        containers = docker_client.containers.list()
        running_containers = len(containers)
    except:
        running_containers = 0
    
    # Database count
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SHOW DATABASES")
        databases = [db[0] for db in cursor.fetchall()]
        frappe_dbs = [db for db in databases if not db.startswith('_') and db not in ['mysql', 'information_schema', 'performance_schema']]
        cursor.close()
        conn.close()
        db_count = len(frappe_dbs)
    except:
        db_count = 0
    
    return {
        "total_sites": total_sites,
        "running_containers": running_containers,
        "databases": db_count,
        "timestamp": datetime.utcnow().isoformat()
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
