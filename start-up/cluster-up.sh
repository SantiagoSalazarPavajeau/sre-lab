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

echo "Cluster '${CLUSTER_NAME}' is ready."
