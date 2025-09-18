#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
KUBECONFIG_FILE="${KUBECONFIG:-${ROOT}/.kind-kubeconfig}"
export KUBECONFIG="${KUBECONFIG_FILE}"

MAX_ATTEMPTS=${MAX_KUBE_WAIT_ATTEMPTS:-30}
SLEEP_SECONDS=${KUBE_WAIT_SLEEP_SECONDS:-5}

# Wait for API server to respond
for attempt in $(seq 1 "${MAX_ATTEMPTS}"); do
  if kubectl get --raw=/healthz >/dev/null 2>&1; then
    echo "Kubernetes API is responsive"
    break
  fi
  echo "Waiting for API server (${attempt}/${MAX_ATTEMPTS})"
  sleep "${SLEEP_SECONDS}"
done

if ! kubectl get --raw=/healthz >/dev/null 2>&1; then
  echo "API server did not become ready after $((MAX_ATTEMPTS * SLEEP_SECONDS))s" >&2
  exit 1
fi

# Ensure nodes are Ready
if ! kubectl wait --for=condition=Ready nodes --all --timeout=180s; then
  echo "Nodes failed to reach Ready state" >&2
  exit 1
fi

echo "Cluster is ready for kubectl operations"
