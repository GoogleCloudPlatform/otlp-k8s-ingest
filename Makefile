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

COLLECTOR_CONTRIB_VERSION=0.99.0

TOOLS = $(CURDIR)/.tools

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

.PHONY: generate
generate: tools
	$(KUBECTL) create configmap collector-config -n opentelemetry --from-file=./config/collector.yaml -o yaml --dry-run > ./k8s/base/1_configmap.yaml
	$(YQ) -n 'load("config/collector.yaml") * load("test/collector.yaml")' > k8s/overlays/test/collector.yaml
	cat test/fixtures/input.json | $(JQ) -c > k8s/overlays/test/fixture.json

.PHONY: test
test: tools
	$(KUBECTL) apply -k k8s/overlays/test
	while : ; do \
		$(KUBECTL) get pod/opentelemetry-collector-0 -n opentelemetry && break; \
		sleep 5; \
	done
	$(KUBECTL) wait --for=condition=Ready --timeout=60s pod/opentelemetry-collector-0 -n opentelemetry
	sleep 5
	$(KUBECTL) cp -c filecp opentelemetry/opentelemetry-collector-0:/output/output.json test/fixtures/tmp.json
	$(JQ) . test/fixtures/tmp.json > test/fixtures/expect.json
	rm test/fixtures/tmp.json
	$(KUBECTL) delete -k k8s/overlays/test

.PHONY: prettify-fixture
prettify-fixture: tools
	$(JQ) . test/fixtures/tmp.json > test/fixtures/expect.json
	rm test/fixtures/tmp.json

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
