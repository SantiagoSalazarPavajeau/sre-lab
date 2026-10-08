#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

source "${ROOT}/start-up/lib/kubeconfig.sh"
sre_lab_use_kubeconfig "${SRE_LAB_KUBECONFIG_VARIANT:-auto}"

echo "Deleting monitoring stack (namespace: monitoring)..."
kubectl delete -f k8s/monitoring/ --ignore-not-found

echo "Monitoring teardown complete."
