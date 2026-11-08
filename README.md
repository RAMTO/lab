# Lab (k3s + Tailscale)

Private homelab on Tailscale. Apps are exposed via Traefik Ingress on `*.lab.dobreff.net`.

![Homepage dashboard preview](assets/preview.png)

| Host | App |
|---|---|
| `https://lab.dobreff.net` | Homepage |
| `https://linkding.lab.dobreff.net` | Linkding |
| `https://car.lab.dobreff.net` | Car App |
| `https://git.lab.dobreff.net` | Forgejo |
| `https://yt-transcribe.lab.dobreff.net` | YouTube transcript → Markdown |
| `https://ig-catalog.lab.dobreff.net` | Instagram video catalog (player) |
| `https://ig-downloader.lab.dobreff.net` | Reel downloader (homelab only) |

## Layout

```
lab/
  homepage/     # dashboard
  linkding/     # bookmarks
  car-app/      # vehicle maintenance tracker
  forgejo/      # Git hosting
  yt-transcribe/  # YouTube transcript tool
  ig-video-catalog/  # IG catalog + downloader (see README)
  tls/          # wildcard cert via Let's Encrypt DNS-01 (Netlify)
```

## DNS (Netlify)

| Type | Name | Value |
|---|---|---|
| A | `lab` | Tailscale IP (`100.x…`) |
| A | `*.lab` | same |

(`car.lab` is covered by `*.lab`.)

## TLS

```bash
export NETLIFY_TOKEN='...'
export ACME_EMAIL='you@dobreff.net'
./tls/issue-cert.sh
```

Writes Secret `lab-dobreff-net-tls` into `homepage`, `linkding`, `car-app`, `forgejo`, `yt-transcribe`, and `ig-video-catalog` (TLS Secrets are namespaced). The cert is `*.lab.dobreff.net`, so new `*.lab.dobreff.net` hosts are covered — the script only needs to copy the secret into each app namespace.

## Apply

```bash
# Homepage
kubectl apply -f homepage/namespace.yaml
kubectl apply -f homepage/

# Linkding
kubectl apply -f linkding/namespace.yaml
kubectl apply -f linkding/

# Car App (see car-app/README.md for secrets + seed)
kubectl apply -f car-app/namespace.yaml
kubectl apply -f car-app/

# Forgejo (see forgejo/README.md)
kubectl apply -f forgejo/namespace.yaml
kubectl apply -f forgejo/

# yt-transcribe
kubectl apply -f yt-transcribe/namespace.yaml
kubectl apply -f yt-transcribe/

# ig-video-catalog (see ig-video-catalog/README.md for cookies secret + NVMe path)
kubectl apply -f ig-video-catalog/namespace.yaml
kubectl apply -f ig-video-catalog/

# After ConfigMap changes, restart Homepage (subPath mounts do not hot-reload)
kubectl rollout restart deploy/homepage -n homepage
```

## Notes

- One hostname per app (subdomain under `lab.dobreff.net`). Do not list the same app in both Homepage `services.yaml` and Ingress `gethomepage.dev/*` annotations.
- Pin image tags in production instead of `:latest`.
- Kubernetes CPU/mem widgets need metrics-server.
