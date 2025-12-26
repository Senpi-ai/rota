# Monitoring Proxy Usage - Which IPs Are Being Used

## Overview

This guide shows you how to monitor which proxy IPs are being used and verify that rate-limited rotation is working correctly.

## API Endpoints for Monitoring

### 1. List All Proxies with Usage Stats

**Endpoint**: `GET /api/v1/proxies`

**Example**:
```bash
curl -H "Authorization: Bearer YOUR_TOKEN" \
  "http://localhost:8001/api/v1/proxies?limit=100"
```

**Response**:
```json
{
  "proxies": [
    {
      "id": 1,
      "address": "proxy1.example.com:8080",
      "protocol": "http",
      "status": "active",
      "requests": 25,
      "success_rate": 96.0,
      "avg_response_time": 150
    },
    {
      "id": 2,
      "address": "proxy2.example.com:8080",
      "protocol": "http",
      "status": "active",
      "requests": 30,
      "success_rate": 98.0,
      "avg_response_time": 120
    }
  ]
}
```

**What to check**:
- `requests`: Total lifetime requests per proxy
- `status`: Should be "active" for proxies in rotation
- Compare request counts to see distribution

### 2. Get Dashboard Statistics

**Endpoint**: `GET /api/v1/dashboard/stats`

**Example**:
```bash
curl -H "Authorization: Bearer YOUR_TOKEN" \
  "http://localhost:8001/api/v1/dashboard/stats"
```

**Response**:
```json
{
  "total_proxies": 100,
  "active_proxies": 95,
  "total_requests": 3000,
  "avg_success_rate": 97.5,
  "avg_response_time": 135
}
```

### 3. Get System Status

**Endpoint**: `GET /api/v1/status`

**Example**:
```bash
curl -H "Authorization: Bearer YOUR_TOKEN" \
  "http://localhost:8001/api/v1/status"
```

## Database Queries - See Which Proxy Was Used

### Query Recent Requests (Last Minute)

```sql
SELECT 
  proxy_id,
  proxy_address,
  COUNT(*) as requests_in_last_minute,
  AVG(response_time) as avg_response_time,
  SUM(CASE WHEN success THEN 1 ELSE 0 END) as successful,
  SUM(CASE WHEN NOT success THEN 1 ELSE 0 END) as failed
FROM proxy_requests
WHERE timestamp >= NOW() - INTERVAL '1 minute'
  AND success = true
GROUP BY proxy_id, proxy_address
ORDER BY requests_in_last_minute DESC;
```

**What this shows**:
- Which proxy IPs are being used
- How many requests each proxy handled in the last minute
- Average response time per proxy
- Success/failure counts

### Query Requests Per Proxy in Time Window

```sql
-- See requests per proxy in last 60 seconds (your rate limit window)
SELECT 
  proxy_id,
  proxy_address,
  COUNT(*) as requests_in_window,
  MIN(timestamp) as first_request,
  MAX(timestamp) as last_request
FROM proxy_requests
WHERE timestamp >= NOW() - INTERVAL '60 seconds'
  AND success = true
GROUP BY proxy_id, proxy_address
HAVING COUNT(*) >= 30  -- Show proxies at or near limit
ORDER BY requests_in_window DESC;
```

**What this shows**:
- Which proxies have reached the 30 requests/min limit
- Which proxies are still available (< 30 requests)
- Time distribution of requests

### Query All Requests with Proxy Details

```sql
SELECT 
  pr.proxy_id,
  pr.proxy_address,
  pr.url as endpoint,
  pr.method,
  pr.status_code,
  pr.success,
  pr.response_time,
  pr.timestamp
FROM proxy_requests pr
WHERE pr.timestamp >= NOW() - INTERVAL '5 minutes'
ORDER BY pr.timestamp DESC
LIMIT 100;
```

**What this shows**:
- Every request with which proxy was used
- Which endpoint was called
- Success/failure status
- Response times

### Verify Rate Limit Distribution

```sql
-- Check if proxies are being used evenly (should be ~30 requests each)
SELECT 
  proxy_id,
  proxy_address,
  COUNT(*) as requests_last_minute
FROM proxy_requests
WHERE timestamp >= NOW() - INTERVAL '1 minute'
  AND success = true
GROUP BY proxy_id, proxy_address
ORDER BY requests_last_minute DESC;
```

**Expected result**: Each proxy should have approximately 30 requests (your `n` value) before rotating to the next one.

## Testing Scripts

### Monitor Proxy Usage in Real-Time

```bash
#!/bin/bash
# monitor_proxy_usage.sh

TOKEN="YOUR_TOKEN"
API_URL="http://localhost:8001/api/v1"

while true; do
  echo "=== $(date) ==="
  
  # Get proxy list
  curl -s -H "Authorization: Bearer $TOKEN" \
    "$API_URL/proxies?limit=100" | \
    jq '.proxies[] | {id, address, requests, status}' | \
    head -20
  
  echo ""
  sleep 5
done
```

### Test Rate-Limited Rotation

```bash
#!/bin/bash
# test_rate_limited_rotation.sh

PROXY_URL="http://localhost:8000"
TARGET_URL="https://api.ipify.org?format=json"
TOKEN="YOUR_TOKEN"
API_URL="http://localhost:8001/api/v1"

echo "Sending 100 requests through rota proxy..."
echo "Each proxy should handle ~30 requests before rotating"
echo ""

for i in {1..100}; do
  # Send request through rota proxy
  curl -s -x $PROXY_URL $TARGET_URL > /dev/null
  
  if [ $((i % 10)) -eq 0 ]; then
    echo "Sent $i requests..."
    
    # Check proxy usage
    echo "Proxy usage (last minute):"
    curl -s -H "Authorization: Bearer $TOKEN" \
      "$API_URL/proxies?limit=10" | \
      jq '.proxies[] | "\(.address): \(.requests) requests"'
    echo ""
  fi
  
  sleep 0.1
done

echo "Done! Check database for detailed request distribution."
```

### Query Database from Command Line

```bash
# Using psql
psql -h localhost -U rota -d rota -c "
SELECT 
  proxy_address,
  COUNT(*) as requests_last_minute
FROM proxy_requests
WHERE timestamp >= NOW() - INTERVAL '1 minute'
GROUP BY proxy_address
ORDER BY requests_last_minute DESC;
"

# Using docker exec (if using docker-compose)
docker exec -it rota-db psql -U rota -d rota -c "
SELECT 
  proxy_address,
  COUNT(*) as requests_last_minute
FROM proxy_requests
WHERE timestamp >= NOW() - INTERVAL '1 minute'
GROUP BY proxy_address
ORDER BY requests_last_minute DESC;
"
```

## Dashboard UI

### View Proxy Usage

1. **Navigate to Dashboard**: `http://localhost:3000/dashboard/proxies`
2. **View Proxy List**: See all proxies with request counts
3. **Sort by Requests**: Click on "Requests" column to sort
4. **Filter by Status**: Filter to see only "active" proxies

### View Metrics

1. **Navigate to Metrics**: `http://localhost:3000/dashboard/metrics`
2. **View Charts**: See request distribution over time
3. **Check Success Rates**: Verify proxies are working correctly

## Verification Checklist

### ✅ Rate Limit Working Correctly

1. **Check Request Distribution**:
   ```sql
   SELECT proxy_address, COUNT(*) 
   FROM proxy_requests 
   WHERE timestamp >= NOW() - INTERVAL '1 minute'
   GROUP BY proxy_address;
   ```
   - Each proxy should have ≤ 30 requests in last minute

2. **Check Proxy Rotation**:
   - Send 100 requests
   - Verify ~3-4 proxies are used (100 / 30 = ~3.3)
   - Each proxy should have ~30 requests

3. **Check Exclusion**:
   ```sql
   -- Proxies at limit should not be selected
   SELECT proxy_id, COUNT(*) as requests
   FROM proxy_requests
   WHERE timestamp >= NOW() - INTERVAL '60 seconds'
   GROUP BY proxy_id
   HAVING COUNT(*) >= 30;
   ```
   - These proxies should be excluded from selection

### ✅ Endpoints Being Used

**Proxy Endpoint** (where requests go through):
- `http://localhost:8000` - Main proxy server

**API Endpoints** (for monitoring):
- `GET /api/v1/proxies` - List proxies
- `GET /api/v1/dashboard/stats` - Dashboard stats
- `GET /api/v1/status` - System status

**Database**:
- `proxy_requests` table - All request history
- `proxies` table - Proxy metadata and stats

## Example: Full Test Flow

```bash
# 1. Configure rate-limited rotation
curl -X PUT http://localhost:8001/api/v1/settings \
  -H "Authorization: Bearer $TOKEN" \
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

# 2. Send test requests
for i in {1..100}; do
  curl -x http://localhost:8000 https://api.ipify.org?format=json
  sleep 0.1
done

# 3. Check which proxies were used
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:8001/api/v1/proxies?limit=100" | \
  jq '.proxies[] | select(.requests > 0) | {address, requests}'

# 4. Query database for detailed view
psql -h localhost -U rota -d rota -c "
SELECT 
  proxy_address,
  COUNT(*) as requests,
  MIN(timestamp) as first,
  MAX(timestamp) as last
FROM proxy_requests
WHERE timestamp >= NOW() - INTERVAL '2 minutes'
GROUP BY proxy_address
ORDER BY requests DESC;
"
```

## Troubleshooting

### Issue: All requests going through one proxy

**Check**:
- Rate limit configuration: `GET /api/v1/settings`
- Verify `method` is `"rate-limited"`
- Check `max_requests_per_minute` is set correctly

### Issue: Proxies not rotating

**Check**:
- Database query to see request counts per proxy
- Verify proxies are "active" status
- Check for errors in logs

### Issue: Can't see which proxy was used

**Solution**:
- Query `proxy_requests` table directly
- Use dashboard UI at `http://localhost:3000`
- Check API response for proxy details

## Summary

**To see which IPs are being used**:
1. ✅ Query `proxy_requests` table (most detailed)
2. ✅ Use `/api/v1/proxies` endpoint (current stats)
3. ✅ Use Dashboard UI (visual)
4. ✅ Check logs (real-time)

**Endpoints**:
- **Proxy**: `http://localhost:8000` (where requests go)
- **API**: `http://localhost:8001/api/v1/*` (monitoring)
- **Dashboard**: `http://localhost:3000` (UI)
- **Database**: `localhost:5432` (direct queries)

