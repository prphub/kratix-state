# PostgreSQL Promise - Local Testing Guide

This document provides instructions for testing the PostgreSQL Promise pipeline locally using Docker.

## Prerequisites

- Docker installed and running
- Access to the container registry (ghcr.io)
- Git Bash or compatible shell for Linux-style commands

## Container Information

- **Image**: `ghcr.io/prphub/kratix-state/postgresql-configure-pipeline:v0.1.0`
- **Architecture**: `linux/amd64`
- **Base**: Alpine Linux with `yq` tool
- **Entry Point**: `/usr/local/bin/configure.sh`

## Testing Commands

### 1. Basic Container Test

Test that the container runs without errors:

```bash
# Test resource workflow
docker run --rm -e KRATIX_WORKFLOW_TYPE=resource ghcr.io/prphub/kratix-state/postgresql-configure-pipeline:v0.1.0

# Test promise workflow
docker run --rm -e KRATIX_WORKFLOW_TYPE=promise ghcr.io/prphub/kratix-state/postgresql-configure-pipeline:v0.1.0
```

Both commands should complete without errors and no output (expected behavior).

### 2. Full Pipeline Test with Input/Output

Test the complete pipeline with actual input and output:

```bash
# Navigate to postgresql directory
cd promise/postgresql

# Test with existing test input
docker run --rm \
  -e KRATIX_WORKFLOW_TYPE=resource \
  -v "$(pwd)/test-input:/kratix/input" \
  -v "$(pwd)/test-output:/kratix/output" \
  ghcr.io/prphub/kratix-state/postgresql-configure-pipeline:v0.1.0

# Check the generated output
ls -la test-output/
cat test-output/postgresql-instance.yaml
```

## Test Input Format

The pipeline expects a PostgreSQL resource request in `/kratix/input/object.yaml`:

```yaml
apiVersion: marketplace.kratix.io/v1alpha1
kind: postgresql
metadata:
  name: postgres-final-test
  namespace: post
spec:
  size: small        # small, medium, or large
  database: finaltest # database name
```

## Expected Output

The pipeline generates a complete PostgreSQL deployment in `/kratix/output/postgresql-instance.yaml`:

### Generated Resources

1. **Deployment** (`apps/v1`)
   - PostgreSQL 15 Alpine container
   - Resource limits based on size specification
   - Persistent volume mount
   - Environment variables for database configuration

2. **Service** (`v1`)
   - ClusterIP service on port 5432
   - Selector matching deployment labels

3. **PersistentVolumeClaim** (`v1`)
   - Storage allocation based on size:
     - `small`: 1Gi
     - `medium`: 5Gi  
     - `large`: 10Gi

4. **Secret** (`v1`)
   - Base64 encoded password: `postgres123`
   - Referenced by deployment for POSTGRES_PASSWORD

### Size-Based Configurations

| Size   | Storage | Memory Request | Memory Limit | CPU Request | CPU Limit |
|--------|---------|----------------|--------------|-------------|-----------|
| small  | 1Gi     | 256Mi          | 512Mi        | 100m        | 500m      |
| medium | 5Gi     | 512Mi          | 1Gi          | 250m        | 1000m     |
| large  | 10Gi    | 1Gi            | 2Gi          | 500m        | 2000m     |

## Common Issues and Solutions

### 1. "exec format error"
**Problem**: Container fails with `exec /usr/local/bin/configure.sh: exec format error`

**Solution**: Ensure the image was built with correct platform:
```bash
docker buildx build --platform linux/amd64 -t ghcr.io/prphub/kratix-state/postgresql-configure-pipeline:v0.1.0 . --push
```

### 2. No output generated
**Problem**: Container runs but no files appear in output directory

**Causes**:
- Missing input file at `/kratix/input/object.yaml`
- Incorrect KRATIX_WORKFLOW_TYPE environment variable
- Volume mount issues

**Solution**: Verify input file exists and volume mounts are correct

### 3. Permission errors
**Problem**: Cannot write to output directory

**Solution**: Ensure output directory has correct permissions:
```bash
mkdir -p test-output
chmod 755 test-output
```

## Building the Container

To rebuild the container after changes:

```bash
cd promise/postgresql/internal/configure-pipeline

# Build and push
docker buildx build --platform linux/amd64 -t ghcr.io/prphub/kratix-state/postgresql-configure-pipeline:v0.1.0 . --push
```

## Workflow Types

- **`resource`**: Processes PostgreSQL resource requests and generates Kubernetes manifests
- **`promise`**: Installs cluster-wide dependencies (currently none for PostgreSQL)

## Validation

After testing, verify the output:

1. **YAML Syntax**: Ensure generated YAML is valid
2. **Resource Names**: Check that names match input metadata
3. **Namespace**: Verify namespace is correctly propagated
4. **Labels**: Confirm consistent labeling across resources
5. **References**: Validate secret references and volume claims

## Integration with Kratix

Once local testing passes, the container can be deployed to Kratix:

```bash
kubectl --context=platform apply -f promise.yaml
```

Monitor the promise status:
```bash
kubectl --context=platform get promises
kubectl --context=platform describe promise postgresql
```
