# OTLP Kubernetes Ingest

This project contains Kubernetes manifests for self-deployed OTLP ingest on Kubernetes.

## Running on GKE

Before we begin, set required environment variables:
```console
export GOOGLE_CLOUD_PROJECT=<your project id>
export PROJECT_NUMBER=$(gcloud projects describe ${GOOGLE_CLOUD_PROJECT} --format="value(projectNumber)")
```

### Configure IAM Permissions

**You can skip this step if you have disabled GKE workload identity in your cluster.**

Follow the [Workload Identity
docs](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)
to allow the collector's kubernetes service account to write logs, traces, and metrics:

```console
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

### Install the manifests

First, make sure you have followed the Workload Identity setup steps above.

Then, apply the Kubernetes manifests directly from this repo:

```console
kubectl kustomize https://github.com/GoogleCloudPlatform/otlp-k8s-ingest/k8s/base | envsubst | kubectl apply -f -
```

(Remember to set the `GOOGLE_CLOUD_PROJECT` environment variable.)

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
