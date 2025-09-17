#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
COMPOSE_FILE="${ROOT}/infra/localstack/docker-compose.yml"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required to run LocalStack" >&2
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "docker compose plugin is required (Docker CLI v2)" >&2
  exit 1
fi

echo "Starting LocalStack using ${COMPOSE_FILE}"
docker compose -f "${COMPOSE_FILE}" up -d

echo "LocalStack edge endpoint available at http://localhost:4566"

echo "(Optional) Provision mock infrastructure with Terraform"
echo "  cd ${ROOT}/infra/terraform"
echo "  terraform init"
echo "  terraform apply -auto-approve -var-file=environments/localstack.tfvars"
