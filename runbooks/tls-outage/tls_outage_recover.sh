#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
NS=${NS:-app}
CERT_DIR=${CERT_DIR:-$ROOT/scripts/certs}

if [[ ! -f "$CERT_DIR/valid.crt" || ! -f "$CERT_DIR/valid.key" ]]; then
  echo "[!] Valid certificate not found. Run bash runbooks/tls-outage/tls_generate.sh first." >&2
  exit 1
fi

# Parse first so malformed files cannot be mistaken for expired certificates.
openssl x509 -in "$CERT_DIR/valid.crt" -noout -dates
# These fixtures are self-signed; verification checks validity and signature.
openssl verify -CAfile "$CERT_DIR/valid.crt" "$CERT_DIR/valid.crt"

echo "[+] Recovering TLS by rotating back to VALID cert"
kubectl -n "$NS" create secret tls app-tls \
  --cert="$CERT_DIR/valid.crt" --key="$CERT_DIR/valid.key" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "[+] Restarting tls-proxy to pick up new cert"
kubectl -n "$NS" rollout restart deploy/tls-proxy
kubectl -n "$NS" rollout status deploy/tls-proxy --timeout=90s

echo "[+] TLS recovered. Valid certificate loaded. Verify the expiry metric and alert recovery."

