TLS Outage Simulation
=====================

Overview
--------

This lab introduces an HTTPS reverse proxy (NGINX) in front of the `app` service and simulates a TLS outage by rotating the proxy's certificate to an expired one. Recovery simply rotates the certificate back to a valid one.

What gets installed
-------------------

- `k8s/app/tls-proxy.yaml`: NGINX Deployment + Service in namespace `app` that terminates TLS and proxies to `app:8080`.
- Secret `app-tls`: Kubernetes TLS secret containing the current certificate and key used by the proxy.
- Certs are generated locally into `scripts/certs/`.

Prerequisites
-------------

- A running cluster with the lab namespaces applied (`k8s/infra/namespace.yaml`) and the app deployed (`k8s/app/app-deployment.yaml`).
- `kubectl` access to the cluster context.
- `openssl` available on your PATH.

Detailed Steps (No Scripts)
--------------------------

Environment variables (override as needed for cert paths and CN):

```
export CERT_DIR=${CERT_DIR:-$(pwd)/scripts/certs}
export COMMON_NAME=${COMMON_NAME:-app.local}
mkdir -p "$CERT_DIR"
```

1) Prepare certs, secret, and deploy the TLS proxy

- Ensure namespace exists:
  - `kubectl get ns app >/dev/null 2>&1 || kubectl create ns app`
- Generate a valid self-signed certificate:
  - `openssl req -x509 -nodes -newkey rsa:2048 -keyout "$CERT_DIR/valid.key" -out "$CERT_DIR/valid.crt" -subj "/CN=$COMMON_NAME" -days 365`
- Generate an expired self-signed certificate (expires immediately):
  - `openssl req -x509 -nodes -newkey rsa:2048 -keyout "$CERT_DIR/expired.key" -out "$CERT_DIR/expired.crt" -subj "/CN=$COMMON_NAME" -days 0 || true`
- Create or update the TLS secret with the VALID cert:
  - `kubectl -n app create secret tls app-tls --cert="$CERT_DIR/valid.crt" --key="$CERT_DIR/valid.key" --dry-run=client -o yaml | kubectl apply -f -`
- Apply the NGINX TLS proxy manifests:
  - `kubectl apply -f k8s/app/tls-proxy.yaml`
- Wait for rollout:
  - `kubectl -n app rollout status deploy/tls-proxy --timeout=90s`

2) Access and baseline validation

- Port-forward locally:
  - `kubectl -n app port-forward svc/tls-proxy 8443:443`
- Test success (expect HTTP 200 with self-signed warning):
  - `curl -vk https://localhost:8443/`
- Inspect certificate dates:
  - `openssl s_client -connect localhost:8443 -servername "$COMMON_NAME" </dev/null 2>/dev/null | openssl x509 -noout -dates -subject`

Simulate Outage (Rotate to Expired Cert)
----------------------------------------

- Replace secret with EXPIRED cert:
  - `kubectl -n app create secret tls app-tls --cert="$CERT_DIR/expired.crt" --key="$CERT_DIR/expired.key" --dry-run=client -o yaml | kubectl apply -f -`
- Restart proxy to pick up new secret:
  - `kubectl -n app rollout restart deploy/tls-proxy`
  - `kubectl -n app rollout status deploy/tls-proxy --timeout=90s`
- Validate failure:
  - `curl -vk https://localhost:8443/` (expect TLS failure like “certificate has expired”).
  - `openssl s_client -connect localhost:8443 -servername "$COMMON_NAME" </dev/null 2>/dev/null | openssl x509 -noout -dates -subject` (NotAfter should be in the past).

Recover (Rotate Back to Valid Cert)
-----------------------------------

- Restore secret with VALID cert:
  - `kubectl -n app create secret tls app-tls --cert="$CERT_DIR/valid.crt" --key="$CERT_DIR/valid.key" --dry-run=client -o yaml | kubectl apply -f -`
- Restart proxy and wait:
  - `kubectl -n app rollout restart deploy/tls-proxy`
  - `kubectl -n app rollout status deploy/tls-proxy --timeout=90s`
- Validate success:
  - `curl -vk https://localhost:8443/` (expect HTTP 200 with self-signed warning only).
  - `openssl s_client -connect localhost:8443 -servername "$COMMON_NAME" </dev/null 2>/dev/null | openssl x509 -noout -dates -subject` (NotAfter in the future).

Script Equivalents (Optional)
-----------------------------

- Prepare: `scripts/tls_prepare.sh`
- Outage: `scripts/tls_outage_start.sh`
- Recover: `scripts/tls_outage_recover.sh`

Notes
-----

- The cert Common Name defaults to `app.local`; since it's self-signed, clients will warn on trust, but expiration will deterministically fail during outage.
- The Service is `NodePort` on 30443. With kind, you can connect via any node IP; `port-forward` is simplest for local use.
 

Troubleshooting
---------------

- Verify secret exists and has data:
  - `kubectl -n app get secret app-tls -o yaml | head -n 30`
- Check NGINX proxy logs for reload errors:
  - `kubectl -n app logs deploy/tls-proxy -c nginx --tail=200`
- Confirm ConfigMap is mounted and using the expected server_name:
  - `kubectl -n app get cm tls-proxy-nginx-conf -o yaml`
- Ensure the app service resolves in-cluster:
  - `kubectl -n app run -it netshoot --rm --image nicolaka/netshoot -- curl -sS http://app.app.svc.cluster.local:8080/`

Alerting
--------

- Prometheus scrapes a Blackbox Exporter probe against `https://tls-proxy.app.svc.cluster.local:443` to expose `probe_ssl_earliest_cert_expiry`.
- Alerts defined in `k8s/monitoring/prometheus-config.yaml` (ConfigMap `prometheus-rules`):
  - `TLSCertificateExpired`: fires when `time() > probe_ssl_earliest_cert_expiry` for 1m.
  - `TLSCertificateExpiringSoon`: fires when expiry is within 14 days for 5m.
- Blackbox Exporter config allows self-signed certs (`insecure_skip_verify: true`) so expiry is still measured.
- Apply resources: `kubectl apply -f k8s/monitoring/blackbox-exporter.yaml && kubectl apply -f k8s/monitoring/prometheus-config.yaml && kubectl apply -f k8s/monitoring/prometheus-deployment.yaml`
