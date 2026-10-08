
# SRE Lab

Build sample apps and experiment with monitoring and failure scenarios.

## Quickstart

- Default app: `start-up/quickstart.sh`
- Specific app: `APP=facebook start-up/quickstart.sh`

## Teardown

- App: `APP=facebook start-up/destroy-app.sh`
- Cluster: `start-up/kind-down.sh`


## Jenkins (local Docker)

- Start: `docker compose -f infra/jenkins/docker-compose.yml up -d --build`
- Stop: `docker compose -f infra/jenkins/docker-compose.yml down`

## Kubernetes access

Startup helpers maintain `.kind-kubeconfig-host` for local shells and
`.kind-kubeconfig-internal` for containers. The `.kind-kubeconfig` symlink
selects the current environment. Override selection with
`SRE_LAB_KUBECONFIG_VARIANT=host|internal`.

## Failure Injection

All apps accept failure modes via Deployment env vars:

- Return 500s 50% of the time:
  - `kubectl -n app set env deploy/facebook FAILURE_MODE=error FAILURE_RATE=0.5`

- Add 250ms latency 30% of the time:
  - `kubectl -n app set env deploy/netflix FAILURE_MODE=latency FAILURE_RATE=0.3 LATENCY_MS=250`

- Crash immediately on next request:
  - `kubectl -n app set env deploy/slack FAILURE_MODE=crash`

- Reset:
  - `kubectl -n app set env deploy/facebook FAILURE_MODE=none FAILURE_RATE=0 LATENCY_MS=0`

Prometheus scrapes `:8080/metrics` (see `k8s/monitoring/prometheus-config.yaml`). Point Grafana at Prometheus to chart `app_requests_total`, `app_request_errors_total`, and `app_request_duration_seconds`.
