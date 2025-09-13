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

# Instala Argo CD
echo "Instalando Argo CD..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Aguardando Argo CD iniciar..."
kubectl -n argocd wait --for=condition=available deployment/argocd-server --timeout=180s || kubectl -n argocd get pods

echo "Fazendo port-forward da UI do Argo CD (https://localhost:8080)"
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
sleep 5

echo "Senha inicial do Argo CD (usuário: admin):"
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 --decode && echo

echo "Setup concluído. Acesse https://localhost:8080 para ver o Argo CD UI."
echo "Use usuário 'admin' e a senha acima para login."
