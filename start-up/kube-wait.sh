#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
source "${ROOT}/start-up/lib/kubeconfig.sh"

if [ -z "${KUBECONFIG:-}" ] || [ ! -f "${KUBECONFIG:-/dev/null}" ]; then
  SRE_LAB_KUBECONFIG_SILENT=1 sre_lab_use_kubeconfig "${SRE_LAB_KUBECONFIG_VARIANT:-auto}"
else
  KUBECONFIG_FILE="${KUBECONFIG}"
  export KUBECONFIG
  export KUBECONFIG_FILE
fi

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
