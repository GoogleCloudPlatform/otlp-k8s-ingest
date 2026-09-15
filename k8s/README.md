# OpenTelemetry Collector Kubernetes Manifests

This directory contains modular, production-ready Kubernetes manifests for self-deployed OpenTelemetry Collectors targeting **Google Cloud Observability** (Cloud Trace, Cloud Monitoring, Cloud Logging).

The manifests support:
* **3 Deployment Modes**: Gateway (autoscaling), Deployment (fixed replica), and DaemonSet (per-node agent).
* **Both Environments**: GKE (native Workload Identity) and Any Kubernetes / On-Prem (Workload Identity Federation).
* **Zero Keys**: Fully keyless authentication via Workload Identity / WIF.

---

## Deployment Matrix

| Mode | Environment | Manifest Target | Description |
| :--- | :--- | :--- | :--- |
| **Gateway** | GKE | `k8s/gateway/gke` | Deployment + Service + HPA (autoscales 1-10 replicas based on CPU/memory) |
| **Gateway** | Any K8s / WIF | `k8s/gateway/wif` | Same as above with keyless Workload Identity Federation |
| **Deployment** | GKE | `k8s/deployment/gke` | Standalone Deployment + Service (fixed replicas, no HPA dependency) |
| **Deployment** | Any K8s / WIF | `k8s/deployment/wif` | Standalone Deployment with Workload Identity Federation |
| **DaemonSet** | GKE | `k8s/daemonset/gke` | Per-node agent with host log mounts and node tolerations |
| **DaemonSet** | Any K8s / WIF | `k8s/daemonset/wif` | Per-node agent with Workload Identity Federation |

---

## Prerequisites

### 1. For GKE Deployments
Ensure GKE Workload Identity is configured:
```bash
export GOOGLE_CLOUD_PROJECT="<your-gcp-project-id>"
export PROJECT_NUMBER=$(gcloud projects describe ${GOOGLE_CLOUD_PROJECT} --format="value(projectNumber)")

# Grant permissions to the Kubernetes ServiceAccount via GKE Workload Identity Pool:
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

### 2. For Any K8s / On-Prem Deployments (Workload Identity Federation)
Ensure your cluster has a Google Cloud Workload Identity Pool and Provider configured (no service account keys required):
```bash
export GOOGLE_CLOUD_PROJECT="<your-gcp-project-id>"
export PROJECT_NUMBER="<your-project-number>"
export POOL_ID="<your-workload-identity-pool-id>"
export PROVIDER_ID="<your-workload-identity-provider-id>"
export GCP_SERVICE_ACCOUNT="<collector-gcp-sa>@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com"
```

---

## Installation Commands

### 1. Gateway Mode (Central Scalable Ingestion)
Best for high-volume OTLP ingestion from multiple application workloads.

* **On GKE:**
  ```bash
  kubectl kustomize https://github.com/GoogleCloudPlatform/otlp-k8s-ingest.git/k8s/gateway/gke | envsubst | kubectl apply -f -
  ```
* **On Any K8s / On-Prem (WIF):**
  ```bash
  kubectl kustomize https://github.com/GoogleCloudPlatform/otlp-k8s-ingest.git/k8s/gateway/wif | envsubst | kubectl apply -f -
  ```

---

### 2. Deployment Mode (Standalone)
Best for testing, dev/staging clusters, or environments without a metrics-server / HPA installed.

* **On GKE:**
  ```bash
  kubectl kustomize https://github.com/GoogleCloudPlatform/otlp-k8s-ingest.git/k8s/deployment/gke | envsubst | kubectl apply -f -
  ```
* **On Any K8s / On-Prem (WIF):**
  ```bash
  kubectl kustomize https://github.com/GoogleCloudPlatform/otlp-k8s-ingest.git/k8s/deployment/wif | envsubst | kubectl apply -f -
  ```

---

### 3. DaemonSet Mode (Per-Node Agent)
Best for host metrics, node logs (`/var/log/pods`), and node-local OTLP collection.

* **On GKE:**
  ```bash
  kubectl kustomize https://github.com/GoogleCloudPlatform/otlp-k8s-ingest.git/k8s/daemonset/gke | envsubst | kubectl apply -f -
  ```
* **On Any K8s / On-Prem (WIF):**
  ```bash
  kubectl kustomize https://github.com/GoogleCloudPlatform/otlp-k8s-ingest.git/k8s/daemonset/wif | envsubst | kubectl apply -f -
  ```

---

## Customizing Collector Image and Version

The manifests default to the verified Google-built OpenTelemetry Collector release.

To update or specify a custom collector image (e.g., custom Tango xDS collector distribution):

```bash
# For Gateway or Deployment:
kubectl set image deployment/opentelemetry-collector \
  opentelemetry-collector=us-docker.pkg.dev/my-project/collector:v0.1.0 \
  -n opentelemetry

# For DaemonSet:
kubectl set image daemonset/opentelemetry-collector \
  opentelemetry-collector=us-docker.pkg.dev/my-project/collector:v0.1.0 \
  -n opentelemetry
```

---

## Customizing Configuration

The collector configuration is stored in the `collector-config` ConfigMap in the `opentelemetry` namespace. To apply a custom configuration:

```bash
kubectl create configmap collector-config \
  --namespace opentelemetry \
  --from-file=collector.yaml=my-config.yaml \
  --dry-run=client -o yaml | kubectl apply -f -

# Graceful rolling restart:
kubectl rollout restart deployment/opentelemetry-collector -n opentelemetry
# Or for DaemonSet:
kubectl rollout restart daemonset/opentelemetry-collector -n opentelemetry
```
