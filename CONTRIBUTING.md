# How to Contribute

We would love to accept your patches and contributions to this project.

## Before you begin

### Sign our Contributor License Agreement

Contributions to this project must be accompanied by a
[Contributor License Agreement](https://cla.developers.google.com/about) (CLA).
You (or your employer) retain the copyright to your contribution; this simply
gives us permission to use and redistribute your contributions as part of the
project.

If you or your current employer have already signed the Google CLA (even if it
was for a different project), you probably don't need to do it again.

Visit <https://cla.developers.google.com/> to see your current agreements or to
sign a new one.

### Review our Community Guidelines

This project follows [Google's Open Source Community
Guidelines](https://opensource.google/conduct/).

## Contribution process

### Code Reviews

All submissions, including submissions by project members, require review. We
use [GitHub pull requests](https://docs.github.com/articles/about-pull-requests)
for this purpose.

## File structure

There is one source of truth for each manifest, config, and test fixtures (see
Testing, below). Other instances of these files are generated from the source of
truth file.

### Collector configs

The production Collector config is located at
[`config/collector.yaml`](config/collector.yaml). To make changes to the config
that is deployed by users and tests, edit this file then run `make
generate`. This will update the Kustomize resource and the user-facing
ConfigMap.

The Collector config used for testing is located at
[`test/collector.yaml`](test/collector.yaml). The Kustomize resource and
manifests used with this config are also updated with `make generate`.

### K8s Manifests

Kubernetes manifests are managed by Kustomize resources (and overlays) in the
[`k8s/` directory](k8s/).

Kustomize also manages testing manifests, which add overlays on top of the base
manifests to do the following:

* Add the file receiver and exporter to the collector config
* Add the input fixtures as a ConfigMap value to be mounted by the Collector
* Mount the file fixtures in the collector deployment
* Update the collector deployment to a replicaset (for easier access via pod
  name in testing)

### Versioning

The manifest and collector version being used can be found in the `VERSION`
file. Do not update this file manually. Instead the following commands to update
the versions:
  - To update the collector version run `OTEL_COLLECTOR_VERSION=<otel collector version> make update-otel-version`
  - To update the manifests version run `VERSION=<manifests version> make update-manifests-version`

*Note: The manifests in this repository use the [Google Built OpenTelemetry Collector](https://github.com/GoogleCloudPlatform/opentelemetry-operations-collector/tree/master/google-built-opentelemetry-collector).*

## Testing

Fixture-based tests (deterministic input-output diff checking of signals) use
the same base manifests as the production deployment mode, except they are based
on fixed input data and write output data to a file.

The input and output fixtures are located at
[`test/fixtures`](test/fixtures). In this directory, they are stored in
user-readable (and git-diffable) JSONL format. The Makefile commands for testing
strip away the newlines into pure JSON format and write copies of the
un-prettified input files into the [`k8s/overlays/test`](k8s/overlays/test)
directory so that they can be merged into the base ConfigMap and consumed by the
OTLP JSON file receiver.

To generate the testing manifests, run `make generate`.

### Running tests

To run the test, connect to a GKE cluster (such as with `gcloud container
clusters get-credentials ...`). Then run `make test`.

The test will generate the testing manifests, deploy them to your cluster, wait
a few seconds for the fixture to be received and processed by the collector,
then copy the output to `test/fixtures` and prettify the file.
