#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

source "${ROOT}/start-up/lib/kubeconfig.sh"

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

# Decide whether to use internal or external kubeconfig
# - Internal is for when this script runs inside a container (e.g., Jenkins controller)
# - External is for when this runs on the host (macOS/Linux terminal)
is_container() {
  [ -f "/.dockerenv" ] && return 0
  grep -Eiq '/(docker|containerd|kubepods|lxc)/' /proc/1/cgroup 2>/dev/null && return 0
  return 1
}

# Ensure this container can reach the kind network (only relevant when inside a container)
if is_container && docker network inspect kind >/dev/null 2>&1; then
  CONTAINER_ID=$(hostname)
  echo "Connecting ${CONTAINER_ID} to kind network"
  docker network connect kind "${CONTAINER_ID}" >/dev/null 2>&1 || true
fi

# Refresh kubeconfig variants for both host shells and in-cluster/Jenkins usage
kind get kubeconfig --name "${CLUSTER_NAME}" > "${SRE_LAB_KUBECONFIG_HOST}"
kind get kubeconfig --name "${CLUSTER_NAME}" --internal > "${SRE_LAB_KUBECONFIG_INTERNAL}"

# Pick the appropriate kubeconfig for this environment (overridable via
# SRE_LAB_KUBECONFIG_VARIANT=host|internal).
sre_lab_use_kubeconfig "${SRE_LAB_KUBECONFIG_VARIANT:-auto}"

"${ROOT}/start-up/kube-wait.sh"
