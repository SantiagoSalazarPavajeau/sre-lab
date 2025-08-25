🔧 SRE Lab
Overview

The SRE Lab is a personal reliability engineering playground — a safe environment to build, break, observe, and fix distributed systems without touching production or incurring cloud costs.

This lab simulates the day-to-day responsibilities of a Senior Site Reliability Engineer:

Designing reliable infrastructure.

Practicing incident response.

Running disaster recovery drills.

Building observability pipelines.

Automating fixes to reduce operational toil.

It serves as both a training ground and a portfolio showcase of hands-on SRE expertise.

Goals

🚦 Practice real outages: simulate database crashes, cache hot keys, queue backlogs, and node failures.

🩺 Strengthen observability: set up metrics, logging, and alerting for proactive detection.

⚡ Improve incident response: measure MTTA/MTTR, write postmortems, and iterate.

🛠️ Sharpen IaC skills: manage infrastructure with Kubernetes, Terraform, and Helm locally.

📚 Document & share: every drill becomes a blog post, resume bullet, or GitHub artifact.

Components

Local Kubernetes: miniature city simulator to run apps and services.

AWS Emulators: LocalStack, MinIO, and OpenSearch to mimic S3, queues, and logging.

Databases & Messaging: PostgreSQL, Redis, and Redpanda/Kafka for realistic data patterns.

Observability Stack: Prometheus, Grafana, Loki, and Alertmanager to monitor health.

Chaos Engineering Tools: Chaos Mesh or Litmus to inject failures and stress test reliability.

CI/CD Workflow: local pipelines (via GitOps or simple scripts) to practice safe deployments.

Daily Flow

Start the lab → spin up local Kubernetes + supporting services.

Deploy an app → ship a simple service via local CI/CD.

Observe → confirm dashboards and alerts are working.

Break something → inject a failure (e.g., crash loop, database outage).

Respond & recover → use runbooks, alerts, and automation to resolve.

Reflect → record MTTR, write a postmortem, and design a permanent fix.