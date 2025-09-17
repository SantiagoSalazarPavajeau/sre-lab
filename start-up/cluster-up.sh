#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

if ! command -v kind >/dev/null 2>&1; then
  echo "kind is not installed. Install with: brew install kind" >&2
  exit 1
fi

CLUSTER_NAME=${KIND_CLUSTER_NAME:-sre-lab}

if ! kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
  echo "Creating kind cluster '${CLUSTER_NAME}' with config..."
  kind create cluster --name "${CLUSTER_NAME}" --config kind-config.yaml
else
  echo "Kind cluster '${CLUSTER_NAME}' already exists"
fi

echo "Waiting for Kubernetes API to respond..."
for attempt in $(seq 1 30); do
  if kubectl get nodes >/dev/null 2>&1; then
    break
  fi
  echo "  attempt ${attempt}/30: API not yet reachable; sleeping 5s"
  sleep 5
done

echo "Ensuring kind nodes are Ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=180s >/dev/null

echo "Cluster '${CLUSTER_NAME}' is ready."
