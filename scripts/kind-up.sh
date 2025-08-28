#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

# Create a kind cluster named 'sre-lab' (if it doesn't exist), build the local app image,
# load it into kind, apply k8s manifests, and optionally start port-forwards.

if ! command -v kind >/dev/null 2>&1; then
  echo "kind is not installed. Install with: brew install kind" >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required. Make sure Docker Desktop is running or docker is available." >&2
  exit 1
fi

CLUSTER_NAME=${KIND_CLUSTER_NAME:-sre-lab}

if ! kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
  echo "Creating kind cluster '${CLUSTER_NAME}' with config..."
  kind create cluster --name "${CLUSTER_NAME}" --config kind-config.yaml
else
  echo "Kind cluster '${CLUSTER_NAME}' already exists"
fi

echo "Building app image..."
docker build -t sre-lab-app:latest ./src/services/app

echo "Loading image into kind cluster (${CLUSTER_NAME})..."
kind load docker-image --name "${CLUSTER_NAME}" sre-lab-app:latest

echo "Creating namespace..."
kubectl apply -f k8s/namespace.yaml

echo "Installing Argo CD..."
kubectl create namespace argocd || true
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for Argo CD server to be ready (120s timeout)..."
kubectl -n argocd wait --for=condition=available deploy/argocd-server --timeout=120s

echo "Applying k8s manifests..."
kubectl apply -f k8s/

echo "Waiting for pods to become Ready (120s timeout)..."
kubectl -n sre-lab wait --for=condition=Ready pods --all --timeout=120s || {
  echo "Some pods did not become ready within timeout. Listing pods:"
  kubectl -n sre-lab get pods -o wide
}

if [ "${PORT_FORWARD:-0}" = "1" ]; then
  mkdir -p .scripts
  echo "Starting port-forwards and saving PIDs to .scripts/"
  kubectl -n sre-lab port-forward svc/prometheus 9090:9090 >/dev/null 2>&1 &
  echo $! > .scripts/pf_prometheus.pid

  kubectl -n sre-lab port-forward svc/grafana 3000:3000 >/dev/null 2>&1 &
  echo $! > .scripts/pf_grafana.pid

  kubectl -n sre-lab port-forward svc/app 8080:8080 >/dev/null 2>&1 &
  echo $! > .scripts/pf_app.pid

  kubectl -n sre-lab port-forward svc/cadvisor 8081:8080 >/dev/null 2>&1 &
  echo $! > .scripts/pf_cadvisor.pid

  echo "Port-forwards started. Use scripts/kind-down.sh to stop them (or set PORT_FORWARD=1 when running up.sh)."
else
  echo "Port-forward disabled. To enable automatic port-forwards set PORT_FORWARD=1 before running this script."
fi

echo "Done."
echo
echo "Argo CD is installed. To access the UI:"
echo "  kubectl -n argocd port-forward svc/argocd-server 8080:443"
echo "  Then visit: https://localhost:8080"
echo
echo "Default admin password:"
echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
