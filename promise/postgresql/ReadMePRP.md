# PostgreSQL Promise for Kratix - Complete Implementation Guide

## Overview
This document provides a comprehensive guide for implementing a PostgreSQL Promise in Kratix, including all issues encountered, debugging approaches, and solutions applied during development.

## Project Structure
```
promise/postgresql/
├── promise.yaml                    # Main Promise definition
├── resource-request.yaml          # Example resource request
├── README.md                      # This documentation
├── docs/                          # Additional documentation
├── internal/
│   └── configure-pipeline/
│       ├── Dockerfile             # Pipeline container image
│       ├── execute-pipeline       # Main pipeline script
│       └── resources/
│           └── postgresql-instance.yaml  # Template manifest
└── test-input/
    └── object.yaml               # Test resource request
```

## Implementation Journey

### Phase 1: Initial Setup and ImagePullBackOff Issues

#### Problem 1: ImagePullBackOff Errors
**Symptom:**
```bash
$ kp get pods
NAME                                                              READY   STATUS             RESTARTS   AGE
kratix-postgresql-postgres-example-instance-configure-xyz        0/1     ImagePullBackOff   0          2m
```

**Root Cause:** Missing or incorrect Docker image in container registry.

**Debug Commands:**
```bash
# Check pod status
kp describe pod kratix-postgresql-postgres-example-instance-configure-xyz

# Check image availability
docker pull ghcr.io/prphub/kratix-state/postgresql-configure-pipeline:v0.1.0
```

**Solution:** Built and pushed correct Docker image:
```bash
cd promise/postgresql/internal/configure-pipeline
docker buildx build --platform linux/amd64 -t ghcr.io/prphub/kratix-state/postgresql-configure-pipeline:v0.1.0 . --push
```

#### Problem 2: Dockerfile Configuration Issues
**Initial Dockerfile Problems:**
- Missing proper CMD directive
- Incorrect script placement
- Alpine base image compatibility

**Original Broken Dockerfile:**
```dockerfile
FROM alpine:latest
RUN apk update && apk add --no-cache yq
ADD execute-pipeline /usr/local/bin/configure.sh
RUN chmod +x /usr/local/bin/configure.sh
```

**Fixed Dockerfile:**
```dockerfile
FROM alpine:latest
RUN [ "mkdir", "/tmp/transfer" ]
RUN apk update && apk add --no-cache yq
ADD resources/ /tmp/transfer/
ADD execute-pipeline execute-pipeline
CMD ["sh", "-c", "./execute-pipeline"]
```

**Key Changes:**
1. Added proper CMD directive
2. Correct script placement and naming
3. Proper resource directory structure

### Phase 2: Pipeline Script Debugging

#### Problem 3: Complex yq Expressions Failing
**Original Complex Script (Failed):**
```bash
# Complex yq pipeline that failed silently
cat /tmp/transfer/postgresql-instance.yaml | \
  yq eval '.metadata.name = env(name)' | \
  yq eval '.metadata.namespace = env(namespace)' | \
  yq eval '.spec.replicas = env(replicas)' | \
  yq eval '.spec.template.spec.containers[0].env[0].value = env(database)' | \
  yq eval '.spec.template.spec.containers[0].env[1].valueFrom.secretKeyRef.name = env(name) + "-secret"' | \
  yq eval '.spec.template.spec.containers[0].volumes[0].persistentVolumeClaim.claimName = env(name) + "-pvc"' - \
  > /kratix/output/postgresql-instance.yaml
```

**Issue:** Complex yq selector expressions were failing silently because the PostgreSQL template contains multiple YAML documents (Deployment, Service, PVC, Secret), but yq was only modifying the first document.

#### Problem 4: Comparison with Working Redis Implementation
**Analysis Commands:**
```bash
# Compare Redis vs PostgreSQL implementations
diff promise/redis/internal/configure-pipeline/execute-pipeline promise/postgresql/internal/configure-pipeline/execute-pipeline

# Check Redis template structure
cat promise/redis/internal/configure-pipeline/resources/redis-instance.yaml

# Check PostgreSQL template structure
cat promise/postgresql/internal/configure-pipeline/resources/postgresql-instance.yaml
```

**Key Difference Discovered:**
- **Redis:** Single YAML document, yq works fine
- **PostgreSQL:** Multiple YAML documents separated by `---`, yq only processes first document

**Solution:** Switched from complex yq to simple sed replacement:
```bash
# Simple sed approach that works with multiple documents
sed -e "s/placeholder-name/${name}/g" \
    -e "s/placeholder-namespace/${namespace}/g" \
    -e "s/placeholder-database/${database}/g" \
    /tmp/transfer/postgresql-instance.yaml > /kratix/output/postgresql-instance.yaml
```

### Phase 3: Work and WorkPlacement Issues

#### Problem 5: PostgreSQL Work Created but No WorkPlacements
**Debug Commands:**
```bash
# Check Work objects
kp get work

# Detailed Work inspection
kp get work postgresql-postgres-example-instance-configure-241cf -o yaml

# Check WorkPlacements
kp get workplacements

# Compare with working Redis
kp get work redis-example-instance-configure-6c00f -o yaml
```

**Root Cause Analysis:**
```bash
# PostgreSQL Work object missing workloadGroups
spec:
  promiseName: postgresql
  resourceName: postgres-example
# No workloadGroups section!

# Redis Work object had workloadGroups
spec:
  promiseName: redis
  resourceName: example
  workloadGroups:
  - workloads:
    - object:
        apiVersion: redis.redis.opstreelabs.in/v1beta1
        kind: RedisFailover
        # ... actual manifest content
```

**Conclusion:** Pipeline wasn't generating output files, so Kratix couldn't create WorkPlacements.

### Phase 4: Local Testing and Validation

#### Problem 6: Docker Local Testing Issues
**Windows Path Issues:**
```bash
# Failed command (Windows path problems)
docker run --rm -e KRATIX_WORKFLOW_TYPE=resource -v $PWD/test-input:/kratix/input -v $PWD/test-output:/kratix/output ghcr.io/prphub/kratix-state/postgresql-configure-pipeline:v0.1.0

# Result: Created weird folders like "test-input;D" and "test-output;D"
```

**Solution - Correct Windows Docker Commands:**
```bash
# Create output directory
mkdir -p test-output

# Use absolute Windows paths
docker run --rm -e KRATIX_WORKFLOW_TYPE=resource \
  -v /d/ws/k8s/kratix-state/promise/postgresql/test-input:/kratix/input \
  -v /d/ws/k8s/kratix-state/promise/postgresql/test-output:/kratix/output \
  ghcr.io/prphub/kratix-state/postgresql-configure-pipeline:v0.1.0

# Alternative for CMD/PowerShell
docker run --rm -e KRATIX_WORKFLOW_TYPE=resource ^
  -v D:\ws\k8s\kratix-state\promise\postgresql\test-input:/kratix/input ^
  -v D:\ws\k8s\kratix-state\promise\postgresql\test-output:/kratix/output ^
  ghcr.io/prphub/kratix-state/postgresql-configure-pipeline:v0.1.0
```

### Phase 5: Final Working Implementation

#### Final execute-pipeline Script
```bash
#!/usr/bin/env sh

set -eux

if [ "$KRATIX_WORKFLOW_TYPE" = "resource" ]; then
  # Read current values from the provided resource request
  export name="$(yq eval '.metadata.name' /kratix/input/object.yaml)"
  export namespace="$(yq eval '.metadata.namespace' /kratix/input/object.yaml)"
  export size="$(yq eval '.spec.size' /kratix/input/object.yaml)"
  export database="$(yq eval '.spec.database' /kratix/input/object.yaml)"

  # Set defaults based on size
  export storage="1Gi"
  export replicas=1

  if [ "$size" = "medium" ]; then
    storage="5Gi"
  elif [ "$size" = "large" ]; then
    storage="10Gi"
    replicas=2
  fi

  # Process the template with multiple documents using sed like Redis does
  sed -e "s/placeholder-name/${name}/g" \
      -e "s/placeholder-namespace/${namespace}/g" \
      -e "s/placeholder-database/${database}/g" \
      /tmp/transfer/postgresql-instance.yaml > /kratix/output/postgresql-instance.yaml
  exit 0
fi

if [ "$KRATIX_WORKFLOW_TYPE" = "promise" ]; then
  cp -r /tmp/transfer/dependencies/* /kratix/output/
  exit 0
fi

echo "unsupported KRATIX_WORKFLOW_TYPE: $KRATIX_WORKFLOW_TYPE"
exit 1
```

#### Key Design Decisions

**Why sed instead of yq for template processing:**
1. **Multiple YAML Documents:** PostgreSQL template has 4 resources (Deployment, Service, PVC, Secret)
2. **yq Limitation:** Only processes first document in multi-document YAML
3. **sed Advantage:** Processes entire file content, handles all documents

**Why yq is still used for input reading:**
1. **Structured Data:** Need to extract specific fields from YAML
2. **Type Safety:** yq handles YAML parsing correctly
3. **Kratix Standard:** Consistent with Redis and other marketplace promises

## Debugging Toolkit

### Essential Commands

#### Kratix Resource Monitoring
```bash
# Set up aliases (add to ~/.bashrc)
export PLATFORM=platform
export WORKER=worker
alias kp="kubectl --context=$PLATFORM"
alias kw="kubectl --context=$WORKER"

# Monitor promise installation
kp get promises
kp describe promise postgresql

# Monitor resource requests
kp get postgresql
kp describe postgresql postgres-example

# Monitor pipeline execution
kp get pods -n kratix-platform-system
kp logs -f kratix-postgresql-postgres-example-instance-configure-xyz -n kratix-platform-system

# Monitor Work and WorkPlacements
kp get work
kp get work postgresql-postgres-example-instance-configure-xyz -o yaml
kp get workplacements
```

#### Docker Image Management
```bash
# Build and push image
cd promise/postgresql/internal/configure-pipeline
docker buildx build --platform linux/amd64 -t ghcr.io/prphub/kratix-state/postgresql-configure-pipeline:v0.1.0 . --push

# Verify image
docker pull ghcr.io/prphub/kratix-state/postgresql-configure-pipeline:v0.1.0

# Test locally
docker run --rm -e KRATIX_WORKFLOW_TYPE=resource \
  -v /d/ws/k8s/kratix-state/promise/postgresql/test-input:/kratix/input \
  -v /d/ws/k8s/kratix-state/promise/postgresql/test-output:/kratix/output \
  ghcr.io/prphub/kratix-state/postgresql-configure-pipeline:v0.1.0

# Interactive debugging
docker run --rm -it -v /d/ws/k8s/kratix-state/test-input:/kratix/input -e KRATIX_WORKFLOW_TYPE=resource ghcr.io/prphub/kratix-state/postgresql-configure-pipeline:v0.1.0 sh
```

#### Git State Store Monitoring
```bash
# Check if resources are committed to Git
cd /path/to/kratix-state-repo
git log --oneline
git status

# Check worker resources
kw get pods -n default
kw get postgresql -n default
```

#### Manual Reconciliation Trigger
```bash
# Force Kratix to recreate pipeline job
kubectl --context=platform annotate postgresql postgres-example kratix.io/manual-reconciliation=$(date +%s) -n default
```

### Troubleshooting Scenarios

#### Scenario 1: ImagePullBackOff
1. Verify image exists: `docker pull <image>`
2. Check image registry authentication
3. Verify imagePullSecrets in Promise
4. Check platform has access to registry

#### Scenario 2: Pipeline Completes but No Git Commit
1. Check Work object has workloadGroups: `kp get work <name> -o yaml`
2. Verify pipeline generates output: Local Docker test
3. Check worker connectivity and GitOps configuration
4. Verify destinationSelectors match worker labels

#### Scenario 3: Template Processing Issues
1. Test template locally with sample data
2. Validate YAML structure (single vs multi-document)
3. Check placeholder names match sed expressions
4. Verify environment variables are set correctly

#### Scenario 4: Resource Creation Fails on Worker
1. Check WorkPlacement status: `kp get workplacements`
2. Verify worker cluster has required CRDs/operators
3. Check namespace and RBAC permissions
4. Validate generated manifests are syntactically correct

## Testing Strategy

### Local Development Testing
```bash
# 1. Build image locally
docker build -t test-postgresql-pipeline .

# 2. Test with sample input
mkdir -p test-input test-output
cp ../test-input/object.yaml test-input/
docker run --rm -e KRATIX_WORKFLOW_TYPE=resource \
  -v $PWD/test-input:/kratix/input \
  -v $PWD/test-output:/kratix/output \
  test-postgresql-pipeline

# 3. Validate output
cat test-output/postgresql-instance.yaml
```

### Integration Testing
```bash
# 1. Deploy to Kratix
kp apply -f promise.yaml

# 2. Create resource request
kp apply -f resource-request.yaml

# 3. Monitor pipeline execution
kp get pods -n kratix-platform-system -w

# 4. Verify Work creation
kp get work

# 5. Check WorkPlacement scheduling
kp get workplacements

# 6. Validate worker deployment
kw get all -n target-namespace
```

## Configuration Reference

### Promise.yaml Key Sections
```yaml
spec:
  destinationSelectors:
  - matchLabels:
      environment: dev  # Must match worker labels
  
  workflows:
    resource:
      configure:
        - spec:
            containers:
            - image: ghcr.io/prphub/kratix-state/postgresql-configure-pipeline:v0.1.0
              imagePullPolicy: Always  # Ensures latest image
            imagePullSecrets:
            - name: ghcr-secret  # Required for private registries
```

### Resource Request Schema
```yaml
apiVersion: marketplace.kratix.io/v1alpha1
kind: postgresql
metadata:
  name: postgres-example
  namespace: default
spec:
  size: small      # small|medium|large
  database: myapp  # Database name to create
```

## Lessons Learned

1. **Multi-document YAML Templates:** Use sed for replacement, not complex yq expressions
2. **Local Testing:** Essential for rapid iteration and debugging
3. **Image Pull Policy:** Set to "Always" during development for latest changes
4. **Windows Docker Volumes:** Use absolute paths, not relative $PWD
5. **Work vs WorkPlacements:** Work creation doesn't guarantee WorkPlacement scheduling
6. **Silent Failures:** Pipeline can complete successfully but produce no output
7. **Template Placeholders:** Simple string replacement more reliable than complex expressions

## Production Considerations

### Image Versioning
- Use semantic versioning for production images
- Pin specific versions in production Promise definitions
- Test image changes in development environment first

### Security
- Use imagePullSecrets for private registries
- Implement proper RBAC for Promise and pipeline operations
- Validate input parameters to prevent injection attacks

### Monitoring
- Set up alerts for pipeline failures
- Monitor Git commit frequency and WorkPlacement creation
- Track resource creation success rates on worker clusters

### Performance
- Optimize Docker image size (multi-stage builds)
- Cache frequently used base images
- Consider pipeline resource limits for large deployments

## Usage

To request a PostgreSQL database, create a resource:

```yaml
apiVersion: marketplace.kratix.io/v1alpha1
kind: postgresql
metadata:
  name: postgres-example
  namespace: default
spec:
  size: small
  database: myapp
```

## Sizes

- `small`: 1Gi storage, 1 replica
- `medium`: 5Gi storage, 1 replica  
- `large`: 10Gi storage, 2 replicas

## Related Documentation
- [Kratix Official Documentation](https://kratix.io)
- [Kratix Marketplace](https://github.com/syntasso/kratix-marketplace)
- [Docker Multi-platform Builds](https://docs.docker.com/buildx/working-with-buildx/)
- [yq Documentation](https://mikefarah.gitbook.io/yq/)
