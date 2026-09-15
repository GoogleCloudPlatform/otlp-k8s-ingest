# OpenTelemetry Collector Kubernetes Manifests

This directory contains clean, modular Kubernetes manifests for deploying the OpenTelemetry Collector targeting **Google Cloud Observability** (Cloud Trace, Cloud Monitoring, Cloud Logging).

The manifests support:
* **3 Deployment Modes**:
  * **Gateway** (`k8s/gateway`): Multi-replica ingestion gateway exposed via a Kubernetes Service.
  * **Deployment** (`k8s/deployment`): Standalone collector deployment with a single replica.
  * **DaemonSet** (`k8s/daemonset`): Per-node collector agent mounting `/var/log/pods` with node tolerations.
* **Both Environments**:
  * **GKE**: Native Workload Identity via GKE metadata server.
  * **Any K8s / On-Prem**: Keyless Workload Identity Federation (WIF) pointing directly to your `credential-configuration.json` file.
* **No Autoscaling**: Explicitly does not deploy any HorizontalPodAutoscaler (HPA).

---

## Directory Structure

Every mode directory uses standard, predictable numbered file naming:

```
k8s/
├── gateway/
│   ├── 0_namespace.yaml
│   ├── 1_configmap.yaml
│   ├── 2_rbac.yaml
│   ├── 3_service.yaml
│   ├── 4_gateway.yaml          # Deployment (replicas: 2)
│   ├── 5_wif.yaml              # WIF patch for non-GKE clusters
│   └── kustomization.yaml
│
├── deployment/
│   ├── 0_namespace.yaml
│   ├── 1_configmap.yaml
│   ├── 2_rbac.yaml
│   ├── 3_service.yaml
│   ├── 4_deployment.yaml       # Deployment (replicas: 1)
│   ├── 5_wif.yaml              # WIF patch for non-GKE clusters
│   └── kustomization.yaml
│
└── daemonset/
    ├── 0_namespace.yaml
    ├── 1_configmap.yaml
    ├── 2_rbac.yaml
    ├── 3_service.yaml
    ├── 4_daemonset.yaml        # DaemonSet (runs on all nodes)
    ├── 5_wif.yaml              # WIF patch for non-GKE clusters
    └── kustomization.yaml
```

---

## Deploying on GKE (Default)

On GKE with Workload Identity enabled, no credentials file is needed.

### 1. Set Environment Variables
```bash
export GOOGLE_CLOUD_PROJECT="<your-gcp-project-id>"
export PROJECT_NUMBER=$(gcloud projects describe ${GOOGLE_CLOUD_PROJECT} --format="value(projectNumber)")

# Grant IAM permissions to the collector's Kubernetes ServiceAccount:
gcloud projects add-iam-policy-binding projects/$GOOGLE_CLOUD_PROJECT \
    --role=roles/logging.logWriter \
    --member=principal://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$GOOGLE_CLOUD_PROJECT.svc.id.goog/subject/ns/opentelemetry/sa/opentelemetry-collector \
    --condition=None
gcloud projects add-iam-policy-binding projects/$GOOGLE_CLOUD_PROJECT \
    --role=roles/monitoring.metricWriter \
    --member=principal://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$GOOGLE_CLOUD_PROJECT.svc.id.goog/subject/ns/opentelemetry/sa/opentelemetry-collector \
    --condition=None
gcloud projects add-iam-policy-binding projects/$GOOGLE_CLOUD_PROJECT \
    --role=roles/cloudtrace.agent \
    --member=principal://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$GOOGLE_CLOUD_PROJECT.svc.id.goog/subject/ns/opentelemetry/sa/opentelemetry-collector \
    --condition=None
```

### 2. Apply the Manifests

* **Gateway Mode:**
  ```bash
  kubectl kustomize https://github.com/GoogleCloudPlatform/otlp-k8s-ingest.git/k8s/gateway | envsubst | kubectl apply -f -
  ```

* **Deployment Mode:**
  ```bash
  kubectl kustomize https://github.com/GoogleCloudPlatform/otlp-k8s-ingest.git/k8s/deployment | envsubst | kubectl apply -f -
  ```

* **DaemonSet Mode:**
  ```bash
  kubectl kustomize https://github.com/GoogleCloudPlatform/otlp-k8s-ingest.git/k8s/daemonset | envsubst | kubectl apply -f -
  ```

---

## Deploying on Any K8s / On-Prem with Workload Identity Federation (WIF)

For non-GKE clusters, you do **not** need service account keys. Point directly to your generated `credential-configuration.json` file.

### 1. Create the ConfigMap Pointing to Your WIF File
Point to the path of your WIF credential file:
```bash
export WIF_FILE_PATH="/path/to/credential-configuration.json"

kubectl create configmap gcp-wif-config \
  --from-file=credential-configuration.json="${WIF_FILE_PATH}" \
  -n opentelemetry --dry-run=client -o yaml | kubectl apply -f -
```

### 2. Apply the Manifests with the WIF Patch (`5_wif.yaml`)

Set your Workload Identity Pool / Provider audience:
```bash
export GOOGLE_CLOUD_PROJECT="<your-gcp-project-id>"
export PROJECT_NUMBER="<your-project-number>"
export POOL_ID="<your-pool-id>"
export PROVIDER_ID="<your-provider-id>"
```

* **Gateway Mode with WIF:**
  ```bash
  kubectl kustomize https://github.com/GoogleCloudPlatform/otlp-k8s-ingest.git/k8s/gateway | envsubst | kubectl apply -f -
  envsubst < k8s/gateway/5_wif.yaml | kubectl apply -f -
  ```

* **Deployment Mode with WIF:**
  ```bash
  kubectl kustomize https://github.com/GoogleCloudPlatform/otlp-k8s-ingest.git/k8s/deployment | envsubst | kubectl apply -f -
  envsubst < k8s/deployment/5_wif.yaml | kubectl apply -f -
  ```

* **DaemonSet Mode with WIF:**
  ```bash
  kubectl kustomize https://github.com/GoogleCloudPlatform/otlp-k8s-ingest.git/k8s/daemonset | envsubst | kubectl apply -f -
  envsubst < k8s/daemonset/5_wif.yaml | kubectl apply -f -
  ```

Alternatively, when customizing locally with Kustomize, you can specify your WIF file path in `kustomization.yaml`:
```yaml
configMapGenerator:
  - name: gcp-wif-config
    files:
      - credential-configuration.json=/path/to/credential-configuration.json

patches:
  - path: 5_wif.yaml
```

---

## Upgrading the Collector Image

To upgrade the collector version without modifying YAML files:

```bash
# For Gateway or Deployment:
kubectl set image deployment/opentelemetry-collector \
  opentelemetry-collector=us-docker.pkg.dev/my-project/collector:v0.2.0 \
  -n opentelemetry

# For DaemonSet:
kubectl set image daemonset/opentelemetry-collector \
  opentelemetry-collector=us-docker.pkg.dev/my-project/collector:v0.2.0 \
  -n opentelemetry
```
