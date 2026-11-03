# Forgejo

Self-hosted Git (`codeberg.org/forgejo/forgejo`).

| | |
|---|---|
| URL | `https://git.lab.dobreff.net` |
| Data | PVC `forgejo-data` → `/data` (DB, repos, `app.ini`) |
| TLS | `lab-dobreff-net-tls` (wildcard `*.lab.dobreff.net`) |

## Prerequisites

1. DNS `*.lab` → Tailscale IP (`git.lab` is covered by the wildcard).
2. TLS secret in namespace `forgejo` — re-run `../tls/issue-cert.sh` after first namespace apply.
3. Pin or bump image tag in `deployment.yaml` when upgrading.

## Apply (prod k3s)

```bash
kubectl apply -f namespace.yaml
kubectl apply -f storage.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f ingress.yaml
```

First visit: complete the **install wizard** once. Data persists on the PVC across restarts.

## Verify

```bash
kubectl -n forgejo get pods,svc,ingress,pvc
curl -sS -o /dev/null -w '%{http_code}\n' https://git.lab.dobreff.net/api/healthz
```

## Local (Rancher Desktop)

Use **ClusterIP + Ingress** (manifests above), not LoadBalancer on port 3000 (conflicts with other svclb services).

Add to `/etc/hosts`:

```text
127.0.0.1  git.lab.dobreff.net
```

Open `http://git.lab.dobreff.net` (or HTTPS if you copied the TLS secret into `forgejo`).

## Notes

- **Git over SSH** is not exposed yet (would need a Service for container port 22 and `FORGEJO__server__SSH_PORT` / firewall). HTTPS clone works via Ingress.
- To grow disk: edit `storage.yaml` only if your StorageClass allows expansion; otherwise backup `/data` and recreate PVC.
