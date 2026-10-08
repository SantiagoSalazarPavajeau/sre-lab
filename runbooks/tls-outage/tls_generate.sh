#!/usr/bin/env bash
# Generate fixtures without changing Kubernetes resources.
set -euo pipefail
umask 077
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
CERT_DIR=${CERT_DIR:-$ROOT/scripts/certs}
COMMON_NAME=${COMMON_NAME:-app.local}
mkdir -p "$CERT_DIR"
CERT_DIR=$(cd "$CERT_DIR" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

touch "$work/index.txt"
echo 01 > "$work/serial"
cat > "$work/ca.cnf" <<CONFIG
[ca]
default_ca = lab
[lab]
database = $work/index.txt
serial = $work/serial
new_certs_dir = $work
default_md = sha256
policy = names
[names]
commonName = supplied
CONFIG

openssl req -x509 -nodes -newkey rsa:2048 \
  -keyout "$work/valid.key" -out "$work/valid.crt" \
  -subj "/CN=$COMMON_NAME" -days 365
openssl req -new -nodes -newkey rsa:2048 \
  -keyout "$work/expired.key" -out "$work/expired.csr" \
  -subj "/CN=$COMMON_NAME"
openssl ca -batch -selfsign -config "$work/ca.cnf" \
  -keyfile "$work/expired.key" -in "$work/expired.csr" \
  -out "$work/expired.crt" -notext \
  -startdate 250101000000Z -enddate 250102000000Z

openssl verify -CAfile "$work/valid.crt" "$work/valid.crt"
openssl x509 -in "$work/expired.crt" -noout -dates
if openssl x509 -in "$work/expired.crt" -noout -checkend 0; then
  echo '[!] Expected an expired certificate; check the system clock.' >&2
  exit 1
fi
for file in valid.crt valid.key expired.crt expired.key; do
  install -m 600 "$work/$file" "$CERT_DIR/$file"
done
echo "[+] Certificate fixtures saved to $CERT_DIR"
