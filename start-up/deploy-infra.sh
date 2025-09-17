#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

KUBECONFIG_FILE="${ROOT}/.kind-kubeconfig"
export KUBECONFIG="${KUBECONFIG_FILE}"

echo "Applying infra namespace and base resources..."
# Ensure cluster is ready before applying manifests
"${ROOT}/start-up/kube-wait.sh"
kubectl apply -f k8s/infra/namespace.yaml
echo "Infra applied."
