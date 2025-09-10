#!/usr/bin/env bash
set -euo pipefail

# Orchestrates the decoupled scripts to provide a convenient, one-shot setup.
# Honours APP and PORT_FORWARD env vars.

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

APP=${APP:-app}
PORT_FORWARD=${PORT_FORWARD:-0}

echo "[quickstart] Bringing up cluster..."
start-up/cluster-up.sh

echo "[quickstart] Deploying infra..."
start-up/deploy-infra.sh

echo "[quickstart] Deploying monitoring..."
start-up/deploy-monitoring.sh

echo "[quickstart] Deploying CI/CD..."
start-up/deploy-cicd.sh

echo "[quickstart] Deploying app '${APP}'..."
APP="$APP" PORT_FORWARD="$PORT_FORWARD" start-up/deploy-app.sh

if [ "$PORT_FORWARD" = "1" ]; then
  mkdir -p .scripts
  echo "[quickstart] Starting monitoring port-forwards..."
  # Prometheus 9090
  kubectl -n monitoring port-forward svc/prometheus 9090:9090 >/dev/null 2>&1 &
  echo $! > .scripts/pf_prometheus.pid
  # Grafana 3000
  kubectl -n monitoring port-forward svc/grafana 3000:3000 >/dev/null 2>&1 &
  echo $! > .scripts/pf_grafana.pid
  # cAdvisor 8081 -> 8080
  kubectl -n monitoring port-forward svc/cadvisor 8081:8080 >/dev/null 2>&1 &
  echo $! > .scripts/pf_cadvisor.pid
fi

echo "[quickstart] Done. APP=${APP}. PORT_FORWARD=${PORT_FORWARD}."
