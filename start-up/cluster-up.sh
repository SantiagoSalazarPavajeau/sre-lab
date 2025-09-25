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

# Decide whether to use internal or external kubeconfig
# - Internal is for when this script runs inside a container (e.g., Jenkins controller)
# - External is for when this runs on the host (macOS/Linux terminal)
is_container() {
  [ -f "/.dockerenv" ] && return 0
  grep -Eiq '/(docker|containerd|kubepods|lxc)/' /proc/1/cgroup 2>/dev/null && return 0
  return 1
}

normalize_bool() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|y|Y) echo true ;;
    0|false|FALSE|no|NO|n|N) echo false ;;
    *) echo "" ;;
  esac
}

USE_INTERNAL=""
if [ -n "${KIND_USE_INTERNAL:-}" ]; then
  USE_INTERNAL=$(normalize_bool "$KIND_USE_INTERNAL")
fi

if [ -z "$USE_INTERNAL" ]; then
  if is_container; then
    USE_INTERNAL=true
  else
    USE_INTERNAL=false
  fi
fi

# Ensure this container can reach the kind network (only relevant when inside a container)
if is_container && docker network inspect kind >/dev/null 2>&1; then
  CONTAINER_ID=$(hostname)
  echo "Connecting ${CONTAINER_ID} to kind network"
  docker network connect kind "${CONTAINER_ID}" >/dev/null 2>&1 || true
fi

mkdir -p "$(dirname "${KUBECONFIG_FILE}")"
if [ "$USE_INTERNAL" = true ]; then
  echo "Writing INTERNAL kubeconfig for cluster '${CLUSTER_NAME}' to ${KUBECONFIG_FILE}"
  kind get kubeconfig --name "${CLUSTER_NAME}" --internal > "${KUBECONFIG_FILE}"
else
  echo "Writing EXTERNAL kubeconfig for cluster '${CLUSTER_NAME}' to ${KUBECONFIG_FILE}"
  kind get kubeconfig --name "${CLUSTER_NAME}" > "${KUBECONFIG_FILE}"
fi

"${ROOT}/start-up/kube-wait.sh"
