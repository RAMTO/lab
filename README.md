# Lab

## Namespace

Create namespace yaml file

```
kubectl create ns linkding --dry--run=client -o yaml > namespace.yaml
```

Apply namespace yaml file

```
kubectl apply -f namespace.yaml
```

Activate new namespace

```
kubectl set-context --current --namespace=linkding
```

## Deployment

Create deployment yaml file

```
kubectl create deploy linkding --dry-run=client -o yaml > deployment.yaml
```

Edit the image in the deployment file with

```
ghcr.io/sissbruecker/linkding:1.46.2-plus-alpine
```

Apply deployment yaml file

```
kubectl apply -f deployment.yaml
```



