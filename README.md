# canary

## Checks rápidos:

- Tenha Docker rodando (Docker Desktop / colima + docker).

- Recomendo ter Homebrew instalado (os scripts usam brew quando possível).

- Se a porta 80 já estiver em uso, altere para 8080.

## Como usar:

```
chmod +x setup-argo-rollouts.sh deploy-meuapp.sh test-canary.sh cleanup.sh
```

```
./setup-argo-rollouts.sh      # cria cluster, instala ingress-nginx e Argo Rollouts + plugin
./deploy-meuapp.sh           # aplica Rollout + Services + Ingress (versão v1)
./test-canary.sh             # atualiza para v2 e coleta distribuição de tráfego
```

```
./cleanup.sh                 # opcional: deleta cluster kind
```