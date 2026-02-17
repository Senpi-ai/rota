# Rota codebase – API and proxy endpoints

## Overview
- Rota: proxy rotation platform (Go core + Next.js dashboard).
- API server: port 8001. Proxy server: port 8000. DB: Postgres/TimescaleDB.

## API server (base: http://host:8001)

### Public
- GET /health
- GET /docs (Swagger UI)
- GET /api/v1/swagger.json
- GET /api/v1/health

### Auth
- POST /api/v1/auth/login (body: username, password → JWT)

### Health & system
- GET /api/v1/status
- GET /api/v1/database/health
- GET /api/v1/database/stats
- GET /api/v1/metrics/system

### Dashboard
- GET /api/v1/dashboard/stats
- GET /api/v1/dashboard/charts/response-time
- GET /api/v1/dashboard/charts/success-rate

### Proxies
- GET /api/v1/proxies
- POST /api/v1/proxies
- POST /api/v1/proxies/bulk
- POST /api/v1/proxies/bulk-delete
- POST /api/v1/proxies/bulk-test
- GET /api/v1/proxies/export
- PUT /api/v1/proxies/{id}
- DELETE /api/v1/proxies/{id}
- POST /api/v1/proxies/{id}/test
- POST /api/v1/proxies/reload

### Logs
- GET /api/v1/logs
- GET /api/v1/logs/export

### Settings
- GET /api/v1/settings
- PUT /api/v1/settings
- POST /api/v1/settings/reset

### Webshare
- POST /api/v1/webshare/sync
- GET /api/v1/webshare/sync/status

### WebSockets
- GET /ws/dashboard
- GET /ws/logs

## Proxy server (port 8000)
- GET /health — liveness
- /hyperliquid, /hyperliquid/* — passthrough to api.hyperliquid.xyz (rate limited)
- Other: proxy traffic (auth + rate limit, rotation)

## Route definitions
- API: rota/core/internal/api/server.go (setupRoutes)
- Proxy: rota/core/internal/proxy/server.go (wrapper handler)