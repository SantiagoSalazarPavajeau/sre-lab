#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

# Stop any backgrounded kubectl port-forwards saved by up.sh
if [ -d .scripts ]; then
  echo "[sre-lab] Stopping port-forward PIDs from .scripts/"
  for f in .scripts/*.pid; do
    [ -f "$f" ] || continue
    pid=$(cat "$f")
    if ps -p "$pid" >/dev/null 2>&1; then
      echo "killing pid $pid"
      kill "$pid" || true
    fi
    rm -f "$f"
  done
  rmdir .scripts 2>/dev/null || true
fi

# Also kill any kubectl port-forward processes as fallback
pgrep -a -f "kubectl .*port-forward" >/dev/null 2>&1 && {
  echo "[sre-lab] Killing any remaining kubectl port-forward processes"
  pkill -f "kubectl .*port-forward" || true
}

read -r -p "Delete the sre-lab namespace and all resources? [y/N]: " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
  echo "[sre-lab] Deleting namespace sre-lab..."
  kubectl delete namespace sre-lab --ignore-not-found
else
  echo "[sre-lab] Skipping namespace deletion."
fi

echo "[sre-lab] Done."
