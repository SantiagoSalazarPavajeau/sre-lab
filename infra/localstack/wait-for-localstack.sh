#!/usr/bin/env bash
set -euo pipefail

BASE_ENDPOINT=${1:-${LOCALSTACK_ENDPOINT:-http://localhost:4566}}
HEALTH_ENDPOINT="${BASE_ENDPOINT%/}/_localstack/health"
MAX_ATTEMPTS=${LOCALSTACK_MAX_ATTEMPTS:-30}
SLEEP_SECONDS=${LOCALSTACK_SLEEP_SECONDS:-2}

for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
  if OUTPUT=$(curl -fsS "$HEALTH_ENDPOINT" 2>/dev/null); then
    if echo "$OUTPUT" | grep -q '"ready": *true'; then
      echo "LocalStack is ready"
      exit 0
    fi
  fi
  echo "Waiting for LocalStack ($attempt/$MAX_ATTEMPTS)"
  sleep "$SLEEP_SECONDS"
done

echo "LocalStack did not become ready within $((MAX_ATTEMPTS * SLEEP_SECONDS)) seconds" >&2
exit 1
