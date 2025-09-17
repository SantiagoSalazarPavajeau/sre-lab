# SRE Lab

## Overview

The SRE Lab is a personal reliability engineering playground — a safe environment to build, break, observe, and fix distributed systems without touching production or incurring cloud costs.

This lab simulates the day-to-day responsibilities of a Senior Site Reliability Engineer:

- Designing reliable infrastructure.
- Practicing incident response.
- Running disaster recovery drills.
- Building observability pipelines.
- Automating fixes to reduce operational toil.

It serves as both a training ground and a portfolio showcase of hands-on SRE expertise.

## Goals

- **Practice real outages:** simulate database crashes, cache hot keys, queue backlogs, and node failures.
- **Strengthen observability:** set up metrics, logging, and alerting for proactive detection.
- **Improve incident response:** measure MTTA/MTTR, write postmortems, and iterate.
- **Sharpen IaC skills:** manage infrastructure with Kubernetes, Terraform, and Helm locally.
- **Document & share:** every drill becomes a blog post, resume bullet, or GitHub artifact.

## Components

- **Local Kubernetes:** miniature city simulator to run apps and services.
- **AWS Emulators:** LocalStack, MinIO, and OpenSearch to mimic S3, queues, and logging.
- **Databases & Messaging:** PostgreSQL, Redis, and Redpanda/Kafka for realistic data patterns.
- **Observability Stack:** Prometheus, Grafana, Loki, and Alertmanager to monitor health.
- **Chaos Engineering Tools:** Chaos Mesh or Litmus to inject failures and stress test reliability.
- **CI/CD Workflow:** local pipelines (via GitOps or simple scripts) to practice safe deployments.

## Mock Apps (facebook/netflix/slack)

This lab now supports multiple simple mock apps that all expose standard endpoints and Prometheus metrics. Each app is independently deployable so you can spin up exactly what a lab needs.

- Endpoints: `GET /` (hello), `GET /healthz`, `GET /readyz`, `GET /metrics`
- Failure toggles (via env): `FAILURE_MODE` (none|error|latency|crash), `FAILURE_RATE` (0..1), `LATENCY_MS` (int)

### Decoupled Deployments

You can now deploy the cluster, infra, monitoring, CI/CD, and apps independently.

- Cluster only: `start-up/cluster-up.sh`
- Infra (namespaces): `start-up/deploy-infra.sh`
- Monitoring (Prometheus, Grafana, Alertmanager, exporters): `start-up/deploy-monitoring.sh`
- CI/CD (installs Argo CD, applies CI/CD manifests): `start-up/deploy-cicd.sh`
- App: `APP=facebook start-up/deploy-app.sh`

Monitoring discovers app services dynamically via Kubernetes service discovery (no hardcoded targets), so it’s safe to deploy monitoring without any apps.

### Deploy locally with kind

- Default app (quickstart):
  - `start-up/quickstart.sh`

- Specific app (quickstart):
  - `APP=facebook start-up/quickstart.sh`
  - `APP=netflix start-up/quickstart.sh`
  - `APP=slack start-up/quickstart.sh`

- With port-forwards (Prometheus 9090, Grafana 3000, selected app 8080):
  - `PORT_FORWARD=1 APP=facebook start-up/quickstart.sh`

The script builds `src/services/$APP`, tags it as `sre-lab-$APP:latest`, loads it into kind, applies `k8s/` and `k8s/apps/$APP`. For more granular control, use the decoupled scripts above.

### Tear Down

- App only:
  - `APP=facebook start-up/destroy-app.sh`
- Monitoring only:
  - `start-up/destroy-monitoring.sh`
- CI/CD only (and optionally Argo CD namespace):
  - `start-up/destroy-cicd.sh`
  - `DELETE_ARGOCD_NAMESPACE=1 start-up/destroy-cicd.sh`
- Infra (namespaces; deletes contained resources):
  - `start-up/destroy-infra.sh`
- Everything (cluster):
  - `start-up/kind-down.sh`

### Deploy via kubectl

If your cluster is already up:

- `kubectl apply -f k8s/apps/facebook`
- `kubectl apply -f k8s/apps/netflix`
- `kubectl apply -f k8s/apps/slack`

## Mock AWS Infrastructure (LocalStack + Terraform)

- Start the LocalStack emulator with `start-up/localstack-up.sh` (uses `infra/localstack/docker-compose.yml`).
- Provision the mock VPC, IAM, and registries with Terraform from `infra/terraform/`:
  - `terraform init`
  - `terraform workspace select localstack || terraform workspace new localstack`
  - `terraform apply -auto-approve -var-file=environments/localstack.tfvars`
- Outputs advertise the VPC, subnet, and IAM details a real EKS control plane would expect. Use them to wire additional automation or document lab assumptions.
- Tear everything down via `start-up/localstack-down.sh -v` when finished.
- All Kubernetes scripts produce a dedicated kubeconfig at `.kind-kubeconfig` and export it automatically, so Jenkins and local workflows share a consistent API endpoint even when kind runs inside a container.

### Jenkins controller (local Docker)

- Bring up Jenkins with all required tooling via `docker compose -f infra/jenkins/docker-compose.yml up -d --build`. Jenkins inherits your `~/.ssh` directory (mounted to `/var/jenkins_home/.ssh`), so ensure `github.com` is in `known_hosts` first (`ssh-keyscan github.com >> ~/.ssh/known_hosts`). The entrypoint automatically matches the container `docker` group to the socket (`/var/run/docker.sock` by default). For Colima use `docker --context colima compose` if your default context is elsewhere.
- The container mounts the repo at `/workspace`, binds the Docker socket, and includes `kind`, `kubectl`, `terraform`, and `yq`, so pipelines can run the same scripts used locally.
- Shut it down with `docker compose -f infra/jenkins/docker-compose.yml down`; state persists in the `jenkins_home` volume.

### Jenkins + Terraform workflow

- Pipeline controls:
  - `BOOTSTRAP_KIND` – run `start-up/cluster-up.sh` and optionally seed namespaces/components.
  - `DEPLOY_INFRA`, `DEPLOY_MONITORING`, `DEPLOY_CICD` – toggle which cluster add-ons apply during bootstrapping.
  - `TF_ENV` – selects the Terraform workspace and matching `environments/<env>.tfvars` file (default `localstack`).
  - `TF_ACTION` – choose between `plan` and `apply` for the infrastructure stage.
  - `SKIP_TERRAFORM` – bypass mock AWS provisioning (useful for app-only builds).
- kubeconfig for the kind cluster is written to `.kind-kubeconfig`; all `start-up/*.sh` helpers export this path so subsequent `kubectl` commands (including Jenkins stages) hit the correct API endpoint.
- The pipeline stages run in this order:
  1. Bootstrap kind (if enabled).
  2. Start LocalStack, run Terraform plan/apply, capture outputs, tear LocalStack down.
  3. Build, push, and roll out the selected app, then handle TLS simulations if requested.

### Failure injection examples

All apps support simple, controlled failures through environment variables on their Deployment:

- Return 500s 50% of the time:
  - `kubectl -n app set env deploy/facebook FAILURE_MODE=error FAILURE_RATE=0.5`

- Add 250ms latency 30% of the time:
  - `kubectl -n app set env deploy/netflix FAILURE_MODE=latency FAILURE_RATE=0.3 LATENCY_MS=250`

- Crash immediately on next request (pod restarts due to liveness):
  - `kubectl -n app set env deploy/slack FAILURE_MODE=crash`

- Reset to healthy:
  - `kubectl -n app set env deploy/facebook FAILURE_MODE=none FAILURE_RATE=0 LATENCY_MS=0`

Prometheus scrapes all app services at `:8080/metrics` (see `k8s/monitoring/prometheus-config.yaml`). Grafana can be pointed at Prometheus to visualize `app_requests_total`, `app_request_errors_total`, and `app_request_duration_seconds` per app.

### Jenkins (optional)

The pipeline accepts a parameter `APP_NAME` with choices `app`, `facebook`, `netflix`, `slack` and builds `./src/services/${APP_NAME}`. It updates the matching manifest under `k8s/app/` (for `app`) or `k8s/apps/${APP_NAME}/` and pushes the image tag into the manifest.

## Daily Flow

1. **Start the lab:** spin up local Kubernetes + supporting services.
2. **Deploy an app:** ship a simple service via local CI/CD.
3. **Observe:** confirm dashboards and alerts are working.
4. **Break something:** inject a failure (e.g., crash loop, database outage).
5. **Respond & recover:** use runbooks, alerts, and automation to resolve.
6. **Reflect:** record MTTR, write a postmortem, and design a permanent fix.
