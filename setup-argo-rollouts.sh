#!/usr/bin/env bash
set -euo pipefail

# Ajuste: se a porta 80 estiver em uso no seu Mac, substitua HOST_HTTP_PORT=8080 abaixo.
HOST_HTTP_PORT=80
HOST_HTTPS_PORT=443
CLUSTER_NAME="argo-canary"

command -v docker >/dev/null 2>&1 || { echo "ERRO: Docker não encontrado. Instale Docker Desktop ou colima+docker e rode novamente."; exit 1; }

if ! command -v kind >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    echo "Instalando kind, kubectl e dependências via brew..."
    brew install kind kubectl helm jq || true
  else
    echo "Instale kind, kubectl e helm manualmente (recomendo Homebrew)."; exit 1
  fi
fi

# cria config do kind com mapeamento de portas host->container (necessário para Ingress access via localhost)
cat > kind-config.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 80
    hostPort: ${HOST_HTTP_PORT}
    protocol: TCP
  - containerPort: 443
    hostPort: ${HOST_HTTPS_PORT}
    protocol: TCP
EOF

echo "Criando cluster kind chamado '${CLUSTER_NAME}' ..."
kind create cluster --name "${CLUSTER_NAME}" --config kind-config.yaml

echo "Aguardando nós prontos..."
kubectl wait --for=condition=Ready nodes --all --timeout=120s

# Instala ingress-nginx (manifest otimizado para kind)
echo "Instalando ingress-nginx..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

echo "Esperando ingress-nginx ficar Ready (namespace ingress-nginx)..."
kubectl -n ingress-nginx wait --for=condition=available deployment/ingress-nginx-controller --timeout=180s || kubectl -n ingress-nginx get pods

# Instala Argo Rollouts
echo "Instalando Argo Rollouts..."
kubectl create namespace argo-rollouts --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argo-rollouts -f https://raw.githubusercontent.com/argoproj/argo-rollouts/stable/manifests/install.yaml

echo "Aguardando pods do argo-rollouts..."
# fallback wait simples
sleep 8
kubectl -n argo-rollouts get pods || true

# Instala kubectl-argo-rollouts plugin (prefere brew)
if ! command -v kubectl-argo-rollouts >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    echo "Instalando kubectl-argo-rollouts via brew..."
    brew tap argoproj/tap || true
    brew install argoproj/tap/kubectl-argo-rollouts || true
  else
    echo "Fazendo download do binário kubectl-argo-rollouts..."
    curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-darwin-amd64
    chmod +x ./kubectl-argo-rollouts-darwin-amd64
    sudo mv ./kubectl-argo-rollouts-darwin-amd64 /usr/local/bin/kubectl-argo-rollouts
  fi
fi

echo "Setup inicial concluído."
echo "Verifique: kubectl get nodes ; kubectl -n ingress-nginx get pods ; kubectl -n argo-rollouts get pods"
echo "Se a porta ${HOST_HTTP_PORT} estiver ocupada, edite 'kind-config.yaml' e recrie o cluster com HOST_HTTP_PORT diferente."
