#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

APP=${APP:-app}

echo "Deleting app '${APP}' manifests..."
if [ -d "k8s/apps/${APP}" ]; then
  kubectl delete -f "k8s/apps/${APP}" --ignore-not-found
else
  kubectl delete -f k8s/app/ --ignore-not-found
fi

# Stop app port-forward if running
if [ -f ".scripts/pf_${APP}.pid" ]; then
  pid=$(cat ".scripts/pf_${APP}.pid")
  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid" || true
  fi
  rm -f ".scripts/pf_${APP}.pid"
fi

echo "App '${APP}' teardown complete."
