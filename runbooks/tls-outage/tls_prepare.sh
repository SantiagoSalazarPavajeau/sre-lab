#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
NS=${NS:-app}
export CERT_DIR=${CERT_DIR:-$ROOT/scripts/certs}

bash "$ROOT/runbooks/tls-outage/tls_generate.sh"

echo "[+] Ensuring namespace '$NS' exists"
kubectl get ns "$NS" >/dev/null 2>&1 || kubectl create ns "$NS"

echo "[+] Creating/Updating TLS secret 'app-tls' with VALID cert"
kubectl -n "$NS" create secret tls app-tls \
  --cert="$CERT_DIR/valid.crt" --key="$CERT_DIR/valid.key" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "[+] Applying TLS proxy manifests"
kubectl apply -f "$ROOT/k8s/app/tls-proxy.yaml"

echo "[+] Restarting tls-proxy to load the certificate"
kubectl -n "$NS" rollout restart deploy/tls-proxy

echo "[+] Waiting for tls-proxy rollout"
kubectl -n "$NS" rollout status deploy/tls-proxy --timeout=90s

echo "[+] Done. Access via NodePort 30443 (kind nodes) or port-forward:"
echo "    kubectl -n $NS port-forward svc/tls-proxy 8443:443"
