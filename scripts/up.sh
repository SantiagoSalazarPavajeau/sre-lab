#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

echo "[sre-lab] Starting Minikube (if not running)..."
if ! minikube status >/dev/null 2>&1; then
  minikube start --driver=hyperkit --memory=4096 --cpus=2
else
  echo "[sre-lab] minikube already running"
fi

echo "[sre-lab] Building app image..."
docker build -t sre-lab-app:latest ./src/services/app

echo "[sre-lab] Loading image into minikube..."
minikube image load sre-lab-app:latest

echo "[sre-lab] Applying k8s manifests..."
kubectl apply -f k8s/

echo "[sre-lab] Waiting for pods to become Ready (120s timeout)..."
kubectl -n sre-lab wait --for=condition=Ready pods --all --timeout=120s || {
  echo "[sre-lab] Some pods did not become ready within timeout. Listing pods:"
  kubectl -n sre-lab get pods -o wide
}

if [ "${PORT_FORWARD:-0}" = "1" ]; then
  mkdir -p .scripts
  echo "[sre-lab] Starting port-forwards in background and saving PIDs to .scripts/"
  kubectl -n sre-lab port-forward svc/prometheus 9090:9090 >/dev/null 2>&1 &
  echo $! > .scripts/pf_prometheus.pid

  kubectl -n sre-lab port-forward svc/grafana 3000:3000 >/dev/null 2>&1 &
  echo $! > .scripts/pf_grafana.pid

  kubectl -n sre-lab port-forward svc/app 8080:8080 >/dev/null 2>&1 &
  echo $! > .scripts/pf_app.pid

  kubectl -n sre-lab port-forward svc/cadvisor 8081:8080 >/dev/null 2>&1 &
  echo $! > .scripts/pf_cadvisor.pid

  echo "[sre-lab] Port-forwards started. Use scripts/down.sh to stop them (or set PORT_FORWARD=1 when running up.sh)."
else
  echo "[sre-lab] Port-forward disabled. To enable automatic port-forwards set PORT_FORWARD=1 before running this script."
fi

echo "[sre-lab] Done."
