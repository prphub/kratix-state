# PostgreSQL Promise - Complete Folder Structure

```
postgresql/
├── README.md
├── promise.yaml
├── BUILD_AND_DEPLOY.md
├── request-examples/
│   ├── basic-postgresql.yaml
│   ├── production-postgresql.yaml
│   └── development-postgresql.yaml
├── pipeline/
│   ├── Dockerfile
│   └── configure.sh
└── docs/
    └── troubleshooting.md
```

## File Descriptions

- **README.md**: Complete documentation for the PostgreSQL Promise
- **promise.yaml**: Main Kratix Promise definition with CRD and pipeline configuration
- **request-examples/**: Sample YAML files showing different PostgreSQL configurations
  - **basic-postgresql.yaml**: Simple PostgreSQL instance
  - **production-postgresql.yaml**: Full-featured production setup
  - **development-postgresql.yaml**: Development environment setup
- **pipeline/**: Contains the configure pipeline
  - **Dockerfile**: Container image definition for the pipeline
  - **configure.sh**: Main script that processes requests and generates Kubernetes resources
- **docs/**: Additional documentation
  - **build-and-deploy.md**: Step-by-step guide for building and deploying the Promise
  - **troubleshooting.md**: Common issues and solutions

## Important Notes

### 🚨 Image Does Not Exist Yet
The image referenced in `promise.yaml` (`YOUR_REGISTRY/postgresql-configure-pipeline:v0.1.0`) is a **placeholder**. You MUST:

1. **Build the image** using the provided Dockerfile
2. **Push it to your container registry** 
3. **Update promise.yaml** with the correct image reference

### 🔐 Docker Authentication Required
The build and push commands require:
- Being logged into a container registry (Docker Hub, GitHub Container Registry, etc.)
- Having push permissions to that registry
- Updating the image reference in promise.yaml with your actual registry

See `BUILD_AND_DEPLOY.md` for complete instructions.