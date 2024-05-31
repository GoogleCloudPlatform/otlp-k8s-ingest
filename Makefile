COLLECTOR_CONTRIB_VERSION=0.99.0

.PHONY: generate
generate:
	kubectl create configmap collector-config -n opentelemetry --from-file=./config/collector.yaml -o yaml --dry-run > ./k8s/base/1_configmap.yaml
	yq -n 'load("config/collector.yaml") * load("test/collector.yaml")' > k8s/overlays/test/collector.yaml
	cat test/fixtures/input.json | jq -c > k8s/overlays/test/fixture.json
	kubectl kustomize k8s/base > collector/collector.yaml

.PHONY: generate-test
generate-test: generate
	kubectl kustomize k8s/overlays/test > collector/collector.yaml
