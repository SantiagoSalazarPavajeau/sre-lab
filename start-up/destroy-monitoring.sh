#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

echo "Deleting monitoring stack (namespace: monitoring)..."
kubectl delete -f k8s/monitoring/ --ignore-not-found

echo "Monitoring teardown complete."
