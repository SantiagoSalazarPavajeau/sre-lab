#!/usr/bin/env bash
set -euo pipefail

# Simple end-to-end health checks for the local lab.
# Assumes quickstart has run and port-forwards are active.

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

KUBECONFIG_FILE="${KUBECONFIG:-${ROOT}/.kind-kubeconfig}"
export KUBECONFIG="$KUBECONFIG_FILE"

APP=${APP:-app}

pass() { echo "[ok] $*"; }
fail() { echo "[fail] $*" >&2; exit 1; }

echo "[smoke] Using kubeconfig: $KUBECONFIG_FILE"

# 1) Cluster API and nodes
kubectl get --raw=/readyz >/dev/null 2>&1 || fail "Kubernetes API not ready"
pass "Kubernetes API responsive"

kubectl wait --for=condition=Ready nodes --all --timeout=120s >/dev/null 2>&1 || fail "Nodes not Ready"
pass "Nodes Ready"

# 2) Namespaces present
kubectl get ns app monitoring >/dev/null 2>&1 || fail "Required namespaces missing (app/monitoring)"
pass "Namespaces present (app, monitoring)"

# 3) App deployment and service
kubectl -n app get deploy "$APP" >/dev/null 2>&1 || fail "Deployment '$APP' not found in namespace app"
kubectl -n app wait --for=condition=available "deploy/$APP" --timeout=120s >/dev/null 2>&1 || fail "Deployment '$APP' not available"
kubectl -n app get svc "$APP" >/dev/null 2>&1 || fail "Service '$APP' not found in namespace app"
pass "App deployment and service available"

# 4) App HTTP health + metrics (requires port-forward on 8080)
if curl -fsS http://localhost:8080/healthz >/dev/null 2>&1; then
  pass "App health endpoint reachable (localhost:8080/healthz)"
else
  fail "App health endpoint not reachable on localhost:8080 (is port-forward enabled?)"
fi

if curl -fsS http://localhost:8080/metrics | grep -Eq '(^|_)app_requests_total'; then
  pass "App metrics exposed"
else
  fail "App metrics missing on /metrics"
fi

# 5) Monitoring (Prometheus + Grafana) via port-forwards
if curl -fsS 'http://localhost:9090/api/v1/query?query=up' | grep -q '"status":"success"'; then
  pass "Prometheus API responding"
else
  fail "Prometheus API not responding on localhost:9090"
fi

if curl -Is http://localhost:3001/login | head -n1 | grep -Eq '^(HTTP/1.1 200|HTTP/1.1 302)'; then
  pass "Grafana login reachable"
else
  fail "Grafana not reachable on localhost:3001"
fi

# 6) LocalStack health (mock AWS)
if curl -fsS http://localhost:4566/_localstack/health | grep -Eq '"(running|ready)"'; then
  pass "LocalStack healthy"
else
  fail "LocalStack not healthy on localhost:4566"
fi

# 7) Terraform outputs (optional)
if command -v terraform >/dev/null 2>&1; then
  (cd infra/terraform && terraform output >/dev/null 2>&1) && pass "Terraform outputs accessible" || fail "Terraform outputs failed"
else
  echo "[info] Terraform not installed; skipping outputs check"
fi

echo "[smoke] All checks passed"
