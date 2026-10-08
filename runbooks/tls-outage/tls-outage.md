# TLS outage drill

The nginx proxy terminates HTTPS and forwards requests to the app. Its certificate
and key come from the `app-tls` Secret in namespace `app`.

## Prepare

Use a running lab cluster with the app deployed and kubectl pointed at the lab.
From the repository root:

```bash
bash runbooks/tls-outage/tls_prepare.sh
kubectl -n app port-forward svc/tls-proxy 8443:443
```

Preparation generates both certificate fixtures, installs the valid one, applies
the proxy manifests, and restarts the proxy to load it. It changes the live Secret;
do not run preparation during an incident unless you intend to recover it.
The proxy manifest uses namespace `app`.

To generate files only, without changing Kubernetes:

```bash
bash runbooks/tls-outage/tls_generate.sh
```

Fixtures default to `scripts/certs/` under the repository root, regardless of your
working directory. Override with `CERT_DIR`; `COMMON_NAME` defaults to `app.local`.
Private keys are generated with restrictive permissions and ignored by Git.
Generation uses `openssl ca` with explicit January 2025 dates for the expired
fixture, compatible with LibreSSL 3.3.6. Errors are not suppressed.

## Establish a baseline

```bash
curl -vk https://localhost:8443/
openssl s_client -connect localhost:8443 -servername app.local </dev/null 2>/dev/null |
  openssl x509 -noout -dates -subject
```

Expect an application response and a future `notAfter` date. `curl -k` skips
certificate verification: it checks connectivity, not certificate validity.

In Prometheus, query:

```promql
probe_ssl_earliest_cert_expiry{job="blackbox"} - time()
```

A positive value means seconds remaining until expiry. The repository's Blackbox
configuration uses `insecure_skip_verify: true`, so `probe_success` can stay 1 even
with an expired certificate. Use the expiry metric and TLS alerts for this drill.

## Inject and detect

```bash
date -u
bash runbooks/tls-outage/tls_outage_start.sh
```

The script checks that the certificate parses and is expired before updating the
Secret, then restarts nginx to load it. Kubernetes validates the certificate/key
pair during the local `create secret tls --dry-run=client` step.

The expiry query should turn negative after a scrape. `TLSCertificateExpired`
becomes Pending, then Firing after one minute of continuous expiry.
`TLSCertificateExpiringSoon` covers only certificates still valid with fewer than
14 days remaining; it has a five-minute hold. Expired certificates do not match it.

A rollout may close an existing port-forward. Restart it before further curl or
openssl checks. Clients that validate expiry reject the expired certificate;
`curl -k` intentionally bypasses that rejection. These self-signed fixtures also
require explicit client trust, so an ordinary curl failure alone does not isolate
expiry as the cause.

## Recover and verify

```bash
bash runbooks/tls-outage/tls_outage_recover.sh
date -u
```

Recovery verifies the valid self-signed fixture before updating the Secret and
restarting nginx. Confirm the expiry query is positive and both alerts are
Inactive after the next scrape and rule evaluation. Record injection, detection,
and recovery timestamps; do not infer incident duration from the rollout alone.

## Load changed alert rules

Repository edits do not update the running cluster automatically:

```bash
kubectl apply -f k8s/monitoring/prometheus-config.yaml
kubectl -n monitoring rollout restart deployment/prometheus
kubectl -n monitoring rollout status deployment/prometheus --timeout=90s
```

Restart the Prometheus port-forward if its pod was replaced. The expired and
expiring-soon expressions preserve the expiry timestamp for alert annotations.

## Troubleshoot startup

```bash
kubectl -n app describe pod -l app=tls-proxy
kubectl -n app get secret app-tls
kubectl -n app logs deploy/tls-proxy -c nginx --tail=200
```

A missing required Secret prevents container startup. Updating mounted files alone
does not reload nginx's in-memory certificate; these scripts use a rollout restart.
