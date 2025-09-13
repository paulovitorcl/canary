#!/usr/bin/env bash
set -euo pipefail

HOST="http://localhost"
HDR="rollouts-demo.local"

echo "Test inicial: coletando 10 requisições (v1 esperado)..."
for i in $(seq 1 10); do curl -s -H "Host: ${HDR}" "${HOST}/" || true; echo; done

echo
echo "Agora vamos atualizar o Rollout (mudar texto para version:v2) — isso inicia o canary."
cat > rollout-v2.yaml <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: rollouts-demo
spec:
  replicas: 5
  selector:
    matchLabels:
      app: rollouts-demo
  template:
    metadata:
      labels:
        app: rollouts-demo
    spec:
      containers:
      - name: http-echo
        image: hashicorp/http-echo:alpine
        args:
        - -listen=:8080
        - -text=version:v2
        ports:
        - containerPort: 8080
  strategy:
    canary:
      canaryService: rollouts-demo-canary
      stableService: rollouts-demo-stable
      trafficRouting:
        nginx:
          stableIngress: rollouts-demo-stable
      steps:
      - setWeight: 10
      - pause: {duration: 15s}
      - setWeight: 50
      - pause: {duration: 15s}
      - setWeight: 100
YAML

kubectl apply -f rollout-v2.yaml
echo "Rollout atualizado. Watch:"
kubectl argo rollouts get rollout rollouts-demo --watch &

# coletar distribuição por 60 segundos (ajuste se quiser)
echo "Aguardando 5s para estabilizar..."
sleep 5

echo "Coletando 200 requisições para mostrar a divisão de tráfego (v1/v2)..."
v1=0; v2=0; other=0
for i in $(seq 1 200); do
  out=$(curl -s -H "Host: ${HDR}" "${HOST}/" || true)
  if [[ "${out}" == *"version:v1"* ]]; then ((v1++));
  elif [[ "${out}" == *"version:v2"* ]]; then ((v2++));
  else ((other++));
  fi
done

echo "Resultado das 200 requisições:"
echo "v1: ${v1}"
echo "v2: ${v2}"
echo "other: ${other}"
echo
echo "Você também pode observar os Ingresses gerados:"
kubectl get ing -o wide
echo "E ver o canary ingress gerado pelo controller (nome parecido com rollouts-demo-rollouts-demo-stable-canary)."
