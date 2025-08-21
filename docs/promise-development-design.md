# Postgres Promise: Detailed Design and Execution Flow

This document provides a detailed design and execution flow for the custom Postgres Promise, focusing on how resource requests are processed, how the `execute-pipeline` script works, and how the deployment is performed via containerized pipelines.

> Note: While examples reference Postgres, this design is generic and applies to any custom Kratix Promise.

---

## 1. High-Level Flow

1. **Promise Definition**: The Postgres Promise is defined as a CRD in `promise.yaml`.
2. **Promise Application**: When the Promise is applied to the cluster, it registers the CRD and associated pipeline logic.
3. **Resource Request**: A user creates a custom resource (e.g., `Postgresql`) with their desired spec (database name, size, etc.).
4. **Pipeline Trigger**: Kratix detects the new resource and triggers the pipeline defined in the Promise.
5. **Pipeline Execution**: The pipeline runs in a container, executing the `execute-pipeline` script.
6. **Template Rendering & Deployment**: The script reads the resource spec, renders deployment manifests, and outputs them for application to the cluster.
7. **Status Update**: The pipeline updates the resource status with provisioning results.

---

## 2. Detailed Execution Flow

### a. Resource Request Example

```yaml
apiVersion: marketplace.kratix.io/v1
kind: Postgresql
metadata:
  name: my-db
  namespace: my-namespace
spec:
  database: mydatabase
  size: medium
```

### b. Pipeline Container & Dockerfile

- The pipeline logic is packaged as a Docker image.
- The image contains the `execute-pipeline` script and any dependencies (e.g., `yq`, `sed`).
- The Dockerfile copies the script and templates into the image.

**Dockerfile snippet:**
```dockerfile
FROM alpine:3.18
RUN apk add --no-cache yq
COPY execute-pipeline /usr/local/bin/execute-pipeline
COPY postgresql-instance.yaml /tmp/transfer/postgresql-instance.yaml
ENTRYPOINT ["/usr/local/bin/execute-pipeline"]
```

### c. Pipeline Execution (`execute-pipeline`)

- The pipeline is invoked by Kratix with environment variables and input files:
  - `/kratix/input/object.yaml`: The resource request YAML.
  - `$KRATIX_WORKFLOW_TYPE`: Indicates if this is a `promise` or `resource` workflow.

**Key Steps in `execute-pipeline`:**
1. **Read Input Values**: Uses `yq` to extract values from the resource spec (e.g., name, namespace, size, database).
2. **Set Defaults**: Sets default storage and replica values based on the `size` field.
3. **Render Template**: Uses `sed` to substitute placeholders in the manifest template with actual values.
4. **Output Manifest**: Writes the rendered manifest to `/kratix/output/postgresql-instance.yaml` for Kratix to apply.

**Script snippet:**
```sh
export name="$(yq eval '.metadata.name' /kratix/input/object.yaml)"
export namespace="$(yq eval '.metadata.namespace' /kratix/input/object.yaml)"
export size="$(yq eval '.spec.size' /kratix/input/object.yaml)"
export database="$(yq eval '.spec.database' /kratix/input/object.yaml)"
# ... set storage/replicas ...
sed -e "s/placeholder-namespace/${namespace}/g" \
    -e "s/placeholder-name/${name}/g" \
    -e "s/placeholder-database/${database}/g" \
    /tmp/transfer/postgresql-instance.yaml > /kratix/output/postgresql-instance.yaml
```

### d. Commit and Deployment

- When the Promise is applied, Kratix commits the CRD and pipeline definition to the cluster.
- When a resource request is created, Kratix triggers the pipeline, which produces the manifest.
- The output manifest is then applied to the cluster, creating the actual Postgres deployment (e.g., StatefulSet, Service, Secret).

### e. Status Management

- The pipeline can update the status subresource of the custom resource to reflect provisioning state, errors, or connection details.

---

## 3. Mermaid: End-to-End Flow

```mermaid
sequenceDiagram
  autonumber
  participant U as User / Platform Consumer
  participant K as Kubernetes API (Platform)
  participant X as Kratix Controller
  participant P as Pipeline Container (execute-pipeline)
  participant G as State Store (Git)
  participant CD as GitOps (Argo CD / Flux)
  participant W as Kubernetes API (Worker)
  participant T as Target System / Operator

  rect rgb(255,242,204)
    note over U,K: Promise installation (one-time)
    U->>K: Apply promise.yaml (CRD + workflows)
    K-->>X: CRD registered; workflows reconciled
    X->>P: Run promise workflow (KRATIX_WORKFLOW_TYPE=promise)
    P-->>X: Output dependencies (/kratix/output/*)
    X->>G: Commit platform/worker dependencies
  end

  rect rgb(218,232,252)
    note over U,K: Resource lifecycle
    U->>K: Create Resource CR (kind: CustomKind)
    K-->>X: Event: new Resource CR
    X->>P: Run resource workflow (KRATIX_WORKFLOW_TYPE=resource)
    P->>P: Read /kratix/input/object.yaml (yq)
    P->>P: Render manifests -> /kratix/output/*.yaml
    P-->>X: Exit 0 with outputs
    X->>G: Commit outputs (path by destinationSelectors)
    G-->>CD: Repo change detected
    CD->>W: Sync and apply manifests
    W->>T: Reconcile to target system
    T-->>W: Ready/Status
    W-->>X: Feedback (status/events)
    X-->>K: Update Resource CR .status
  end

  alt Error path
    P-->>X: Non-zero exit / error
    X-->>K: Update .status with error details
  end
```

---

## 4. Key Design Points

- **Separation of Concerns**: Business logic is in the pipeline container, not the controller.
- **Declarative**: All values are taken from the resource spec, making the process repeatable and auditable.
- **Extensible**: To add new fields, update the CRD, template, and script logic.
- **Containerized**: The pipeline runs in a container, ensuring a consistent environment.

---

## 5. Delivery via State Store (Git) and Destination Selection

- **State Store Commit:** Kratix writes `/kratix/output/*` to the configured state store (Git repo). Each run results in a commit under a deterministic path (e.g., by resource UID/namespace/kind).
- **Destination Routing:** `destinationSelectors` on the Promise direct outputs to one or more destinations (e.g., worker clusters). Kratix separates platform vs worker dependencies and resource outputs accordingly.
- **GitOps Application:** Argo CD / Flux in each destination watches the state store path and applies the manifests, ensuring drift detection and reconciliation.

## 6. Workflows: Promise vs Resource

- **Promise workflow (install-time):** Publishes dependencies (CRDs/operators/Namespaces/RBAC) needed for consumers and workers.
- **Resource workflow (per-request):** Reads the resource CR, renders manifests, and emits them to `/kratix/output`.

## 7. RBAC and Secrets

- Grant least-privilege RBAC to the pipeline:
  - Read-only to secrets required for rendering (e.g., credentials referenced via `env.valueFrom.secretKeyRef`).
  - CRUD on the Promise’s API group for reading/updating status.
  - No direct cluster-admin; rely on GitOps to apply rendered resources.
- Store secrets in a designated namespace (e.g., `common-secrets`) and reference them explicitly in pipeline `rbac.permissions`.

## 8. Error Handling and Idempotency

- Make `execute-pipeline` idempotent: rendering the same inputs produces the same outputs (no timestamps/randomness in file names/paths).
- Fail fast with clear exit codes and stderr messages; write a human-readable `message` to `.status` on errors.
- Avoid partial writes: render to a temp dir, then move into `/kratix/output` atomically.

## 9. Observability and Status

- Write progress and errors to stdout/stderr; Kratix surfaces logs on pipeline pods.
- Use structured status fields (conditions, message, timestamps) to reflect lifecycle: Pending -> Rendering -> Committed -> Applied -> Ready/Error.

## 10. Versioning and Compatibility

- Track Promise version via `kratix.io/promise-version` label; bump on breaking CRD or workflow changes.
- Prefer additive schema changes; when breaking, support migration or dual-version storage if feasible.

## 11. Testing

- Provide `test-input/object.yaml` and golden outputs under `test-output/` to validate rendering.
- Run the container locally with mounted input to verify `/kratix/output` contents.
- Include CI that diffs rendered outputs against goldens.

## 12. Security

- Use pinned, minimal base images and enable image provenance (Sigstore/cosign if available).
- Scope RBAC to required resources only; avoid wildcard verbs.
- Never print secret values in logs; prefer referencing via environment variables.

---

For further details, see the actual `execute-pipeline` script and Dockerfile in the `promise/postgresql/internal/configure-pipeline/` directory.
