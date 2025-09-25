#!/usr/bin/env bash
set -euo pipefail

# Orchestrates the decoupled scripts to provide a convenient, one-shot setup.
# Honours APP and PORT_FORWARD env vars.

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

KUBECONFIG_FILE="${ROOT}/.kind-kubeconfig"
export KUBECONFIG="${KUBECONFIG_FILE}"

APP=${APP:-app}
# Enable port-forwards by default for local UX
PORT_FORWARD=${PORT_FORWARD:-1}

echo "[quickstart] Starting LocalStack and provisioning mock AWS..."
start-up/localstack-up.sh
if command -v terraform >/dev/null 2>&1; then
  # Wait for LocalStack to be healthy, then apply Terraform
  infra/localstack/wait-for-localstack.sh "http://localhost:4566"
  (
    cd infra/terraform
    terraform init -input=false
    terraform workspace select localstack || terraform workspace new localstack
    terraform apply -input=false -auto-approve -var-file=environments/localstack.tfvars -var="localstack_endpoint=http://localhost:4566"
  )
else
  echo "[quickstart] Terraform not found; skipping mock AWS provisioning"
fi

echo "[quickstart] Bringing up cluster..."
start-up/cluster-up.sh

echo "[quickstart] Deploying infra..."
start-up/deploy-infra.sh

echo "[quickstart] Deploying monitoring..."
start-up/deploy-monitoring.sh

echo "[quickstart] Deploying app '${APP}'..."
APP="$APP" PORT_FORWARD="$PORT_FORWARD" start-up/deploy-app.sh

if [ "$PORT_FORWARD" = "1" ]; then
  mkdir -p .scripts
  echo "[quickstart] Starting monitoring port-forwards..."
  # Prometheus 9090
  kubectl -n monitoring port-forward svc/prometheus 9090:9090 >/dev/null 2>&1 &
  echo $! > .scripts/pf_prometheus.pid
  # Grafana 3001
  kubectl -n monitoring port-forward svc/grafana 3001:3001 >/dev/null 2>&1 &
  echo $! > .scripts/pf_grafana.pid
  # cAdvisor 8081 -> 8080
  kubectl -n monitoring port-forward svc/cadvisor 8081:8080 >/dev/null 2>&1 &
  echo $! > .scripts/pf_cadvisor.pid
fi

# Run end-to-end smoke checks
if [ -x scripts/smoke.sh ]; then
  echo "[quickstart] Running end-to-end checks..."
  APP="$APP" scripts/smoke.sh || {
    echo "[quickstart] End-to-end checks FAILED" >&2
    exit 1
  }
else
  echo "[quickstart] Skipping end-to-end checks (scripts/smoke.sh not found)"
fi

echo "[quickstart] Done. APP=${APP}. PORT_FORWARD=${PORT_FORWARD}."
