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

.PHONY: test
test: generate-test
	kubectl apply -f collector/.
	while : ; do \
		kubectl get pod/opentelemetry-collector-0 -n opentelemetry && break; \
		sleep 5; \
	done
	kubectl wait --for=condition=Ready --timeout=60s pod/opentelemetry-collector-0 -n opentelemetry
	sleep 5
	kubectl cp -c filecp opentelemetry/opentelemetry-collector-0:/output/output.json test/fixtures/tmp.json
	jq . test/fixtures/tmp.json > test/fixtures/expect.json
	rm test/fixtures/tmp.json
	kubectl delete -f collector/.
