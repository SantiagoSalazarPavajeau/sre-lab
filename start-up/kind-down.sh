#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

CLUSTER_NAME=${KIND_CLUSTER_NAME:-sre-lab}

# Stop port-forwards if they exist
if [ -d .scripts ]; then
  echo "Stopping port-forwards..."
  for pid_file in .scripts/pf_*.pid; do
    if [ -f "$pid_file" ]; then
      pid=$(cat "$pid_file")
      if kill -0 "$pid" 2>/dev/null; then
        kill "$pid"
      fi
      rm "$pid_file"
    fi
  done
  rmdir .scripts 2>/dev/null || true
fi

# Delete the kind cluster
if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
  echo "Deleting kind cluster '${CLUSTER_NAME}'..."
  kind delete cluster --name "${CLUSTER_NAME}"
else
  echo "Kind cluster '${CLUSTER_NAME}' does not exist"
fi

echo "Done."
