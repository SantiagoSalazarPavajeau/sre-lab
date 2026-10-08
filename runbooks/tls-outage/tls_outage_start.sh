#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
NS=${NS:-app}
CERT_DIR=${CERT_DIR:-$ROOT/scripts/certs}

if [[ ! -f "$CERT_DIR/expired.crt" || ! -f "$CERT_DIR/expired.key" ]]; then
  echo "[!] Expired certificate not found. Run bash runbooks/tls-outage/tls_generate.sh first." >&2
  exit 1
fi

# Parse first so malformed files cannot be mistaken for expired certificates.
openssl x509 -in "$CERT_DIR/expired.crt" -noout -dates
if openssl x509 -in "$CERT_DIR/expired.crt" -noout -checkend 0; then
  echo '[!] Refusing rotation: certificate is not expired.' >&2
  exit 1
fi

echo "[+] Simulating TLS outage by rotating to EXPIRED cert"
kubectl -n "$NS" create secret tls app-tls \
  --cert="$CERT_DIR/expired.crt" --key="$CERT_DIR/expired.key" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "[+] Restarting tls-proxy to pick up new cert"
kubectl -n "$NS" rollout restart deploy/tls-proxy
kubectl -n "$NS" rollout status deploy/tls-proxy --timeout=90s

echo "[+] TLS outage in effect. Clients checking expiry should reject the certificate; curl -k bypasses this check."

