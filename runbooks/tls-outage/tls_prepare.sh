#!/usr/bin/env bash
set -euo pipefail

NS=${NS:-app}
CERT_DIR=${CERT_DIR:-$(pwd)/scripts/certs}
COMMON_NAME=${COMMON_NAME:-app.local}

mkdir -p "$CERT_DIR"

echo "[+] Ensuring namespace '$NS' exists"
kubectl get ns "$NS" >/dev/null 2>&1 || kubectl create ns "$NS"

echo "[+] Generating valid self-signed certificate for CN=$COMMON_NAME"
openssl req -x509 -nodes -newkey rsa:2048 \
  -keyout "$CERT_DIR/valid.key" \
  -out "$CERT_DIR/valid.crt" \
  -subj "/CN=$COMMON_NAME" -days 365 >/dev/null 2>&1

echo "[+] Generating expired self-signed certificate for CN=$COMMON_NAME"
# Using -days 0 yields a certificate that expires immediately (Not After == Not Before)
openssl req -x509 -nodes -newkey rsa:2048 \
  -keyout "$CERT_DIR/expired.key" \
  -out "$CERT_DIR/expired.crt" \
  -subj "/CN=$COMMON_NAME" -days 0 >/dev/null 2>&1 || true

echo "[+] Creating/Updating TLS secret 'app-tls' with VALID cert"
kubectl -n "$NS" create secret tls app-tls \
  --cert="$CERT_DIR/valid.crt" --key="$CERT_DIR/valid.key" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "[+] Applying TLS proxy manifests"
kubectl apply -f k8s/app/tls-proxy.yaml

echo "[+] Waiting for tls-proxy rollout"
kubectl -n "$NS" rollout status deploy/tls-proxy --timeout=90s

echo "[+] Done. Access via NodePort 30443 (kind nodes) or port-forward:"
echo "    kubectl -n $NS port-forward svc/tls-proxy 8443:443"
