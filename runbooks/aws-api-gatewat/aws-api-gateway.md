🔹 10 SRE Lab Tasks for AWS API Gateway
1. 🔐 JWT Authorizer Debugging

Configure an HTTP API with a JWT authorizer (e.g., Amazon Cognito).

Break it by using an expired or malformed token.

Practice reading CloudWatch logs and error responses (401 Unauthorized) to pinpoint auth failures.

2. 🌐 WebSocket Connection Storm

Set up a WebSocket API with $connect, $default, $disconnect.

Simulate 500+ concurrent clients with a tool like wscat or ab.

Monitor CloudWatch for 429 Too Many Requests and adjust throttle limits.

3. 🛑 Throttling / Quota Drill

Enable usage plans + API keys on a REST API.

Set a quota of 100 requests/day.

Send 150 requests, observe 429 errors.

Check how CloudWatch metrics (ThrottledRequests) reflect this.

4. 🧯 Incident Simulation: 502 Bad Gateway

Integrate an API Gateway route with a backend Lambda that times out.

Trigger 502 Bad Gateway errors.

Practice:

Check Execution logs in CloudWatch.

Increase integration timeout.

Redeploy and verify recovery.

5. 📊 Latency SLO Dashboard

Collect p50, p95, p99 latency metrics from API Gateway.

Create a CloudWatch dashboard with latency + 4xx/5xx error rates.

Set an alarm if p95 latency > 500ms for 5 minutes.

6. 🛡 Attach WAF and Block SQLi

Deploy a REST API.

Attach AWS WAF with an OWASP managed rule set.

Send a request like:

GET /items?id=1' OR '1'='1


Verify the request is blocked and logged.

7. 🔄 Canary Deployment

Deploy v1 of an API Lambda (returns Hello v1).

Enable canary release on stage → 20% traffic to v2 (Hello v2).

Curl repeatedly and confirm responses split between versions.

Roll back to v1 (simulate failed deploy).

8. 📉 Cost Spike Investigation

Generate high RPS traffic for 30 min.

Check API Gateway cost breakdown in Cost Explorer.

Practice identifying “chatty client” traffic and propose optimizations (batching, caching).

9. 🔍 mTLS Enforcement

Create a REST API with a custom domain.

Enable mutual TLS with ACM + truststore in S3.

Test with curl:

curl --cert client.crt --key client.key https://api.example.com


Confirm requests without a cert fail.

10. 🚨 On-Call Drill: High 5xx Alert

Simulate a broken backend (Lambda error, NLB target down).

API Gateway shows 5xx surge.

Run through incident workflow:

CloudWatch alarms trigger.

Identify failing integration.

Deploy fallback (mock integration or cached response).

Verify alarms clear.

✅ These mirror what SREs really face:

Config errors (auth, mTLS).

Scaling limits (throttling, WebSocket bursts).

Reliability drills (502s, canaries).

Security (WAF, quotas).

Observability & cost awareness.