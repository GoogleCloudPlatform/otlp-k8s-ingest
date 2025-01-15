# OTLP Kubernetes Ingest

This project contains Kubernetes manifests for self-deployed OTLP ingest on Kubernetes.

## Running on GKE

The recommended way to add the collector to your deployment is using `kubectl
apply`. If running on a GKE Autopilot cluster (or any cluster with Workload
Identity), you must follow the prerequisite steps to set up a Workload
Identity-enabled service account below. Otherwise, you can skip to the next
section.

### Workload Identity prequisites

Follow the [Workload Identity
docs](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity#authenticating_to)
to set up an IAM service account in your GCP project with permission to use
Workload Identity and write logs, traces, and metrics:

```console
export GCLOUD_PROJECT=<your project id>
```

Then run the following to create the service account with the appropriate permissions:
```console
gcloud iam service-accounts create opentelemetry-collector \
    --project=${GCLOUD_PROJECT}
gcloud projects add-iam-policy-binding ${GCLOUD_PROJECT} \
    --member "serviceAccount:opentelemetry-collector@${GCLOUD_PROJECT}.iam.gserviceaccount.com" \
    --role "roles/logging.logWriter"
gcloud projects add-iam-policy-binding ${GCLOUD_PROJECT} \
    --member "serviceAccount:opentelemetry-collector@${GCLOUD_PROJECT}.iam.gserviceaccount.com" \
    --role "roles/monitoring.metricWriter"
gcloud projects add-iam-policy-binding ${GCLOUD_PROJECT} \
    --member "serviceAccount:opentelemetry-collector@${GCLOUD_PROJECT}.iam.gserviceaccount.com" \
    --role "roles/cloudtrace.agent"
gcloud iam service-accounts add-iam-policy-binding opentelemetry-collector@${GCLOUD_PROJECT}.iam.gserviceaccount.com \
    --role roles/iam.workloadIdentityUser \
    --member "serviceAccount:${GCLOUD_PROJECT}.svc.id.goog[opentelemetry/opentelemetry-collector]" \
    --project ${GCLOUD_PROJECT}
```

### Install the manifests

First, make sure you have followed the Workload Identity setup steps above.

Then, apply the Kubernetes manifests directly from this repo:

```console
export GCP_REGION=<your region>
kubectl kustomize https://github.com/GoogleCloudPlatform/otlp-k8s-ingest/k8s/base?ref=otlpmetric | envsubst | kubectl apply -f -
```

(Remember to set the `GCLOUD_PROJECT` environment variable.)

### [Optional] Run the OpenTelemetry demo application alongside the collector

To test out and see the deployment in action, you can run the demo OpenTemetry application using
```console
kubectl apply  -f sample/.
```

### See Telemetry in Google Cloud Observability

Metrics, Log and Traces should be now available in your project in Cloud Observability.
You can see metrics under "Prometheus Target" in Cloud Monitoring.

### Observability of the OpenTelemetry Collector

In order to monitor the OpenTelemetry collector, you can deploy the dashboards available [here](https://github.com/GoogleCloudPlatform/monitoring-dashboard-samples/tree/master/dashboards/opentelemetry-collector).

You can import these dashboards by navigating to the Google Cloud Console and:

- Navigating to `Monitoring` > `Dashboards`
- Clicking on the `Sample Library` tab to find all available samples
- Clicking on the `OpenTelemetry Collector` category from the list
- Select and import the available dashboards

Once you import and apply the dashboard, you'll see several metrics tracking the uptime of the collector, its memory footprint and the API calls it makes to Cloud Observability:

![OpenTelemetry Collector Dashboard](/dashboard.png "OpenTelemetry Collector Dashboard")

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for details.

## License

Apache 2.0; see [`LICENSE`](LICENSE) for details.

## Disclaimer

This project is not an official Google project. It is not supported by
Google and Google specifically disclaims all warranties as to its quality,
merchantability, or fitness for a particular purpose.
