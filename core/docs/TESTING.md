# Testing Guide for Rota

## Overview

This guide covers how to run tests for the Rota proxy rotation platform, including unit tests and integration tests for the rate-limited rotation strategy.

## Test Structure

### Unit Tests (`rotation_test.go`)

Basic unit tests that can run without a database:
- Constructor tests
- Configuration validation
- Method name variant handling

**Status**: Currently skipped (require database for full testing)

### Integration Tests (`rotation_integration_test.go`)

Full integration tests that require a database connection:
- Proxy selection with real database queries
- Rate limit enforcement
- Cache behavior
- Window expiration
- Configurable values

**Tag**: `integration` - Run with `go test -tags=integration`

## Quick Start

### Option 1: Run Tests (They'll Skip - Shows Structure)

```bash
cd rota/core
go test ./internal/proxy -v
```

This will show the test structure but all tests will skip (they need a database).

### Option 2: Set Up Test Database and Run Integration Tests

## Step-by-Step: Set Up Test Database

### 1. Start Test Database with Docker

```bash
# Start TimescaleDB container
docker run -d \
  --name rota-test-db \
  -e POSTGRES_USER=rota_test \
  -e POSTGRES_PASSWORD=test_password \
  -e POSTGRES_DB=rota_test \
  -p 5433:5432 \
  timescale/timescaledb:latest-pg16

# Wait for database to be ready
sleep 5

# Verify it's running
docker ps | grep rota-test-db
```

### 2. Set Environment Variables (Optional - defaults work)

```bash
export DB_HOST=localhost
export DB_PORT=5433
export DB_USER=rota_test
export DB_PASSWORD=test_password
export DB_NAME=rota_test
export DB_SSLMODE=disable
```

### 3. Run Integration Tests

The test setup function (`setupTestDB()`) automatically:
- Connects to the test database
- Runs all migrations
- Cleans up test data

```bash
cd rota/core
go test -tags=integration ./internal/proxy -v
```

## Test Coverage

### What We Test

✅ **Proxy Selection**
- Selects available proxy when none at limit
- Excludes proxies at rate limit
- Returns error when all proxies at limit
- Round-robin selection from available proxies

✅ **Rate Limiting**
- Enforces max_requests_per_minute limit
- Respects window_seconds time window
- Handles window expiration correctly

✅ **Caching**
- Caches available proxies for performance
- Invalidates cache on refresh
- Cache expires after configured duration

✅ **Configuration**
- Uses configured max_requests_per_minute
- Uses configured window_seconds
- Applies defaults when not configured
- Handles method name variants

✅ **Edge Cases**
- All proxies at limit
- Database query failures
- Empty proxy list
- Zero requests (all proxies available)

## Test Commands

### See Test Structure
```bash
cd rota/core
go test ./internal/proxy -v
```

### Run with Coverage
```bash
cd rota/core
go test ./internal/proxy -cover
```

### Run Specific Test
```bash
cd rota/core
go test ./internal/proxy -v -run TestNewProxySelector_RateLimited_Variants
```

### Run Integration Tests (once DB is set up)
```bash
cd rota/core
go test -tags=integration ./internal/proxy -v
```

### Run All Tests
```bash
cd rota/core
go test ./... -v
```

## Test Scripts

Use the provided test scripts in `core/scripts/`:

```bash
# Run all tests
cd rota/core
./scripts/run_tests.sh all

# Run integration tests only
./scripts/run_tests.sh integration
```

## Helper Functions

The integration tests include helper functions:

### `setupTestDB(t *testing.T) *pgxpool.Pool`
- Creates database connection
- Runs migrations
- Cleans up test data
- Returns database pool

### `cleanupTestData(ctx, t, pool)`
- Truncates all test tables
- Ensures clean state for each test

### `createTestProxy(ctx, t, pool, address, protocol) int`
- Creates a test proxy in database
- Returns proxy ID

### `insertTestRequest(ctx, t, pool, proxyID, success, age)`
- Inserts a test request into `proxy_requests` table
- `age` parameter controls how old the request is (for testing window expiration)

## Configuration

The test setup reads these environment variables (with defaults):

```bash
DB_HOST=localhost          # Default: localhost
DB_PORT=5433              # Default: 5433
DB_USER=rota_test         # Default: rota_test
DB_PASSWORD=test_password # Default: test_password
DB_NAME=rota_test         # Default: rota_test
DB_SSLMODE=disable        # Default: disable
```

## Alternative: Manual Testing

Since automated tests need database setup, you can manually test:

### 1. Start Rota with Test Configuration

```bash
cd rota
docker-compose up -d
```

### 2. Configure Rate-Limited Rotation

```bash
curl -X PUT -u admin:admin http://localhost:8001/api/v1/settings \
  -H "Content-Type: application/json" \
  -d '{
    "rotation": {
      "method": "rate-limited",
      "rate_limited": {
        "max_requests_per_minute": 30,
        "window_seconds": 60
      }
    }
  }'
```

### 3. Add Test Proxies

```bash
curl -X POST -u admin:admin http://localhost:8001/api/v1/proxies \
  -H "Content-Type: application/json" \
  -d '{
    "address": "test-proxy:8080",
    "protocol": "http"
  }'
```

### 4. Send Requests and Monitor

```bash
# Send requests through proxy
curl -x http://localhost:8000 https://api.ipify.org

# Check proxy usage
curl -u admin:admin http://localhost:8001/api/v1/proxies
```

### 5. Use Test Scripts

```bash
# Test proxy rotation
cd rota
./core/scripts/test_proxy_rotation.sh 20

# Monitor proxy usage
./core/scripts/test_proxy_usage.sh 100
```

## Continuous Integration

### GitHub Actions Example

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: timescale/timescaledb:latest-pg16
        env:
          POSTGRES_USER: rota_test
          POSTGRES_PASSWORD: test_password
          POSTGRES_DB: rota_test
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-go@v4
        with:
          go-version: '1.25'
      
      - name: Run tests
        env:
          DB_HOST: localhost
          DB_PORT: 5432
          DB_USER: rota_test
          DB_PASSWORD: test_password
          DB_NAME: rota_test
        run: |
          cd core
          go test -tags=integration ./... -v
```

## Troubleshooting

### Database Connection Fails

**Error**: `Test database not available`

**Solution**: 
1. Check if Docker container is running: `docker ps | grep rota-test-db`
2. Check environment variables match container settings
3. Verify port 5433 is not in use: `lsof -i :5433`

### Migrations Fail

**Error**: `Failed to run migrations`

**Solution**:
1. Check database logs: `docker logs rota-test-db`
2. Verify TimescaleDB extension is available
3. Check database permissions

### Tests Timeout

**Error**: Test times out

**Solution**:
1. Increase timeout in `setupTestDB()` if needed
2. Check database performance
3. Verify network connectivity

## Best Practices

1. **Isolation**: Each test should be independent
2. **Cleanup**: Always clean up test data
3. **Realistic Data**: Use realistic test scenarios
4. **Error Cases**: Test error handling
5. **Edge Cases**: Test boundary conditions
6. **Documentation**: Document test scenarios

## Current Status

- ✅ Test structure created
- ✅ Integration tests implemented
- ✅ Test database setup function complete
- ✅ Helper functions for test data
- ✅ Test scripts available

## Next Steps

1. ✅ Run integration tests with real database
2. ✅ Test rate limiting behavior
3. ✅ Verify window expiration
4. ✅ Test edge cases
5. 📝 Add more unit tests (with mocks)
6. 📝 Achieve >80% code coverage

