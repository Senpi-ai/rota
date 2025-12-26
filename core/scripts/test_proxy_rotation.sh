#!/usr/bin/env bash

# Test script to verify proxy rotation is working
# Shows which proxy IPs are being used for each request

set -e

NUM_REQUESTS=${1:-20}
PROXY_URL="http://localhost:8000"
TARGET_URL="https://api.ipify.org?format=json"
API_URL="http://localhost:8001/api/v1"
API_USER="admin"
API_PASS="admin"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Rota Proxy Rotation Test ===${NC}"
echo "Sending $NUM_REQUESTS requests through rota proxy"
echo "Proxy: $PROXY_URL"
echo "Target: $TARGET_URL"
echo ""

# Check if services are running
echo -e "${CYAN}Checking services...${NC}"
if ! curl -s -f "http://localhost:8001/health" > /dev/null 2>&1; then
  echo -e "${RED}Error: API not accessible at http://localhost:8001${NC}"
  exit 1
fi

# Get current rotation settings
echo -e "${CYAN}Current rotation method:${NC}"
ROTATION_METHOD=$(curl -s -u "$API_USER:$API_PASS" "$API_URL/settings" | jq -r '.rotation.method')
echo "  Method: $ROTATION_METHOD"

if [ "$ROTATION_METHOD" = "rate-limited" ] || [ "$ROTATION_METHOD" = "rate_limited" ]; then
  RATE_LIMIT=$(curl -s -u "$API_USER:$API_PASS" "$API_URL/settings" | jq -r '.rotation.rate_limited.max_requests_per_minute')
  WINDOW=$(curl -s -u "$API_USER:$API_PASS" "$API_URL/settings" | jq -r '.rotation.rate_limited.window_seconds')
  echo "  Max requests per minute: $RATE_LIMIT"
  echo "  Window (seconds): $WINDOW"
fi

# Get proxy list
echo ""
echo -e "${CYAN}Registered proxies:${NC}"
PROXY_COUNT=$(curl -s -u "$API_USER:$API_PASS" "$API_URL/proxies" | jq '.proxies | length')
echo "  Total proxies: $PROXY_COUNT"
curl -s -u "$API_USER:$API_PASS" "$API_URL/proxies" | jq -r '.proxies[] | "  - ID: \(.id) | \(.protocol)://\(.address) | Status: \(.status)"'

if [ "$PROXY_COUNT" -eq 0 ]; then
  echo -e "${RED}Error: No proxies registered!${NC}"
  exit 1
fi

echo ""
echo -e "${GREEN}=== Sending Requests ===${NC}"
echo ""

# Track which IPs we see (this shows which proxy is being used)
# Use a temp file to track IPs (compatible with older bash)
TEMP_IPS=$(mktemp)
SUCCESS_COUNT=0
FAIL_COUNT=0

for i in $(seq 1 $NUM_REQUESTS); do
  # Send request through proxy and capture the IP
  RESPONSE=$(curl -s -x $PROXY_URL $TARGET_URL 2>&1)
  
  if echo "$RESPONSE" | jq -e '.ip' > /dev/null 2>&1; then
    IP=$(echo "$RESPONSE" | jq -r '.ip')
    echo "$IP" >> "$TEMP_IPS"
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    echo -e "${GREEN}Request $i:${NC} Proxy IP = $IP"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo -e "${RED}Request $i:${NC} Failed - $RESPONSE"
  fi
  
  # Small delay
  sleep 0.2
done

echo ""
echo -e "${BLUE}=== Results ===${NC}"
echo "Total requests: $NUM_REQUESTS"
echo "Successful: $SUCCESS_COUNT"
echo "Failed: $FAIL_COUNT"
echo ""

if [ $SUCCESS_COUNT -gt 0 ]; then
  echo -e "${CYAN}Proxy IPs used (rotation verification):${NC}"
  # Count unique IPs and their occurrences
  sort "$TEMP_IPS" | uniq -c | while read count ip; do
    PERCENTAGE=$(echo "scale=1; $count * 100 / $SUCCESS_COUNT" | bc 2>/dev/null || echo "0")
    echo "  $ip: $count requests ($PERCENTAGE%)"
  done
  
  UNIQUE_IPS=$(sort "$TEMP_IPS" | uniq | wc -l | tr -d ' ')
  echo ""
  echo "Unique proxy IPs used: $UNIQUE_IPS"
  
  if [ "$UNIQUE_IPS" -gt 1 ]; then
    echo -e "${GREEN}✓ Rotation is working! Multiple proxies are being used.${NC}"
  else
    echo -e "${YELLOW}⚠ Only one proxy IP detected. This might be expected depending on rotation method.${NC}"
  fi
  
  rm -f "$TEMP_IPS"
else
  echo -e "${RED}✗ No successful requests - cannot verify rotation${NC}"
  rm -f "$TEMP_IPS"
fi

echo ""
echo -e "${CYAN}=== Check Detailed Stats via API ===${NC}"
echo "View proxy statistics:"
echo "  curl -u $API_USER:$API_PASS $API_URL/proxies | jq '.proxies[] | {id, address, protocol, requests, success_rate}'"
echo ""
echo "View recent request logs:"
echo "  curl -u $API_USER:$API_PASS $API_URL/requests?limit=10 | jq"
echo ""
echo "Or visit the dashboard:"
echo "  http://localhost:3000"

