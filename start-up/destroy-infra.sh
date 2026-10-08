#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

source "${ROOT}/start-up/lib/kubeconfig.sh"
sre_lab_use_kubeconfig "${SRE_LAB_KUBECONFIG_VARIANT:-auto}"

echo "Deleting infra namespaces (monitoring, app)..."
kubectl delete -f k8s/infra/namespace.yaml --ignore-not-found

echo "Infra teardown complete."
