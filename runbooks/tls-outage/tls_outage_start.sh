#!/usr/bin/env bash
set -euo pipefail

NS=${NS:-app}
CERT_DIR=${CERT_DIR:-$(pwd)/scripts/certs}

if [[ ! -f "$CERT_DIR/expired.crt" || ! -f "$CERT_DIR/expired.key" ]]; then
  echo "[!] Expired certificate not found. Run scripts/tls_prepare.sh first." >&2
  exit 1
fi

echo "[+] Simulating TLS outage by rotating to EXPIRED cert"
kubectl -n "$NS" create secret tls app-tls \
  --cert="$CERT_DIR/expired.crt" --key="$CERT_DIR/expired.key" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "[+] Restarting tls-proxy to pick up new cert"
kubectl -n "$NS" rollout restart deploy/tls-proxy
kubectl -n "$NS" rollout status deploy/tls-proxy --timeout=90s

echo "[+] TLS outage in effect. New TLS handshakes should fail due to expiration."

