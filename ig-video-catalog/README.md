# ig-video-catalog (k3s)

Instagram reel downloader + local video catalog. Images: **`ghcr.io/ramto/ig-catalog`** and **`ghcr.io/ramto/ig-downloader`**.

| | |
|---|---|
| Catalog URL | `https://ig-catalog.lab.dobreff.net` |
| Downloader URL | `https://ig-downloader.lab.dobreff.net` (cookies — homelab / Tailscale only) |
| Videos | hostPath `/mnt/nvme/ig-videos/categories` (shared by both pods) |
| Thumbnails | PVC `ig-catalog-thumbs` |
| Secrets | `ig-cookies` (`cookies.txt` from the app repo) |

## Prerequisites

1. Images pushed to GHCR (`linux/arm64` for Pi).
2. Directory on the node: `sudo mkdir -p /mnt/nvme/ig-videos/categories` and seed once, e.g.  
   `rsync -avh …/ig-video-catalog/categories/ pi:/mnt/nvme/ig-videos/categories/`
3. Wildcard TLS secret in this namespace — re-run **`../tls/issue-cert.sh`** after first apply.

## Apply

```bash
kubectl apply -f namespace.yaml

kubectl -n ig-video-catalog create secret generic ig-cookies \
  --from-file=cookies.txt=/path/to/ig-video-catalog/downloader/cookies.txt \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f storage.yaml
kubectl apply -f catalog-deployment.yaml
kubectl apply -f catalog-service.yaml
kubectl apply -f catalog-ingress.yaml
kubectl apply -f downloader-deployment.yaml
kubectl apply -f downloader-service.yaml
kubectl apply -f downloader-ingress.yaml
```

Or after namespace + secret:

```bash
kubectl apply -f namespace.yaml
# ... secret as above ...
kubectl apply -f .
```

## Private GHCR

```bash
kubectl -n ig-video-catalog create secret docker-registry ghcr-pull \
  --docker-server=ghcr.io \
  --docker-username=ramto \
  --docker-password=YOUR_PAT
```

Uncomment `imagePullSecrets` in both Deployments.

## Smoke test

```bash
kubectl -n ig-video-catalog get pods,svc,ingress,pvc
# Catalog: categories load, play + seek, thumbnails (first hit may be slow — ffmpeg)
# Downloader: save one reel → .mp4 + .json on disk → refresh catalog
```

## Updates

Rebuild/push image → `kubectl -n ig-video-catalog rollout restart deploy/ig-catalog` (or `ig-downloader`).  
New files under `categories/` do **not** require redeploy.  
When Instagram expires the session: re-export cookies, recreate `ig-cookies`, restart `ig-downloader`.

## Local dev (Mac, Rancher Desktop)

Kubernetes manifests live here for the Pi homelab. For local `:local` images + Mac `hostPath`, build on the Mac and use port-forward / LoadBalancer — see **ig-video-catalog** app repo README (no in-repo k8s YAML).
