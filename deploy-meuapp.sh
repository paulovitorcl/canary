#!/usr/bin/env bash
set -euo pipefail

# Nome da app e namespace
APP_NAME="meuapp"
NAMESPACE="default"
ARGOCD_NAMESPACE="argocd"

# Aplica rollout e service/ingress já existentes
# echo "Aplicando Rollout e Service/Ingress..."
# kubectl apply -f rollout.yaml -n ${NAMESPACE}
# kubectl apply -f ingress.yaml -n ${NAMESPACE}

# echo "Esperando pods ficarem prontos..."
# kubectl -n ${NAMESPACE} wait --for=condition=Available rollout/${APP_NAME} --timeout=180s || kubectl -n ${NAMESPACE} get pods

# Cria Application no Argo CD para visualizar tudo
echo "Criando Application no Argo CD para visualizar a app..."
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${APP_NAME}
  namespace: ${ARGOCD_NAMESPACE}
spec:
  project: default
  source:
    repoURL: https://github.com/paulovitorcl/minha-app-canary.git
    targetRevision: HEAD
    path: .
  destination:
    server: https://kubernetes.default.svc
    namespace: ${NAMESPACE}
  syncPolicy:
    automated: {}
EOF

echo "Aplicação criada. Agora abra o Argo CD UI em https://localhost:8080"
echo "Login: admin / senha mostrada no setup"
