-- Quick SQL Queries to Check Which Proxy IPs Are Being Used
-- Run these queries against your rota database

-- 1. See which proxies were used in the last minute
SELECT 
  proxy_id,
  proxy_address as proxy_ip,
  COUNT(*) as requests_in_last_minute,
  AVG(response_time) as avg_response_time_ms,
  SUM(CASE WHEN success THEN 1 ELSE 0 END) as successful,
  SUM(CASE WHEN NOT success THEN 1 ELSE 0 END) as failed
FROM proxy_requests
WHERE timestamp >= NOW() - INTERVAL '1 minute'
  AND success = true
GROUP BY proxy_id, proxy_address
ORDER BY requests_in_last_minute DESC;

-- 2. Check if rate limiting is working (should see ~30 requests per proxy)
SELECT 
  proxy_address as proxy_ip,
  COUNT(*) as requests_in_last_minute,
  CASE 
    WHEN COUNT(*) >= 30 THEN 'AT LIMIT'
    ELSE 'AVAILABLE'
  END as status
FROM proxy_requests
WHERE timestamp >= NOW() - INTERVAL '1 minute'
  AND success = true
GROUP BY proxy_address
ORDER BY requests_in_last_minute DESC;

-- 3. See all recent requests with proxy details
SELECT 
  pr.timestamp,
  pr.proxy_address as proxy_ip,
  pr.url as endpoint_called,
  pr.method,
  pr.status_code,
  pr.success,
  pr.response_time as response_time_ms
FROM proxy_requests pr
WHERE pr.timestamp >= NOW() - INTERVAL '5 minutes'
ORDER BY pr.timestamp DESC
LIMIT 50;

-- 4. Check request distribution across proxies (last 5 minutes)
SELECT 
  proxy_address as proxy_ip,
  COUNT(*) as total_requests,
  COUNT(*) FILTER (WHERE timestamp >= NOW() - INTERVAL '1 minute') as requests_last_minute,
  COUNT(*) FILTER (WHERE timestamp >= NOW() - INTERVAL '60 seconds' AND timestamp >= NOW() - INTERVAL '1 minute') as requests_previous_minute,
  AVG(response_time) as avg_response_time_ms,
  MIN(timestamp) as first_request,
  MAX(timestamp) as last_request
FROM proxy_requests
WHERE timestamp >= NOW() - INTERVAL '5 minutes'
  AND success = true
GROUP BY proxy_address
ORDER BY total_requests DESC;

-- 5. Find proxies that have reached the rate limit (30 requests in 60 seconds)
SELECT 
  proxy_id,
  proxy_address as proxy_ip,
  COUNT(*) as requests_in_window
FROM proxy_requests
WHERE timestamp >= NOW() - INTERVAL '60 seconds'
  AND success = true
GROUP BY proxy_id, proxy_address
HAVING COUNT(*) >= 30
ORDER BY requests_in_window DESC;

-- 6. Find available proxies (under 30 requests in last 60 seconds)
SELECT 
  proxy_id,
  proxy_address as proxy_ip,
  COUNT(*) as requests_in_window,
  30 - COUNT(*) as requests_remaining
FROM proxy_requests
WHERE timestamp >= NOW() - INTERVAL '60 seconds'
  AND success = true
GROUP BY proxy_id, proxy_address
HAVING COUNT(*) < 30
ORDER BY requests_in_window DESC;

-- 7. Check rotation pattern (which proxies were used in sequence)
SELECT 
  timestamp,
  proxy_address as proxy_ip,
  url as endpoint,
  ROW_NUMBER() OVER (PARTITION BY proxy_address ORDER BY timestamp) as request_number_for_proxy
FROM proxy_requests
WHERE timestamp >= NOW() - INTERVAL '10 minutes'
  AND success = true
ORDER BY timestamp ASC
LIMIT 100;

-- 8. Summary: Proxy usage statistics
SELECT 
  COUNT(DISTINCT proxy_address) as unique_proxies_used,
  COUNT(*) as total_requests,
  COUNT(*) FILTER (WHERE timestamp >= NOW() - INTERVAL '1 minute') as requests_last_minute,
  AVG(response_time) as avg_response_time_ms,
  SUM(CASE WHEN success THEN 1 ELSE 0 END) * 100.0 / COUNT(*) as success_rate_percent
FROM proxy_requests
WHERE timestamp >= NOW() - INTERVAL '10 minutes';

