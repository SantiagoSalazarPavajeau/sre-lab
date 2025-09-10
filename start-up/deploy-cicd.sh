#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

echo "Installing Argo CD (uses upstream manifests)..."
kubectl create namespace argocd || true
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for Argo CD server to be ready (180s timeout)..."
kubectl -n argocd wait --for=condition=available deploy/argocd-server --timeout=180s || true

echo "Applying local CI/CD manifests (Jenkins, ArgoCD Application)..."
kubectl apply -f k8s/cicd/

echo "CI/CD deployed."
