# k3s/Rancher Deployment Guide

This guide explains how to deploy the Astro blog site to a k3s cluster using Rancher.

## Prerequisites

- k3s cluster running (with Rancher installed)
- `kubectl` configured to access your k3s cluster
- Docker registry access (Docker Hub, GitHub Container Registry, etc.)
- `kustomize` or `kubectl apply` for deployment
- (Optional) GitHub Actions for automated deployments

## GitHub Actions Automatic Deployment

The `.github/workflows/docker_build.yml` workflow automatically builds and deploys your application on pushes to the `master` branch.

### Setting Up Secrets

You need to configure the following GitHub repository secrets for automated deployment:

1. **KUBECONFIG** (Required)
   - Your k3s cluster kubeconfig file, base64 encoded
   - Get your kubeconfig from your k3s cluster:
     ```bash
     cat ~/.kube/config | base64 -w0
     ```
   - Go to GitHub repo → **Settings** → **Secrets and variables** → **Actions**
   - Click **New repository secret**
   - Name: `KUBECONFIG`
   - Value: The base64-encoded kubeconfig
   - Click **Add secret**

### Initial Setup

Before GitHub Actions can deploy, you must apply the Kubernetes manifests to your cluster once:

```bash
kubectl apply -f k8s/
```

This creates:
- The `astro-blog` namespace
- The deployment and service
- The ingress configuration

After this initial setup, pushes to `master` will automatically update the deployment with the new image.

### How It Works

1. **Build Step**: Builds and pushes Docker image to GitHub Container Registry
2. **Deploy Step**: 
   - Creates the `astro-blog` namespace
   - Sets up image pull credentials for GitHub Container Registry
   - Updates the deployment with the new image
   - Waits for rollout to complete
   - Shows deployment status

### Triggering Deployments

Deployments are automatically triggered when:
- You push to the `master` branch
- The build completes successfully

### Monitoring Deployment

After pushing:
1. Go to your GitHub repo → **Actions**
2. Watch the workflow progress
3. Check the logs for any issues

View deployment status on your k3s cluster:
```bash
kubectl get deployments -n astro-blog
kubectl logs -n astro-blog -l app=astro-blog
```

## Step 1: Build and Push Docker Image

First, build and push your Docker image to a registry:

```bash
# Build the image
docker build -t your-registry/astro-blog-site:latest \
  --build-arg VITE_DRUPAL_BASE_URL=https://your-drupal-site.com \
  --build-arg VITE_DRUPAL_API_PREFIX=/api \
  .

# Push to registry
docker push your-registry/astro-blog-site:latest
```

Replace:
- `your-registry` with your Docker registry (e.g., `docker.io/yourusername`, `ghcr.io/yourusername`)
- Build args with your actual values

## Step 2: Update Configuration

Edit the Kubernetes manifests in the `k8s/` directory:

### Update Ingress Domain
Edit `k8s/ingress.yaml` and replace `yourdomain.com` with your actual domain.

### Update Image Reference
Either update the image in `k8s/deployment.yaml` or use environment variables with kustomize:

```bash
export REGISTRY="your-registry"
export IMAGE_NAME="astro-blog-site"
export IMAGE_TAG="latest"
```

## Step 3: Deploy Using kubectl

### Option A: Direct kubectl apply
```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml
```

### Option B: Using Kustomize (Recommended)
```bash
# With environment variables
kustomize edit set image astro-blog=${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} k8s/
kubectl apply -k k8s/
```

### Option C: Deploy via Rancher UI
1. Go to your Rancher dashboard
2. Select your cluster
3. Go to **Workloads** → **Deployments**
4. Click **Create from YAML** or **Import YAML**
5. Copy the contents of the `k8s/` directory manifests and paste them

## Step 4: Verify Deployment

```bash
# Check if pods are running
kubectl get pods -n astro-blog

# Check service status
kubectl get svc -n astro-blog

# Check ingress
kubectl get ingress -n astro-blog

# View logs
kubectl logs -n astro-blog -l app=astro-blog
```

## Step 5: Access Your Site

Once the ingress is ready, your site will be accessible at your configured domain. If using HTTP (not HTTPS):
- Direct IP access: Get the k3s ingress IP and access via that
- DNS: Update DNS records to point to your k3s node/load balancer

## Optional: Configure HTTPS with Cert-Manager

If you want automatic HTTPS:

1. Install cert-manager (if not already installed):
```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml
```

2. Create a ClusterIssuer for Let's Encrypt:
```bash
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: traefik
EOF
```

3. Uncomment the TLS section in `k8s/ingress.yaml` and redeploy

## Scaling

To scale the deployment:

```bash
kubectl scale deployment astro-blog-web -n astro-blog --replicas=3
```

Or edit `k8s/deployment.yaml` and change the `replicas` field.

## Updates

To update the deployment with a new image:

```bash
kubectl set image deployment/astro-blog-web -n astro-blog \
  web=your-registry/astro-blog-site:new-tag
```

## Troubleshooting

### Pod not starting
```bash
kubectl describe pod -n astro-blog <pod-name>
```

### Image pull errors
```bash
# Ensure image exists and registry credentials are configured
kubectl create secret docker-registry regcred \
  --docker-server=your-registry \
  --docker-username=username \
  --docker-password=password \
  -n astro-blog
```

Then add to deployment spec:
```yaml
imagePullSecrets:
- name: regcred
```

### Ingress not working
```bash
# Check traefik is running
kubectl get pods -n kube-system | grep traefik

# Check ingress status
kubectl describe ingress astro-blog-web -n astro-blog
```
