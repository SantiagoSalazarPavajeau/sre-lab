#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

echo "Applying infra namespace and base resources..."
kubectl apply -f k8s/infra/namespace.yaml
echo "Infra applied."
