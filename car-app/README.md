# Car App

Vehicle maintenance tracker (`ghcr.io/ramto/car-app`).

| | |
|---|---|
| URL | `https://car.lab.dobreff.net` |
| Data | PVC `car-app-data` → `/app/data` (SQLite) |
| Secrets | `car-app-secrets` (Vincario keys) |

## Prerequisites

1. Image built & available to the cluster (`ghcr.io/ramto/car-app:latest`).
2. Wildcard DNS `*.lab` → Tailscale IP (already used by other apps).
3. TLS secret in this namespace (re-run `../tls/issue-cert.sh` after first apply).

## Apply

```bash
kubectl apply -f namespace.yaml
kubectl apply -f secret.example.yaml   # edit keys first, or use create secret below
# Prefer:
kubectl -n car-app create secret generic car-app-secrets \
  --from-literal=VINCARIO_API_KEY='...' \
  --from-literal=VINCARIO_SECRET_KEY='...' \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f storage.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f ingress.yaml
```

If the GHCR package is private:

```bash
kubectl -n car-app create secret docker-registry ghcr-pull \
  --docker-server=ghcr.io \
  --docker-username=RAMTO \
  --docker-password=ghp_...
# then uncomment imagePullSecrets in deployment.yaml
```

## Seed existing SQLite (one-shot)

From the `car-app` repo (after the pod is Running):

```bash
sqlite3 seed/car-app.seed.db "PRAGMA wal_checkpoint(TRUNCATE);"
rm -f seed/car-app.seed.db-shm seed/car-app.seed.db-wal

POD=$(kubectl -n car-app get pod -l app=car-app -o jsonpath='{.items[0].metadata.name}')
# Stop writes briefly: copy while running is OK for a quiet SQLite file, then restart
kubectl -n car-app cp seed/car-app.seed.db "$POD:/app/data/car-app.db"
kubectl -n car-app rollout restart deploy/car-app
```

## Verify

```bash
kubectl -n car-app get pods,svc,ingress,pvc
curl -sS https://car.lab.dobreff.net/api/health
curl -sS https://car.lab.dobreff.net/api/state | head
```
