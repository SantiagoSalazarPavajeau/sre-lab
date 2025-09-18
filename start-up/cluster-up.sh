#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

KUBECONFIG_FILE="${ROOT}/.kind-kubeconfig"
export KUBECONFIG="${KUBECONFIG_FILE}"

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

# Ensure this container can reach the kind network (required when running inside Jenkins)
if docker network inspect kind >/dev/null 2>&1; then
  CONTAINER_ID=$(hostname)
  echo "Connecting ${CONTAINER_ID} to kind network"
  docker network connect kind "${CONTAINER_ID}" >/dev/null 2>&1 || true
fi

mkdir -p "$(dirname "${KUBECONFIG_FILE}")"
kind get kubeconfig --name "${CLUSTER_NAME}" --internal > "${KUBECONFIG_FILE}"

"${ROOT}/start-up/kube-wait.sh"
