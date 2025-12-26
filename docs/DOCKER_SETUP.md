# Docker Setup Guide for Rota

## Overview

Rota consists of three main components that can be containerized:
1. **Core** (Go) - Proxy server and API
2. **Dashboard** (Next.js) - Web UI
3. **TimescaleDB** - Database

## Quick Start

### Using Docker Compose (Recommended)

The easiest way to run the entire stack:

```bash
cd rota
docker-compose up -d
```

This starts:
- **Rota Core**: `http://localhost:8000` (proxy), `http://localhost:8001` (API)
- **Rota Dashboard**: `http://localhost:3000`
- **TimescaleDB**: `localhost:5432`

### Default Credentials

- **Dashboard**: `admin` / `admin`
- **Database**: `rota` / `rota_password`

## Dockerfiles

### Core Dockerfile (`core/Dockerfile`)

Multi-stage build for the Go application:

**Build Stage**:
- Uses `golang:1.25.3-alpine`
- Compiles static binary
- Optimized for size

**Runtime Stage**:
- Uses `alpine:latest` (minimal)
- Runs as non-root user
- Includes health checks
- Exposes ports 8000 (proxy) and 8001 (API)

**Build**:
```bash
cd rota/core
docker build -t rota-core:latest .
```

**Run**:
```bash
docker run -d \
  --name rota-core \
  -p 8000:8000 \
  -p 8001:8001 \
  -e DB_HOST=your-db-host \
  -e DB_USER=rota \
  -e DB_PASSWORD=your-password \
  -e DB_NAME=rota \
  rota-core:latest
```

### Dashboard Dockerfile (`dashboard/Dockerfile`)

Multi-stage build for Next.js application:

**Stages**:
1. **Dependencies**: Install pnpm and dependencies
2. **Builder**: Build Next.js application
3. **Runner**: Production runtime

**Build**:
```bash
cd rota/dashboard
docker build -t rota-dashboard:latest .
```

**Run**:
```bash
docker run -d \
  --name rota-dashboard \
  -p 3000:3000 \
  -e NEXT_PUBLIC_API_URL=http://localhost:8001 \
  rota-dashboard:latest
```

## Docker Compose Configuration

### Full Stack (`docker-compose.yml`)

Includes all three services with proper networking and health checks.

**Services**:
- `rota-core`: Core proxy and API server
- `rota-dashboard`: Web dashboard
- `timescaledb`: PostgreSQL with TimescaleDB extension

**Networks**:
- `rota-network`: Bridge network for service communication

**Volumes**:
- `timescaledb-data`: Persistent database storage

### Environment Variables

#### Core Service

```yaml
PROXY_PORT=8000          # Proxy server port
API_PORT=8001           # API server port
LOG_LEVEL=info          # Log level (debug, info, warn, error)
DB_HOST=timescaledb     # Database host
DB_PORT=5432            # Database port
DB_USER=rota            # Database user
DB_PASSWORD=rota_password  # Database password
DB_NAME=rota            # Database name
DB_SSLMODE=disable      # SSL mode
ROTA_ADMIN_USER=admin   # Dashboard admin username
ROTA_ADMIN_PASSWORD=admin  # Dashboard admin password
```

#### Dashboard Service

```yaml
NEXT_PUBLIC_API_URL=http://localhost:8001  # API URL for frontend
```

## Building Images

### Build Core

```bash
cd rota/core
docker build -t rota-core:latest .
```

### Build Dashboard

```bash
cd rota/dashboard
docker build -t rota-dashboard:latest .
```

### Build All with Compose

```bash
docker-compose build
```

## Running Containers

### Start All Services

```bash
docker-compose up -d
```

### Start Specific Service

```bash
docker-compose up -d rota-core
docker-compose up -d rota-dashboard
```

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f rota-core
docker-compose logs -f rota-dashboard
```

### Stop Services

```bash
docker-compose down
```

### Stop and Remove Volumes

```bash
docker-compose down -v
```

## Production Deployment

### Environment-Specific Configuration

Create `.env` file:

```bash
# Database
DB_HOST=your-production-db-host
DB_PORT=5432
DB_USER=rota_prod
DB_PASSWORD=secure_password
DB_NAME=rota_prod
DB_SSLMODE=require

# Security
ROTA_ADMIN_USER=admin
ROTA_ADMIN_PASSWORD=secure_admin_password

# Logging
LOG_LEVEL=info
```

### Production Docker Compose

Create `docker-compose.prod.yml`:

```yaml
version: "3.8"

services:
  rota-core:
    build:
      context: ./core
      dockerfile: Dockerfile
    restart: always
    ports:
      - "8000:8000"
      - "8001:8001"
    env_file:
      - .env
    networks:
      - rota-network
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:8001/health"]
      interval: 30s
      timeout: 3s
      start_period: 10s
      retries: 3

  rota-dashboard:
    build:
      context: ./dashboard
      dockerfile: Dockerfile
    restart: always
    ports:
      - "3000:3000"
    environment:
      - NEXT_PUBLIC_API_URL=${API_URL:-http://localhost:8001}
    networks:
      - rota-network
    depends_on:
      - rota-core

networks:
  rota-network:
    driver: bridge
```

Run:
```bash
docker-compose -f docker-compose.prod.yml up -d
```

## Health Checks

### Core Service

Health check endpoint: `http://localhost:8001/health`

```bash
# Check health
curl http://localhost:8001/health

# Check from container
docker exec rota-core wget -q -O- http://localhost:8001/health
```

### Database

```bash
# Check database health
docker exec rota-timescaledb pg_isready -U rota -d rota
```

## Troubleshooting

### Container Won't Start

1. **Check logs**:
   ```bash
   docker-compose logs rota-core
   ```

2. **Verify database connection**:
   ```bash
   docker exec rota-core wget -q -O- http://localhost:8001/database/health
   ```

3. **Check environment variables**:
   ```bash
   docker exec rota-core env | grep DB_
   ```

### Database Connection Issues

1. **Verify database is running**:
   ```bash
   docker-compose ps timescaledb
   ```

2. **Check network connectivity**:
   ```bash
   docker exec rota-core ping timescaledb
   ```

3. **Test database connection**:
   ```bash
   docker exec rota-timescaledb psql -U rota -d rota -c "SELECT 1;"
   ```

### Port Conflicts

If ports are already in use:

```bash
# Check what's using the port
lsof -i :8000
lsof -i :8001
lsof -i :3000

# Change ports in docker-compose.yml
ports:
  - "8002:8000"  # Change host port
  - "8003:8001"
```

## Development with Docker

### Mount Source Code for Development

```yaml
services:
  rota-core:
    build:
      context: ./core
      dockerfile: Dockerfile
    volumes:
      - ./core:/app
    command: go run ./cmd/server/main.go
```

### Hot Reload for Dashboard

```yaml
services:
  rota-dashboard:
    build:
      context: ./dashboard
      dockerfile: Dockerfile
    volumes:
      - ./dashboard:/app
      - /app/node_modules
      - /app/.next
    command: pnpm dev
```

## Image Optimization

### Multi-Stage Builds

Both Dockerfiles use multi-stage builds to minimize image size:
- **Core**: ~20MB final image (from ~300MB builder)
- **Dashboard**: ~150MB final image (from ~1GB builder)

### Layer Caching

Dockerfiles are optimized for layer caching:
- Dependencies installed before source code
- Source code changes don't invalidate dependency layers

## Security Best Practices

1. **Non-root user**: Both containers run as non-root
2. **Minimal base images**: Alpine Linux for minimal attack surface
3. **No secrets in images**: Use environment variables or secrets
4. **Health checks**: Automatic health monitoring
5. **Read-only filesystem** (optional): Can be added for extra security

## Monitoring

### Container Stats

```bash
docker stats rota-core rota-dashboard
```

### Resource Limits

Add to `docker-compose.yml`:

```yaml
services:
  rota-core:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          cpus: '1'
          memory: 1G
```

## Backup and Restore

### Backup Database

```bash
docker exec rota-timescaledb pg_dump -U rota rota > backup.sql
```

### Restore Database

```bash
docker exec -i rota-timescaledb psql -U rota rota < backup.sql
```

## Summary

✅ **Dockerfiles exist** for both core and dashboard  
✅ **Docker Compose** configured for full stack  
✅ **Health checks** implemented  
✅ **Production-ready** with security best practices  
✅ **Easy deployment** with single command  

Run `docker-compose up -d` to start everything!

