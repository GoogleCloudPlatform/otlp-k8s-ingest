# OpenTelemetry Collector Kubernetes Manifests

This directory contains clean, modular Kubernetes manifests for deploying the OpenTelemetry Collector targeting **Google Cloud Observability** (Cloud Trace, Cloud Monitoring, Cloud Logging).

---

## Directory Structure

* **`k8s/base/`**: The foundational manifests deploying the collector as a **Deployment** with a **Service**, **HPA**, and native support for both **GKE** and **On-Prem (WIF)**.
* **`k8s/gateway/`**: Reuses `k8s/base/` to deploy the collector configured specifically as a multi-replica ingestion **Gateway** (`replicas: 2`), inheriting namespace, RBAC, config, HPA, and WIF support.
* **`k8s/daemonset/`**: Reuses `k8s/base/` to deploy the collector as a **DaemonSet** (1 pod per node with `/var/log/pods` host mounts and node tolerations), inheriting namespace, RBAC, config, and WIF support.

```
k8s/
├── base/                       # Base Deployment + Service + HPA
│   ├── 0_namespace.yaml
│   ├── 1_configmap.yaml
│   ├── 2_rbac.yaml
│   ├── 3_service.yaml
│   ├── 4_deployment.yaml       # Deployment with WIF / GKE support
│   ├── 5_hpa.yaml              # HorizontalPodAutoscaler
│   └── kustomization.yml
│
├── gateway/                    # Reuses base, customized as a Gateway
│   ├── 4_gateway.yaml          # Gateway configuration (replicas: 2)
│   └── kustomization.yaml      # Inherits base
│
└── daemonset/                  # Reuses base, customized as a DaemonSet
    ├── 4_daemonset.yaml        # DaemonSet (runs on all nodes)
    └── kustomization.yaml      # Inherits base
```

---

## Project Tango / Control Plane Configuration

The collector runs with the `googlecontrolplane` configuration provider alongside a local configuration file:

```bash
/usr/bin/otelcol \
  --config "googlecontrolplane:xds://${CONTROL_PLANE_ADDRESS}?gcp.fleet_id=${FLEET_ID}&project=${OPTIONAL_PROJECT_ID}" \
  --config /etc/otelcol/config.yaml
```

* **Control Plane Address (`CONTROL_PLANE_ADDRESS`)**: The xDS endpoint for Telemetry Director (default: `telemetrydirector.googleapis.com`).
* **Fleet ID (`FLEET_ID`)**: The fleet identifier the collector subscribes to.
* **Destination Project (`OPTIONAL_PROJECT_ID`)**: Optional GCP project where telemetry is routed.
* **Config YAML (`/etc/otelcol/config.yaml`)**: Custom or default collector configuration.

### Supplying a Custom Config YAML File (Optional)

If not supplied, the built-in default configuration in `k8s/base/1_configmap.yaml` is used automatically. To supply your own custom `config.yaml`:

```bash
export CONFIG_FILE_PATH="/path/to/your/custom-config.yaml"

kubectl create configmap collector-config \
  --from-file=config.yaml="${CONFIG_FILE_PATH}" \
  -n opentelemetry --dry-run=client -o yaml | kubectl apply -f -
```

---

## Deploying on GKE (Default)

On GKE with Workload Identity enabled, no credentials file is needed. If no WIF file path is supplied, the collector automatically assumes GKE and authenticates via the GKE metadata server.

### 1. Set Required Environment Variables
```bash
export GOOGLE_CLOUD_PROJECT="<your-gcp-project-id>"
export PROJECT_NUMBER=$(gcloud projects describe ${GOOGLE_CLOUD_PROJECT} --format="value(projectNumber)")

# Tango Control Plane & Fleet settings
export CONTROL_PLANE_ADDRESS="telemetrydirector.googleapis.com"
export FLEET_ID="<your-fleet-id>"
export OPTIONAL_PROJECT_ID="${GOOGLE_CLOUD_PROJECT}"

# Grant IAM permissions to the Kubernetes ServiceAccount:
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

* **Base Deployment:**
  ```bash
  kubectl kustomize https://github.com/GoogleCloudPlatform/otlp-k8s-ingest.git/k8s/base | envsubst | kubectl apply -f -
  ```

* **Gateway Mode (Multi-Replica Ingestion Gateway):**
  ```bash
  kubectl kustomize https://github.com/GoogleCloudPlatform/otlp-k8s-ingest.git/k8s/gateway | envsubst | kubectl apply -f -
  ```

* **DaemonSet Mode (Per-Node Agent):**
  ```bash
  kubectl kustomize https://github.com/GoogleCloudPlatform/otlp-k8s-ingest.git/k8s/daemonset | envsubst | kubectl apply -f -
  ```

---

## Deploying On-Prem / Non-GKE with Workload Identity Federation (WIF)

For on-prem or non-GKE clusters, you do **not** need service account keys. Supply your generated `credential-configuration.json` file path.

### 1. Supply Your WIF File Path to Create the ConfigMap
```bash
export WIF_FILE_PATH="/path/to/credential-configuration.json"

kubectl create configmap gcp-wif-config \
  --from-file=credential-configuration.json="${WIF_FILE_PATH}" \
  -n opentelemetry --dry-run=client -o yaml | kubectl apply -f -
```

### 2. Set Environment Variables
```bash
export GOOGLE_CLOUD_PROJECT="<your-gcp-project-id>"
export PROJECT_NUMBER="<your-project-number>"
export POOL_ID="<your-pool-id>"
export PROVIDER_ID="<your-provider-id>"
export GOOGLE_APPLICATION_CREDENTIALS="/etc/gcp/credential-configuration.json"

# Tango Control Plane & Fleet settings
export CONTROL_PLANE_ADDRESS="telemetrydirector.googleapis.com"
export FLEET_ID="<your-fleet-id>"
export OPTIONAL_PROJECT_ID="${GOOGLE_CLOUD_PROJECT}"
```

### 3. Apply the Desired Mode

* **Base Deployment (with WIF):**
  ```bash
  kubectl kustomize https://github.com/GoogleCloudPlatform/otlp-k8s-ingest.git/k8s/base | envsubst | kubectl apply -f -
  ```

* **Gateway Mode (with WIF):**
  ```bash
  kubectl kustomize https://github.com/GoogleCloudPlatform/otlp-k8s-ingest.git/k8s/gateway | envsubst | kubectl apply -f -
  ```

* **DaemonSet Mode (with WIF):**
  ```bash
  kubectl kustomize https://github.com/GoogleCloudPlatform/otlp-k8s-ingest.git/k8s/daemonset | envsubst | kubectl apply -f -
  ```

---

## Upgrading the Collector Image Version

To update the collector image version at any time:

```bash
# For Base Deployment or Gateway:
kubectl set image deployment/opentelemetry-collector \
  opentelemetry-collector=us-docker.pkg.dev/my-project/collector:v0.2.0 \
  -n opentelemetry

# For DaemonSet:
kubectl set image daemonset/opentelemetry-collector \
  opentelemetry-collector=us-docker.pkg.dev/my-project/collector:v0.2.0 \
  -n opentelemetry
```
