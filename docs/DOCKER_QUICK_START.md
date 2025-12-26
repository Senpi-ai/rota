# Docker Quick Start Guide

## 🚀 Quick Start (3 Commands)

```bash
# 1. Clone and navigate
cd rota

# 2. Start everything
docker-compose up -d

# 3. Access services
# Dashboard: http://localhost:3000 (admin/admin)
# API: http://localhost:8001
# Proxy: http://localhost:8000
```

## 📋 What Gets Started

- **Rota Core** (Go): Proxy server + API
- **Rota Dashboard** (Next.js): Web UI
- **TimescaleDB**: Database with time-series support

## 🔧 Common Commands

### Start Services
```bash
docker-compose up -d
```

### Stop Services
```bash
docker-compose down
```

### View Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f rota-core
```

### Restart Service
```bash
docker-compose restart rota-core
```

### Rebuild After Code Changes
```bash
docker-compose build rota-core
docker-compose up -d rota-core
```

## 🏗️ Build Individual Images

### Build Core
```bash
cd core
docker build -t rota-core:latest .
```

### Build Dashboard
```bash
cd dashboard
docker build -t rota-dashboard:latest .
```

## 🔍 Verify Everything Works

```bash
# Check health
curl http://localhost:8001/health

# Check API docs
open http://localhost:8001/docs

# Check dashboard
open http://localhost:3000
```

## 📝 Environment Variables

Create `.env` file for custom configuration:

```bash
DB_HOST=your-db-host
DB_PASSWORD=your-secure-password
ROTA_ADMIN_PASSWORD=your-admin-password
```

Then run:
```bash
docker-compose --env-file .env up -d
```

## 🐛 Troubleshooting

### Port Already in Use
```bash
# Check what's using the port
lsof -i :8000
lsof -i :8001
lsof -i :3000

# Change ports in docker-compose.yml
```

### Container Won't Start
```bash
# Check logs
docker-compose logs rota-core

# Check container status
docker-compose ps
```

### Database Connection Issues
```bash
# Verify database is running
docker-compose ps timescaledb

# Check database logs
docker-compose logs timescaledb
```

## 📚 More Information

See `DOCKER_SETUP.md` for detailed documentation.

