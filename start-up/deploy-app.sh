#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

APP=${APP:-app}
CLUSTER_NAME=${KIND_CLUSTER_NAME:-sre-lab}

echo "Building app image for '$APP'..."
docker build -t "sre-lab-${APP}:latest" "./src/services/${APP}"

echo "Loading image into kind cluster (${CLUSTER_NAME})..."
kind load docker-image --name "${CLUSTER_NAME}" "sre-lab-${APP}:latest"

if [ -d "k8s/apps/${APP}" ]; then
  echo "Applying app manifests for '${APP}'..."
  kubectl apply -f "k8s/apps/${APP}"
else
  echo "Applying default app manifests..."
  kubectl apply -f k8s/app/
fi

echo "Waiting for '${APP}' deployment to be available (120s timeout)..."
kubectl -n app wait --for=condition=available "deploy/${APP}" --timeout=120s || true

if [ "${PORT_FORWARD:-0}" = "1" ]; then
  mkdir -p .scripts
  echo "Starting port-forward for ${APP} service on 8080..."
  kubectl -n app port-forward "svc/${APP}" 8080:8080 >/dev/null 2>&1 &
  echo $! > .scripts/pf_${APP}.pid
fi

echo "App '${APP}' deployed."
