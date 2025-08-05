# Writing a Promise
This repository is an aid for the [Writing a Promise](https://kratix.io/docs/workshop/writing-a-promise)
section of the Kratix workshop.

To install:
```
kubectl apply -f promise.yaml
```

To make a resource request:
```
kubectl apply -f resource-request.yaml
```

## Implementation Steps - Commands Used

### 1. Download Dependencies
```bash
curl https://raw.githubusercontent.com/syntasso/kratix-marketplace/main/jenkins/internal/configure-pipeline/dependencies/jenkins.io_jenkins.yaml --output internal/dependencies/jenkins.io_jenkins.yaml --silent
curl https://raw.githubusercontent.com/syntasso/kratix-marketplace/main/jenkins/internal/configure-pipeline/dependencies/all-in-one-v1alpha2.yaml --output internal/dependencies/all-in-one-v1alpha2.yaml --silent
```

### 2. Download and Setup Worker Resource Builder
```bash
mkdir -p bin
curl -sLo ./bin/worker-resource-builder-windows.tar.gz https://github.com/syntasso/kratix/releases/download/v0.0.4/worker-resource-builder_0.0.4_windows_amd64.tar.gz
tar -xvf ./bin/worker-resource-builder-windows.tar.gz -C ./bin
mv ./bin/worker-resource-builder-v*-windows-amd64.exe ./bin/worker-resource-builder.exe
cp ./bin/worker-resource-builder.exe ./internal/scripts/worker-resource-builder.exe
```

### 3. Make Scripts Executable
```bash
chmod +x ./internal/scripts/inject-deps
chmod +x ./internal/scripts/pipeline-image
```

### 4. Inject Dependencies into Promise
```bash
./internal/scripts/inject-deps
```

### 5. Build Docker Image
```bash
export PIPELINE_NAME=kratix-workshop/jenkins-configure-pipeline:dev
./internal/scripts/pipeline-image build
```

### 6. Test Docker Image (PowerShell)
```powershell
docker run -v "$((Get-Location).Path)/internal/configure-pipeline/test-input:/kratix/input" -v "$((Get-Location).Path)/internal/configure-pipeline/test-output:/kratix/output" kratix-workshop/jenkins-configure-pipeline:dev
```

### 7. Load Image into Minikube
```bash
minikube image load kratix-workshop/jenkins-configure-pipeline:dev
```

### 8. Install Promise and Create Resource Request
```bash
# Set environment variables for your cluster contexts
export PLATFORM="your-platform-context"
export WORKER="your-worker-context"

# Install the Promise
kubectl apply --context $PLATFORM --filename promise.yaml

# Verify Promise installation
kubectl --context $PLATFORM get crds --watch

# Create a resource request
kubectl apply --context $PLATFORM --filename resource-request.yaml

# Verify Jenkins Operator is running on both clusters
kubectl --context $PLATFORM get pods
kubectl --context $WORKER get pods

# Check pipeline execution
kubectl logs --context $PLATFORM --selector kratix.io/promise-name=jenkins-default --container create-jenkins-instance

# Watch for Jenkins instance creation
kubectl --context $WORKER get pods --all-namespaces --watch
```

## Notes
- The Jenkins Operator runs on both platform and worker clusters as expected
- The configure pipeline runs on the platform cluster
- The actual Jenkins instances are deployed to the worker cluster
- For Minikube, both PLATFORM and WORKER contexts are typically "minikube"

