# yt-transcribe (k3s)

Deploys **`ghcr.io/ramto/yt-transcript:latest`** (FastAPI + static UI). Use **one replica** — prepared downloads are stored in process memory only.

## Apply

```bash
kubectl apply -f namespace.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f ingress.yaml
```

## URL

Ingress host: **yt-transcribe.lab.dobreff.net** (edit `ingress.yaml` if you use another domain). Covered by the wildcard cert `*.lab.dobreff.net`. After creating this namespace, re-run **`../tls/issue-cert.sh`** so `lab-dobreff-net-tls` is copied into `yt-transcribe` (or copy the secret manually).

## Private image

If the GHCR package is private, create a pull secret and uncomment `imagePullSecrets` in `deployment.yaml`:

```bash
kubectl create secret docker-registry ghcr-pull \
  --namespace yt-transcribe \
  --docker-server=ghcr.io \
  --docker-username=YOUR_GH_USER \
  --docker-password=YOUR_PAT
```
