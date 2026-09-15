# OpenTelemetry Collector Kubernetes Manifests

This directory contains clean, modular Kubernetes manifests for deploying the OpenTelemetry Collector targeting **Google Cloud Observability** (Cloud Trace, Cloud Monitoring, Cloud Logging).

---

## Which directory do I apply?

Apply exactly **one** of `gateway/`, `daemonset/`, or `agent-gateway/`. They all create
resources with the same names in the same namespace, so they are alternatives, not
building blocks to combine. `base/` is machinery the others build on.

| Directory | Apply it? | What runs | Who talks to Google |
| --- | --- | --- | --- |
| **`base/`** | Rarely — it's the shared foundation | 1 collector Deployment | The Deployment |
| **`gateway/`** | Yes | A single HA collector tier (HPA floor 2) | The gateway |
| **`daemonset/`** | Yes | One collector per node, independent of each other | **Every node's collector** |
| **`agent-gateway/`** | Yes | One collector per node **plus** an HA gateway tier | Only the gateway |

### `gateway/` vs `agent-gateway/` — the common confusion

They are not two different gateways. **`agent-gateway/` is literally `gateway/` plus an agent
tier in front of it** — it lists `../gateway` as its base and adds exactly two objects (the
agent DaemonSet and its ConfigMap). The gateway tier the two produce is identical.

```
gateway/            workloads ─────────────────────────────▶ gateway ──▶ Google Cloud
                    (every pod sends to the gateway Service)

agent-gateway/      workloads ──▶ node-local agent ────────▶ gateway ──▶ Google Cloud
                    (pods send to their own node)
```

Pick `gateway/` for simplicity: one tier, fewer moving parts.

Pick `agent-gateway/` when you want the properties an agent tier buys you: telemetry leaves
the node it came from without a network hop first, a node's failure only affects that node,
and per-node batching reduces the connection count the gateway sees. The cost is roughly one
extra collector pod per node.

### `daemonset/` vs `agent-gateway/`

Both run a collector on every node; the difference is where the data goes next.

```
daemonset/          workloads ──▶ node collector ──▶ Google Cloud   (one egress per node)

agent-gateway/      workloads ──▶ node agent ──▶ gateway ──▶ Google Cloud   (one egress point)
```

`daemonset/` gives every node its own egress path and its own credentials. `agent-gateway/`
funnels everything through the gateway, which is usually what you want: a single place to
apply policy, a single set of credentials, and far fewer connections to Google.

```
k8s/
├── base/                       # Shared foundation: Deployment + Service + HPA + RBAC
│   ├── 0_namespace.yaml
│   ├── 1_configmap.yaml
│   ├── 2_rbac.yaml
│   ├── 3_service.yaml
│   ├── 4_deployment.yaml       # Deployment with WIF / GKE support
│   ├── 5_hpa.yaml              # HorizontalPodAutoscaler
│   └── kustomization.yml
│
├── gateway/                    # = base, made highly available
│   ├── 4_gateway.yaml          # component label + HPA minReplicas: 2
│   └── kustomization.yaml      # inherits ../base
│
├── daemonset/                  # = base, reshaped into a per-node DaemonSet
│   ├── 4_daemonset.yaml        # DaemonSet; exports straight to Google
│   └── kustomization.yaml      # inherits ../base, drops the Deployment + HPA
│
└── agent-gateway/              # = gateway, with a per-node agent tier in front
    ├── 1_agent_configmap.yaml  # generated from config/agent-collector.yaml
    ├── 4_agent_daemonset.yaml  # agent DaemonSet; forwards to the gateway Service
    └── kustomization.yaml      # inherits ../gateway
```

### Notes on `agent-gateway/`

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
