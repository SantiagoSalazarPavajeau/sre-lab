#!/usr/bin/env bash
set -euo pipefail

BASE_ENDPOINT=${1:-${LOCALSTACK_ENDPOINT:-http://localhost:4566}}
HEALTH_HTTP="${BASE_ENDPOINT%/}/_localstack/health"
HEALTH_ENDPOINTS=($HEALTH_HTTP)
if [[ "$HEALTH_HTTP" == http://* ]]; then
  HEALTH_HTTPS="https://${HEALTH_HTTP#http://}"
  HEALTH_ENDPOINTS+=($HEALTH_HTTPS)
fi
MAX_ATTEMPTS=${LOCALSTACK_MAX_ATTEMPTS:-4}
SLEEP_SECONDS=${LOCALSTACK_SLEEP_SECONDS:-5}

for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
  for endpoint in "${HEALTH_ENDPOINTS[@]}"; do
    if OUTPUT=$(curl -fsS -k "$endpoint" 2>/dev/null); then
      if echo "$OUTPUT" | grep -q '"ready"[[:space:]]*:[[:space:]]*true'; then
        echo "LocalStack is ready (via $endpoint)"
        exit 0
      fi
      if echo "$OUTPUT" | grep -q '"status"[[:space:]]*:[[:space:]]*"running"'; then
        echo "LocalStack is ready (via $endpoint status)"
        exit 0
      fi
    fi
  done
  echo "Waiting for LocalStack ($attempt/$MAX_ATTEMPTS)"
  sleep "$SLEEP_SECONDS"
done

echo "LocalStack did not become ready within $((MAX_ATTEMPTS * SLEEP_SECONDS)) seconds" >&2
exit 1
