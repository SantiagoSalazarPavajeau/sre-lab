#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

echo "Deleting infra namespaces (monitoring, app, cicd)..."
kubectl delete -f k8s/infra/namespace.yaml --ignore-not-found

echo "Infra teardown complete."
