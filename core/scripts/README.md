# Test Scripts

This directory contains scripts for testing and monitoring Rota.

## Scripts

### `run_tests.sh`
Runs Go tests with various options.

**Usage:**
```bash
cd rota/core
./scripts/run_tests.sh [all|unit|integration|coverage]
```

**Examples:**
```bash
# Run all tests
./scripts/run_tests.sh all

# Run only integration tests
./scripts/run_tests.sh integration

# Run with coverage
./scripts/run_tests.sh coverage
```

### `test_proxy_rotation.sh`
Tests proxy rotation functionality by sending requests through Rota and showing which proxy IPs are being used.

**Usage:**
```bash
cd rota
./core/scripts/test_proxy_rotation.sh [number_of_requests]
```

**Examples:**
```bash
# Send 20 requests
./core/scripts/test_proxy_rotation.sh 20

# Send 100 requests (default)
./core/scripts/test_proxy_rotation.sh 100
```

**What it does:**
- Checks current rotation settings
- Lists registered proxies
- Sends requests through the proxy
- Shows which proxy IPs were used
- Displays distribution statistics

### `test_proxy_usage.sh`
Sends requests through Rota and provides instructions for checking proxy usage.

**Usage:**
```bash
cd rota
./core/scripts/test_proxy_usage.sh [number_of_requests]
```

**Examples:**
```bash
# Send 100 requests (default)
./core/scripts/test_proxy_usage.sh

# Send 500 requests
./core/scripts/test_proxy_usage.sh 500
```

### `queries_check_proxy_usage.sql`
SQL queries for checking proxy usage in the database.

**Usage:**
```bash
# Connect to database
docker exec -it rota-timescaledb psql -U rota -d rota

# Then run queries from the file
\i core/scripts/queries_check_proxy_usage.sql
```

Or copy and paste queries directly into psql.

## Prerequisites

- Rota services running (via `docker-compose up -d`)
- API accessible at `http://localhost:8001`
- Proxy accessible at `http://localhost:8000`
- Default credentials: `admin:admin`

## Environment Variables

Scripts use these defaults:
- `API_URL=http://localhost:8001/api/v1`
- `PROXY_URL=http://localhost:8000`
- `API_USER=admin`
- `API_PASS=admin`

You can override these by setting environment variables before running scripts.

