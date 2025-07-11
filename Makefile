# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

include VERSION

TOOLS = $(CURDIR)/.tools

YAMLLINT_VERSION=1.30.0

$(TOOLS):
	mkdir -p $@

YQ = $(TOOLS)/yq
$(TOOLS)/yq: $(TOOLS)
	curl -L https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -o yq_linux_amd64 && \
	chmod +x ./yq_linux_amd64 && \
	mv ./yq_linux_amd64 $(TOOLS)/yq

JQ = $(TOOLS)/jq
$(TOOLS)/jq: $(TOOLS)
	curl -L https://github.com/jqlang/jq/releases/latest/download/jq-linux-amd64 -o jq-linux-amd64 && \
	chmod +x ./jq-linux-amd64 && \
	mv ./jq-linux-amd64 $(TOOLS)/jq


KUBECTL = $(TOOLS)/kubectl
$(TOOLS)/kubectl: $(TOOLS)
	curl -LO "https://dl.k8s.io/release/$(shell curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
	chmod +x ./kubectl && \
	mv ./kubectl $(TOOLS)/

.PHONY: tools
tools: $(JQ) $(YQ) $(KUBECTL)

OTEL_COLLECTOR_VERSION ?= $(GBOC_VERSION)
.PHONY: update-otel-version
update-otel-version:
	sed -i "s|OpenTelemetry Collector Built By Google/[0-9.]\+|OpenTelemetry Collector Built By Google/$(OTEL_COLLECTOR_VERSION)|g" config/*; \
	sed -i "s|GBOC_VERSION=[0-9.]\+|GBOC_VERSION=$(OTEL_COLLECTOR_VERSION)|g" VERSION; \
	$(MAKE) generate; \
	sed -i "s|app.kubernetes.io/version: \"[0-9.]\+\"|app.kubernetes.io/version: \"$(OTEL_COLLECTOR_VERSION)\"|g" k8s/base/*; \
	sed -i "s|us-docker.pkg.dev/cloud-ops-agents-artifacts/google-cloud-opentelemetry-collector/otelcol-google:[0-9.]\+|us-docker.pkg.dev/cloud-ops-agents-artifacts/google-cloud-opentelemetry-collector/otelcol-google:$(OTEL_COLLECTOR_VERSION)|g" k8s/base/*; \
	sed -i "s|OpenTelemetry Collector Built By Google/[0-9.]\+|OpenTelemetry Collector Built By Google/$(OTEL_COLLECTOR_VERSION)|g" k8s/base/*;

VERSION ?= $(MANIFESTS_VERSION)
.PHONY: update-manifests-version
update-manifests-version:
	sed -i "s|manifests:[0-9.]\+|manifests:$(VERSION)|g" config/*; \
	sed -i "s|MANIFESTS_VERSION=[0-9.]\+|MANIFESTS_VERSION=$(VERSION)|g" VERSION; \
	$(MAKE) generate

.PHONY: generate
generate: tools
	$(KUBECTL) create configmap collector-config -n opentelemetry --from-file=./config/collector.yaml -o yaml --dry-run > ./k8s/base/1_configmap.yaml
	$(YQ) -n 'load("config/collector.yaml") * load("test/collector.yaml")' > k8s/overlays/test/collector.yaml
	cat test/fixtures/spans_input.json | $(JQ) -c > k8s/overlays/test/spans_fixture.json
	cat test/fixtures/metrics_input.json | $(JQ) -c > k8s/overlays/test/metrics_fixture.json
	cat test/fixtures/logs_input.json | $(JQ) -c > k8s/overlays/test/logs_fixture.json

.PHONY: test
test: tools
	$(KUBECTL) kustomize k8s/overlays/test | envsubst | kubectl apply -f -
	while : ; do \
		$(KUBECTL) get pod/opentelemetry-collector-0 -n opentelemetry && break; \
		sleep 5; \
	done
	$(KUBECTL) wait --for=condition=Ready --timeout=60s pod/opentelemetry-collector-0 -n opentelemetry
	# sleep long enough for self-observability metrics to be scraped once
	sleep 60
	$(KUBECTL) cp -c filecp opentelemetry/opentelemetry-collector-0:/output/spans_output.json test/fixtures/spans_output.json
	$(KUBECTL) cp -c filecp opentelemetry/opentelemetry-collector-0:/output/metrics_output.json test/fixtures/metrics_output.json
	$(KUBECTL) cp -c filecp opentelemetry/opentelemetry-collector-0:/output/self_metrics_output.json test/fixtures/self_metrics_output.json
	$(KUBECTL) cp -c filecp opentelemetry/opentelemetry-collector-0:/output/logs_output.json test/fixtures/logs_output.json
	$(JQ) . test/fixtures/spans_output.json > test/fixtures/spans_expect.json
	$(JQ) . test/fixtures/metrics_output.json > test/fixtures/metrics_expect.json
	$(JQ) . test/fixtures/self_metrics_output.json > test/fixtures/self_metrics_expect.json
	$(JQ) . test/fixtures/logs_output.json > test/fixtures/logs_expect.json
	rm test/fixtures/spans_output.json
	rm test/fixtures/metrics_output.json
	rm test/fixtures/self_metrics_output.json
	rm test/fixtures/logs_output.json
	$(KUBECTL) logs opentelemetry-collector-0 -n opentelemetry
	$(KUBECTL) delete -k k8s/overlays/test

.PHONY: prettify-fixture
prettify-fixture: tools
	$(JQ) . test/fixtures/spans_output.json > test/fixtures/spans_expect.json
	rm test/fixtures/spans_output.json
	$(JQ) . test/fixtures/metrics_output.json > test/fixtures/metrics_expect.json
	rm test/fixtures/metrics_output.json
	$(JQ) . test/fixtures/self_metrics_output.json > test/fixtures/self_metrics_expect.json
	rm test/fixtures/self_metrics_output.json
	$(JQ) . test/fixtures/logs_output.json > test/fixtures/logs_expect.json
	rm test/fixtures/logs_output.json

.PHONY: check-clean-work-tree
check-clean-work-tree:
	@if ! git diff --quiet; then \
	  echo; \
	  echo 'Working tree is not clean, did you forget to run "make generate"?'; \
	  echo; \
	  git status; \
	  git diff; \
	  exit 1; \
	fi

.PHONY: install-yamllint
install-yamllint:
    # Using a venv is recommended
	yamllint --version >/dev/null 2>&1 || pip install -U yamllint~=$(YAMLLINT_VERSION)

.PHONY: yamllint
yamllint: install-yamllint
	yamllint .
