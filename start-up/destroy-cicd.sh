#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

echo "Deleting local CI/CD manifests (namespace: cicd)..."
kubectl delete -f k8s/cicd/ --ignore-not-found

if [ "${DELETE_ARGOCD_NAMESPACE:-0}" = "1" ]; then
  echo "Deleting Argo CD namespace 'argocd' (installed from upstream manifests)..."
  kubectl delete namespace argocd --ignore-not-found
fi

echo "CI/CD teardown complete."
