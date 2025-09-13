#!/usr/bin/env bash
set -euo pipefail
CLUSTER_NAME="argo-canary"
echo "Deletando cluster kind ${CLUSTER_NAME}..."
kind delete cluster --name "${CLUSTER_NAME}" || true
echo "Removendo arquivos temporários..."
rm -f kind-config.yaml services.yaml rollout.yaml ingress.yaml rollout-v2.yaml
echo "Feito."
