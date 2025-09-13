#!/usr/bin/env bash
set -euo pipefail

NS=default    # usamos default para simplificar; mude se quiser
echo "Criando manifests para rollouts-demo (v1)..."

cat > services.yaml <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: rollouts-demo-stable
spec:
  selector:
    app: rollouts-demo
  ports:
  - port: 80
    targetPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: rollouts-demo-canary
spec:
  selector:
    app: rollouts-demo
  ports:
  - port: 80
    targetPort: 8080
YAML

cat > rollout.yaml <<'YAML'
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
        - -text=version:v1
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

cat > ingress.yaml <<'YAML'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: rollouts-demo-stable
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  ingressClassName: nginx
  rules:
  - host: rollouts-demo.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: rollouts-demo-stable
            port:
              number: 80
YAML

echo "Aplicando Services, Rollout e Ingress..."
kubectl apply -f services.yaml
kubectl apply -f rollout.yaml
kubectl apply -f ingress.yaml

echo "Aguardando rollout criado..."
kubectl argo rollouts get rollout rollouts-demo || kubectl get rollouts

echo "OK. Teste rápido (antes do upgrade):"
echo "curl -H 'Host: rollouts-demo.local' http://localhost/" 
echo "Faça algumas requisições para ver 'version:v1'"
