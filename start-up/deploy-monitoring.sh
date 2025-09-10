#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

echo "Deploying monitoring stack (Prometheus, Grafana, Alertmanager, exporters)..."
kubectl apply -f k8s/monitoring/

echo "Waiting for Prometheus and Grafana to be ready (120s timeout)..."
for DEP in prometheus grafana; do
  kubectl -n monitoring wait --for=condition=available deploy/${DEP} --timeout=120s || true
done

echo "Monitoring deployed."
