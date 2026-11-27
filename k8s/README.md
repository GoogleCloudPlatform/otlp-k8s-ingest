# OpenTelemetry Collector Kubernetes Manifests

This directory contains clean, modular Kubernetes manifests for deploying the OpenTelemetry Collector targeting **Google Cloud Observability** (Cloud Trace, Cloud Monitoring, Cloud Logging).

---

## Which directory do I apply?

There are three choices. Apply exactly **one** — they create resources with the same names in
the same namespace, so they are alternatives, not building blocks to combine.

| Directory | What it deploys | Who talks to Google |
| --- | --- | --- |
| **`base/`** | A single collector. Workloads send OTLP straight to it. | The collector |
| **`gateway/`** | A per-node agent tier in front of a highly available gateway tier. | Only the gateway |
| **`daemonset/`** | One collector per node, each independent. | Every node's collector |

```
base/         workloads ──────────────────────────▶ collector ──▶ Google Cloud

gateway/      workloads ──▶ node-local agent ────▶ gateway ────▶ Google Cloud

daemonset/    workloads ──▶ node collector ──────────────────▶ Google Cloud
```

**`base/`** is the simplest thing that works, and it is also the foundation the other two build
on. Use it when one collector is enough.

**`gateway/`** is the OpenTelemetry-recommended production architecture. An agent on each node
receives that node's telemetry and forwards it to the gateway, which is the only tier holding
credentials and the only one connecting to Google. You get a single place to apply policy,
per-node batching, and far fewer connections to Google. The cost is roughly one extra collector
pod per node.

**`daemonset/`** also runs a collector per node, but each one exports to Google on its own.
Choose it when you specifically want no central tier; otherwise `gateway/` is usually the better
per-node option.

```
k8s/
├── base/                       # A single collector: Deployment + Service + HPA + RBAC
│   ├── 0_namespace.yaml
│   ├── 1_configmap.yaml
│   ├── 2_rbac.yaml
│   ├── 3_service.yaml
│   ├── 4_deployment.yaml       # Deployment with WIF / GKE support
│   ├── 5_hpa.yaml              # HorizontalPodAutoscaler
│   └── kustomization.yml
│
├── gateway/                    # Agent tier + gateway tier
│   ├── 1_agent_configmap.yaml  # generated from config/agent-collector.yaml
│   ├── 4_agent_daemonset.yaml  # per-node agent; forwards to the gateway Service
│   ├── 4_gateway.yaml          # makes the base Deployment the gateway (HPA floor 2)
│   └── kustomization.yaml      # inherits ../base
│
└── daemonset/                  # One collector per node, each exporting to Google
    ├── 4_daemonset.yaml
    └── kustomization.yaml      # inherits ../base, drops the Deployment + HPA
```

### Notes on the agent tier in `gateway/`

* The agent uses its own config (`config/agent-collector.yaml`), which runs `k8sattributes` in
  **passthrough** mode. This is required: without it the gateway would attribute all telemetry
  to the agent's pod IP — the IP of the connection it received the data on — rather than to the
  originating workload.
* The agent needs **no RBAC and no Google credentials**: it makes no Kubernetes API calls and
  never talks to Google.
* Agent names and labels are suffixed `-agent` so the gateway's Service selector cannot match
  agent pods, which would otherwise make agents forward to themselves.
* The agent exposes `hostPort` 4317/4318 so workloads can reach their node-local agent at
  `$(HOST_IP)`. **`hostPort` is rejected by GKE Autopilot and by restricted Pod Security
  Standards** — on those clusters, remove the `hostPort` fields and have workloads send to the
  gateway Service directly.

---

## Project Tango / Control Plane Configuration

The collector runs with the `googlecontrolplane` configuration provider alongside the built-in default configuration (`/conf/collector.yaml` mounted from `1_configmap.yaml`):

```bash
otelcol \
  --config "googlecontrolplane:xds://${CONTROL_PLANE_ADDRESS}?gcp.fleet_id=${FLEET_ID}&project=${OPTIONAL_PROJECT_ID}" \
  --config /conf/collector.yaml
```

* **Control Plane Address (`CONTROL_PLANE_ADDRESS`)**: The xDS endpoint for Telemetry Director (default: `telemetrydirector.googleapis.com`).
* **Fleet ID (`FLEET_ID`)**: The fleet identifier the collector subscribes to.
* **Destination Project (`OPTIONAL_PROJECT_ID`)**: Optional GCP project where telemetry is routed.

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
