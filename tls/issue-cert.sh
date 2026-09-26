#!/usr/bin/env bash
# Issue/renew wildcard TLS for lab.dobreff.net + *.lab.dobreff.net (Let's Encrypt DNS-01 / Netlify).
# Runs as a k3s Job — no Docker CLI required.
#
# Prereqs:
#   export NETLIFY_TOKEN='...'
#   export ACME_EMAIL='you@dobreff.net'
#   Netlify DNS: lab and *.lab → Tailscale IP
#
# Usage: ./issue-cert.sh
set -euo pipefail

DOMAIN="${DOMAIN:-lab.dobreff.net}"
WILDCARD="*.${DOMAIN}"
NAMESPACE="${NAMESPACE:-homepage}"
SECRET_NAME="${SECRET_NAME:-lab-dobreff-net-tls}"
CERT_BASENAME="${CERT_BASENAME:-lab.dobreff.net}"
EMAIL="${ACME_EMAIL:?set ACME_EMAIL}"
TOKEN="${NETLIFY_TOKEN:?set NETLIFY_TOKEN}"
JOB_NS="cert-manager"
JOB_NAME="lego-issue-lab-wildcard"
KUBECTL_IMAGE="${KUBECTL_IMAGE:-alpine/k8s:1.32.2}"

kubectl get ns "$JOB_NS" >/dev/null 2>&1 || kubectl create namespace "$JOB_NS"
kubectl get ns "$NAMESPACE" >/dev/null 2>&1 || kubectl create namespace "$NAMESPACE"
kubectl get ns linkding >/dev/null 2>&1 || kubectl create namespace linkding

kubectl -n "$JOB_NS" create secret generic netlify-api-token \
  --from-literal=token="$TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: lego-issuer
  namespace: ${JOB_NS}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: lego-issuer
  namespace: ${NAMESPACE}
rules:
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get", "create", "update", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: lego-issuer
  namespace: ${NAMESPACE}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: lego-issuer
subjects:
  - kind: ServiceAccount
    name: lego-issuer
    namespace: ${JOB_NS}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: lego-issuer
  namespace: linkding
rules:
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get", "create", "update", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: lego-issuer
  namespace: linkding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: lego-issuer
subjects:
  - kind: ServiceAccount
    name: lego-issuer
    namespace: ${JOB_NS}
EOF

kubectl -n "$JOB_NS" delete job "$JOB_NAME" --ignore-not-found

kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: ${JOB_NAME}
  namespace: ${JOB_NS}
spec:
  backoffLimit: 1
  ttlSecondsAfterFinished: 600
  template:
    spec:
      restartPolicy: Never
      serviceAccountName: lego-issuer
      volumes:
        - name: certs
          emptyDir: {}
      initContainers:
        - name: lego
          image: goacme/lego:v4.22.2
          imagePullPolicy: IfNotPresent
          env:
            - name: NETLIFY_TOKEN
              valueFrom:
                secretKeyRef:
                  name: netlify-api-token
                  key: token
          args:
            - --path=/data
            - --accept-tos
            - --email=${EMAIL}
            - --dns=netlify
            - --domains=${DOMAIN}
            - --domains=${WILDCARD}
            - --filename=${CERT_BASENAME}
            - run
          volumeMounts:
            - name: certs
              mountPath: /data
      containers:
        - name: apply-secret
          image: ${KUBECTL_IMAGE}
          imagePullPolicy: IfNotPresent
          command:
            - /bin/sh
            - -c
            - |
              set -e
              CRT="/data/certificates/${CERT_BASENAME}.crt"
              KEY="/data/certificates/${CERT_BASENAME}.key"
              test -f "\$CRT"
              test -f "\$KEY"
              kubectl -n "${NAMESPACE}" create secret tls "${SECRET_NAME}" \\
                --cert="\$CRT" --key="\$KEY" \\
                --dry-run=client -o yaml | kubectl apply -f -
              kubectl -n linkding create secret tls "${SECRET_NAME}" \\
                --cert="\$CRT" --key="\$KEY" \\
                --dry-run=client -o yaml | kubectl apply -f -
              echo "Applied ${SECRET_NAME} in ${NAMESPACE} and linkding"
          volumeMounts:
            - name: certs
              mountPath: /data
EOF

echo "Waiting for Job ${JOB_NS}/${JOB_NAME}..."
if ! kubectl -n "$JOB_NS" wait --for=condition=complete "job/${JOB_NAME}" --timeout=300s; then
  echo "Job failed. Logs:"
  kubectl -n "$JOB_NS" logs "job/${JOB_NAME}" --all-containers || true
  kubectl -n "$JOB_NS" describe "job/${JOB_NAME}" | tail -n 40
  exit 1
fi

kubectl -n "$JOB_NS" logs "job/${JOB_NAME}" --all-containers
echo "Done. Cert covers ${DOMAIN} and ${WILDCARD}"
echo "Open https://${DOMAIN}"
