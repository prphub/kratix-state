# File: postgresql/BUILD_AND_DEPLOY.md

# PostgreSQL Promise - Build and Deployment Guide

## Prerequisites

Before you can deploy this PostgreSQL Promise, you need to build and push the configure pipeline image to a container registry.

## Step 1: Choose a Container Registry

You can use any of these registries:

### Option A: Docker Hub (docker.io)
```bash
# Login to Docker Hub
docker login

# Your image will be: docker.io/YOUR_USERNAME/postgresql-configure-pipeline:v0.1.0
```

### Option B: GitHub Container Registry (ghcr.io)
```bash
# Login to GitHub Container Registry
echo $GITHUB_TOKEN | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin

# Your image will be: ghcr.io/YOUR_GITHUB_USERNAME/postgresql-configure-pipeline:v0.1.0
```

### Option C: Private Registry
```bash
# Login to your private registry
docker login your-registry.com

# Your image will be: your-registry.com/postgresql-configure-pipeline:v0.1.0
```

## Step 2: Build and Push the Pipeline Image

### Navigate to the pipeline directory:
```bash
cd postgresql/pipeline
```

### Build the image (replace YOUR_REGISTRY with your actual registry):
```bash
# For Docker Hub
docker build -t docker.io/YOUR_USERNAME/postgresql-configure-pipeline:v0.1.0 .

# For GitHub Container Registry
docker build -t ghcr.io/YOUR_GITHUB_USERNAME/postgresql-configure-pipeline:v0.1.0 .

# For private registry
docker build -t your-registry.com/postgresql-configure-pipeline:v0.1.0 .
```

### Push the image:
```bash
# For Docker Hub
docker push docker.io/YOUR_USERNAME/postgresql-configure-pipeline:v0.1.0

# For GitHub Container Registry
docker push ghcr.io/YOUR_GITHUB_USERNAME/postgresql-configure-pipeline:v0.1.0

# For private registry
docker push your-registry.com/postgresql-configure-pipeline:v0.1.0
```

## Step 3: Update the Promise Configuration

Edit the `postgresql/promise.yaml` file and replace `YOUR_REGISTRY` with your actual image reference:

### Find these lines (appears twice in the file):
```yaml
containers:
  - image: YOUR_REGISTRY/postgresql-configure-pipeline:v0.1.0
    name: postgresql-configure-pipeline
```

### Replace with your actual image:
```yaml
# Example for Docker Hub
containers:
  - image: docker.io/YOUR_USERNAME/postgresql-configure-pipeline:v0.1.0
    name: postgresql-configure-pipeline

# Example for GitHub Container Registry
containers:
  - image: ghcr.io/YOUR_GITHUB_USERNAME/postgresql-configure-pipeline:v0.1.0
    name: postgresql-configure-pipeline
```

## Step 4: Deploy the Promise

```bash
# Apply the Promise to your Kratix platform cluster
kubectl apply -f postgresql/promise.yaml

# Verify the Promise is installed
kubectl get promises
kubectl describe promise postgresql
```

## Step 5: Test with a Sample Request

```bash
# Apply a sample PostgreSQL request
kubectl apply -f postgresql/request-examples/basic-postgresql.yaml

# Check the created resources
kubectl get postgresql
kubectl get pods -l app=basic-db-postgresql
```

## Troubleshooting Build Issues

### Image Pull Errors
If you see `ImagePullBackOff` or `ErrImagePull`:

1. **Verify image exists**:
   ```bash
   docker pull YOUR_REGISTRY/postgresql-configure-pipeline:v0.1.0
   ```

2. **Check registry permissions**:
   - Ensure the image is public OR
   - Configure image pull secrets for private registries

3. **Verify image reference** in promise.yaml matches exactly what you pushed

### Authentication Issues

#### For Docker Hub:
```bash
docker login
# Enter your Docker Hub username and password/token
```

#### For GitHub Container Registry:
```bash
# Create a GitHub Personal Access Token with 'write:packages' scope
export GITHUB_TOKEN=your_token_here
echo $GITHUB_TOKEN | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin
```

#### For Private Registries:
```bash
docker login your-registry.com
# Enter your registry credentials
```

### Build Context Issues
Make sure you're in the correct directory:
```bash
cd postgresql/pipeline
ls -la  # Should show Dockerfile and configure.sh
```

## Alternative: Local Development

For development/testing, you can use a local registry:

```bash
# Start a local registry
docker run -d -p 5000:5000 --name registry registry:2

# Build and push to local registry
docker build -t localhost:5000/postgresql-configure-pipeline:v0.1.0 .
docker push localhost:5000/postgresql-configure-pipeline:v0.1.0

# Update promise.yaml to use:
# image: localhost:5000/postgresql-configure-pipeline:v0.1.0
```

## Security Considerations

1. **Use specific tags** instead of `latest` for production
2. **Scan images** for vulnerabilities before deployment
3. **Use private registries** for sensitive workloads
4. **Configure image pull secrets** for private registries in Kubernetes

## Next Steps

After successful deployment:
1. Test with different PostgreSQL configurations
2. Monitor the pipeline logs for any issues
3. Customize the configure script for your specific needs
4. Set up monitoring for the PostgreSQL instances

## Support

If you encounter issues:
1. Check the pipeline container logs
2. Verify the Promise status
3. Review the troubleshooting guide in `docs/troubleshooting.md`