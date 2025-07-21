# 🚀 Kratix + Argo CD + Jenkins Promise Setup

This guide documents how to install Kratix on a local Minikube cluster, configure Git-based state storage, wire up Argo CD as the GitOps agent, and deploy a Jenkins promise, resulting in a fully functional Jenkins instance.

---

### 1. Prerequisites

Ensure the following are already set up:

* **Minikube** cluster
* **kubectl** CLI
* **Docker Desktop**
* GitHub repo `prphub/kratix-state` with read/write access via PAT
* Argo CD and Kratix installed in the same cluster (`platform` = `worker` context)

---

### 2. Environment

Use a single cluster for both `PLATFORM` and `WORKER`:

```bash
export PLATFORM=platform
export WORKER=platform
```

Ensure your kubeconfig context is set properly:

```bash
kubectl config rename-context minikube platform
kubectl config use-context platform
```

---

### 3. Install Kratix

```bash
kubectl --context="$PLATFORM" apply -f https://github.com/syntasso/kratix/releases/latest/download/kratix.yaml
```

Verify it’s running:

```bash
kubectl --context="$PLATFORM" get crds | grep platform.kratix.io
kubectl --context="$PLATFORM" -n kratix-platform-system get pods
```

---

### 4. Configure GitStateStore

Create a secret with your GitHub PAT and user:

```bash
kubectl --context="$PLATFORM" create secret generic git-creds \
  --from-literal=username=<GIT_USERNAME> \
  --from-literal=password=<GIT_PAT>
```

Apply GitStateStore resource:

```yaml
apiVersion: platform.kratix.io/v1alpha1
kind: GitStateStore
metadata:
  name: default
spec:
  url: https://github.com/prphub/kratix-state.git
  branch: main
  path: /
  authMethod: basicAuth
  secretRef:
    name: git-creds
    namespace: default
```

This enables Kratix to commit state files to your git repo ([docs.kratix.io][1], [docs.kratix.io][2], [docs.kratix.io][3]).

---

### 5. Register Worker Destination

Apply a Destination labeled for Jenkins:

```yaml
apiVersion: platform.kratix.io/v1alpha1
kind: Destination
metadata:
  name: worker
  labels:
    environment: dev
spec:
  path: worker
  stateStoreRef:
    name: default
    kind: GitStateStore
```

Labels match the Jenkins promise selector: `environment: dev` ([docs.kratix.io][4]). Confirm it’s Ready:

```bash
kubectl --context="$PLATFORM" get destination worker -o yaml
```

---

### 6. Install Argo CD

```bash
kubectl --context="$WORKER" create namespace argocd
kubectl --context="$WORKER" apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Verify pods and log in:

```bash
kubectl --context="$WORKER" -n argocd get pods
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

---

### 7. Configure Argo CD Connection to Git Repo

If your repo is private, apply this within the `argocd` namespace:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: kratix-git-repo
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  url: https://github.com/prphub/kratix-state.git
  username: <GIT_USERNAME>
  password: <GIT_PAT>
  type: git
  insecure: "true"
```

---

### 8. Deploy Argo CD Applications

Apply the following in the `argocd` namespace:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kratix-workload-dependencies
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/prphub/kratix-state.git
    targetRevision: HEAD
    path: worker/dependencies
    directory:
      recurse: true
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      selfHeal: true
      prune: true
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kratix-workload-resources
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/prphub/kratix-state.git
    targetRevision: HEAD
    path: worker/resources
    directory:
      recurse: true
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      selfHeal: true
      prune: true
```

Refer to the Kratix docs for suggested structure ([docs.kratix.io][1], [argo-cd.readthedocs.io][5]).

---

### 9. Install Jenkins Promise

```bash
export KRATIX_MARKETPLACE_REPO="https://raw.githubusercontent.com/syntasso/kratix-marketplace/main"
kubectl --context="$PLATFORM" apply -f "${KRATIX_MARKETPLACE_REPO}/jenkins/promise.yaml"
```

Confirm CRD:

```bash
kubectl --context="$PLATFORM" get crds | grep jenkins.marketplace.kratix.io
```

Confirm operator deployment appears via logs:
`kubectl --context="$WORKER" get pods -n default --watch`.

---

### 10. Verify Deployment

```bash
kubectl --context="$WORKER" get pods -n default
```

Expected:

* `jenkins-operator-…` (Running)
* `jenkins-dev-example` (Running)

This confirms successful end-to-end provisioning via Kratix and Argo CD.

---

## ✅ Summary

You now have a working local platform with:

1. **Kratix** for declarative platform control
2. **GitStateStore** leveraging GitHub for state storage
3. **Destination** labeled `dev`, enabling selective workload routing
4. **Argo CD**, syncing both dependencies and resources paths
5. **Jenkins Promise**, providing self-service Jenkins instances

---

## 📚 References

* Kratix Promise, Destination & GitStateStore details ([docs.kratix.io][6], [docs.kratix.io][2], [docs.kratix.io][7], [docs.kratix.io][8])
* Jenkins Promise installation flow
* Argo CD declarative setup guide ([argo-cd.readthedocs.io][5])

[1]: https://docs.kratix.io/main/reference/statestore/gitstatestore?utm_source=chatgpt.com "GitStateStore - Kratix"
[2]: https://docs.kratix.io/main/guides/installing-a-promise?utm_source=chatgpt.com "Installing and using a Promise - Kratix"
[3]: https://docs.kratix.io/main/guides/compound-promises?utm_source=chatgpt.com "Compound Promises - Kratix docs"
[4]: https://docs.kratix.io/main/reference/destinations/multidestination-management?utm_source=chatgpt.com "Managing Multiple Destinations - Kratix docs"
[5]: https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/?utm_source=chatgpt.com "Declarative Setup - Argo CD - Declarative GitOps CD for Kubernetes"
[6]: https://docs.kratix.io/workshop/installing-a-promise?utm_source=chatgpt.com "Section B: Installing a Promise - Kratix"
[7]: https://docs.kratix.io/main/reference/promises/intro?utm_source=chatgpt.com "Promise Custom Resource | Kratix"
[8]: https://docs.kratix.io/main/reference/destinations/intro?utm_source=chatgpt.com "Destination - Kratix docs"
