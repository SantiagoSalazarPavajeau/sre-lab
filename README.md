
# SRE Lab

Build a sandbox of mock production systems to rehearse SRE playbooks end to end.

## Overview

- **System design simulations** bring "full blown" recreations of flagship products—Facebook-style social networking, Slack-like collaboration, Dropbox-esque storage, Netflix-grade streaming, and more—by wiring realistic request flows, background jobs, and dependencies that echo their real-world counterparts. Each mock brand shares a common operational footprint so you can rehearse blueprints from traffic ingress to data persistence without touching the real services.
- **Chaos engineering & failure injection** is the centerpiece: toggle crash, latency, or error modes (with probabilities and delay budgets) entirely through environment variables to mimic brownouts, partial 500s, or hard crashes. TLS outage drills rotate valid and expired certificates to stress-test transport security response.
- **Infrastructure-as-code & automation** cover the lifecycle. Terraform modules target LocalStack to emulate AWS primitives, while quickstart and teardown scripts spin clusters up or down in minutes. A Jenkins pipeline orchestrates app builds, Terraform applies, Kubernetes rollouts, and TLS simulations with a single push-button flow.
- **Observability & runbooks** ship ready-made. Prometheus, Alertmanager, Grafana, cAdvisor, and the Blackbox Exporter auto-discover every mock workload via labels. Scenario guides expand the practice surface with API Gateway outage drills, JWT debugging, canary rollouts, and cost anomaly hunts.

## Quickstart

- Default app: `start-up/quickstart.sh`
- Specific app: `APP=facebook start-up/quickstart.sh`

## Teardown

- App: `APP=facebook start-up/destroy-app.sh`
- Cluster: `start-up/kind-down.sh`


## Jenkins (local Docker)

- Start: `docker compose -f infra/jenkins/docker-compose.yml up -d --build`
- Stop: `docker compose -f infra/jenkins/docker-compose.yml down`

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
