#!/bin/bash

# Test Runner Script for Rota Rate-Limited Rotation
# Usage: ./run_tests.sh [unit|integration|all]

set -e

TEST_TYPE=${1:-all}
TEST_DIR="./internal/proxy"

echo "🧪 Rota Test Runner"
echo "==================="
echo ""

case $TEST_TYPE in
  unit)
    echo "Running unit tests..."
    go test $TEST_DIR -v
    ;;
  integration)
    echo "Running integration tests..."
    echo "⚠️  Note: Integration tests require a test database"
    echo ""
    
    # Check if test database environment variables are set
    if [ -z "$DB_HOST" ]; then
      echo "❌ Error: Test database not configured"
      echo ""
      echo "Set these environment variables:"
      echo "  export DB_HOST=localhost"
      echo "  export DB_PORT=5433"
      echo "  export DB_USER=rota_test"
      echo "  export DB_PASSWORD=test_password"
      echo "  export DB_NAME=rota_test"
      echo "  export DB_SSLMODE=disable"
      echo ""
      echo "Or start test database with:"
      echo "  docker run -d --name rota-test-db \\"
      echo "    -e POSTGRES_USER=rota_test \\"
      echo "    -e POSTGRES_PASSWORD=test_password \\"
      echo "    -e POSTGRES_DB=rota_test \\"
      echo "    -p 5433:5432 \\"
      echo "    timescale/timescaledb:latest-pg16"
      exit 1
    fi
    
    go test -tags=integration $TEST_DIR -v
    ;;
  all)
    echo "Running all tests..."
    echo ""
    echo "1. Unit tests (will skip - need database):"
    go test $TEST_DIR -v
    echo ""
    echo "2. Integration tests (require database):"
    if [ -z "$DB_HOST" ]; then
      echo "   ⚠️  Skipping - test database not configured"
    else
      go test -tags=integration $TEST_DIR -v
    fi
    ;;
  *)
    echo "Usage: $0 [unit|integration|all]"
    exit 1
    ;;
esac

echo ""
echo "✅ Tests completed!"

