#!/bin/bash

# Test script to monitor which proxy IPs are being used
# Usage: ./test_proxy_usage.sh [number_of_requests]

set -e

NUM_REQUESTS=${1:-100}
PROXY_URL="http://localhost:8000"
TARGET_URL="https://api.ipify.org?format=json"
API_URL="http://localhost:8001/api/v1"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Rota Proxy Usage Test ===${NC}"
echo "Sending $NUM_REQUESTS requests through rota proxy"
echo "Proxy: $PROXY_URL"
echo "Target: $TARGET_URL"
echo ""

# Check if API is accessible
if ! curl -s "$API_URL/health" > /dev/null; then
  echo -e "${YELLOW}Warning: API not accessible at $API_URL${NC}"
  echo "Continuing with proxy requests only..."
  echo ""
fi

# Send requests
echo -e "${GREEN}Sending requests...${NC}"
for i in $(seq 1 $NUM_REQUESTS); do
  # Send request through proxy
  curl -s -x $PROXY_URL $TARGET_URL > /dev/null 2>&1
  
  # Show progress every 10 requests
  if [ $((i % 10)) -eq 0 ]; then
    echo -e "${BLUE}Progress: $i/$NUM_REQUESTS requests sent${NC}"
  fi
  
  # Small delay to avoid overwhelming
  sleep 0.1
done

echo ""
echo -e "${GREEN}All requests sent!${NC}"
echo ""
echo -e "${BLUE}=== Next Steps ===${NC}"
echo "1. Query database to see which proxies were used:"
echo "   psql -h localhost -U rota -d rota -c \""
echo "   SELECT proxy_address, COUNT(*) as requests"
echo "   FROM proxy_requests"
echo "   WHERE timestamp >= NOW() - INTERVAL '2 minutes'"
echo "   GROUP BY proxy_address"
echo "   ORDER BY requests DESC;\""
echo ""
echo "2. Check API for proxy stats:"
echo "   curl -H 'Authorization: Bearer YOUR_TOKEN' \\"
echo "     '$API_URL/proxies?limit=100' | jq '.proxies[] | {address, requests}'"
echo ""
echo "3. View Dashboard:"
echo "   http://localhost:3000/dashboard/proxies"
echo ""

