#!/usr/bin/env bash
set -euo pipefail

# Installs Argo CD into the cluster using the upstream install manifest,
# then applies the Argo CD Application that points to this repo's k8s/ directory.
# Run from repo root: ./scripts/install-argocd.sh

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

echo "Installing Argo CD into cluster..."
kubectl create namespace argocd || true
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for Argo CD server to be ready..."
kubectl -n argocd wait --for=condition=available deploy/argocd-server --timeout=120s

# Apply Application manifest that instructs ArgoCD to deploy k8s/ from this repo
echo "Applying Argo CD Application (k8s/ in this repo)..."
kubectl apply -f k8s/argocd-application.yaml

echo "Argo CD installed. To access the UI:
  kubectl -n argocd port-forward svc/argocd-server 8080:443 &
  open https://localhost:8080

Default admin password:
  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
"
