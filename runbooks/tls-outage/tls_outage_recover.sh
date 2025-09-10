#!/usr/bin/env bash
set -euo pipefail

NS=${NS:-app}
CERT_DIR=${CERT_DIR:-$(pwd)/scripts/certs}

if [[ ! -f "$CERT_DIR/valid.crt" || ! -f "$CERT_DIR/valid.key" ]]; then
  echo "[!] Valid certificate not found. Run scripts/tls_prepare.sh first." >&2
  exit 1
fi

echo "[+] Recovering TLS by rotating back to VALID cert"
kubectl -n "$NS" create secret tls app-tls \
  --cert="$CERT_DIR/valid.crt" --key="$CERT_DIR/valid.key" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "[+] Restarting tls-proxy to pick up new cert"
kubectl -n "$NS" rollout restart deploy/tls-proxy
kubectl -n "$NS" rollout status deploy/tls-proxy --timeout=90s

echo "[+] TLS recovered. Handshakes should succeed again."

