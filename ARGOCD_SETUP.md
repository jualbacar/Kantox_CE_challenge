# ArgoCD Setup Guide for Minikube

Complete setup process for running ArgoCD on Minikube.

## Prerequisites

- Minikube installed
- Docker Desktop installed
- kubectl configured

## 1. Start Minikube

```bash
minikube start
```

## 2. Install ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Wait for pods to be ready:

```bash
kubectl get pods -n argocd -w
```

## 3. Access ArgoCD UI

Expose ArgoCD server:

```bash
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'
```

Get the access URL:

```bash
echo "https://$(minikube ip):$(kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.ports[1].nodePort}')"
```

Get admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo
```

Login with:
- Username: `admin`
- Password: (from command above)

---

## OPTIONAL: Corporate Proxy/TLS Certificate Setup

**Only needed if you encounter TLS certificate errors when pulling container images.**

### Problem
Corporate proxy intercepts HTTPS traffic causing: `tls: failed to verify certificate: x509: certificate signed by unknown authority`

### Solution: Configure Docker Desktop CA Certificate

1. Extract your corporate CA certificate:

   **From macOS Keychain:**
   ```bash
   # Open Keychain Access, find corporate CA, export as corporate-ca.cer
   open "/System/Applications/Utilities/Keychain Access.app"
   
   # Convert to PEM
   openssl x509 -inform DER -in ~/Downloads/corporate-ca.cer -out ~/Downloads/corporate-ca.pem
   ```

   **OR from TLS connection:**
   ```bash
   openssl s_client -showcerts -connect ghcr.io:443 </dev/null 2>/dev/null | openssl x509 -outform PEM > ~/Downloads/corporate-ca.pem
   ```

2. Configure Docker Desktop:
   - Open **Docker Desktop** → **Settings** → **Docker Engine**
   - Add to JSON config:
     ```json
     {
       "certs": {
         "ghcr.io": ["/Users/YOUR_USERNAME/Downloads/corporate-ca.pem"],
         "quay.io": ["/Users/YOUR_USERNAME/Downloads/corporate-ca.pem"]
       }
     }
     ```
   - Click **Apply & Restart**

3. Test:
   ```bash
   docker pull ghcr.io/dexidp/dex:v2.43.0
   ```

### If Pods Still Fail to Pull Images

If `argocd-dex-server` pod shows `ImagePullBackOff`:

```bash
# Pull image locally
docker pull ghcr.io/dexidp/dex:v2.43.0

# Load into Minikube
docker save ghcr.io/dexidp/dex:v2.43.0 | (eval $(minikube docker-env) && docker load)

# Patch deployment to use local images
kubectl patch deployment argocd-dex-server -n argocd --type='json' \
  -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/imagePullPolicy", "value": "IfNotPresent"}]'
```

---

## Alternative Access: Port Forward

Instead of NodePort, use port forwarding:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Access at: https://localhost:8080

## Clean Up

Remove ArgoCD:

```bash
kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl delete namespace argocd
```

Stop Minikube:

```bash
minikube stop
```

## Next Steps

- Connect your Git repository to ArgoCD
- Create ArgoCD Applications for API and AUX services
- Set up ApplicationSets for multi-environment deployments (dev/qa/prod)
- Configure AWS credential secrets management
