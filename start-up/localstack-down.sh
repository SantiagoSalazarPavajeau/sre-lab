#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
COMPOSE_FILE="${ROOT}/infra/localstack/docker-compose.yml"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required to stop LocalStack" >&2
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "docker compose plugin is required (Docker CLI v2)" >&2
  exit 1
fi

echo "Stopping LocalStack"
docker compose -f "${COMPOSE_FILE}" down "$@"
