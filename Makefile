NAME := tekton-pipeline
CHART_DIR := charts/${NAME}
CHART_VERSION ?= latest

CHART_REPO := gs://jenkinsxio/charts

ifeq ($(CHART_VERSION),latest)
	CHART_MANIFEST_URL := https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml
else
	CHART_MANIFEST_URL := https://storage.googleapis.com/tekton-releases/pipeline/previous/v${CHART_VERSION}/release.yaml
endif

fetch:
	rm -f ${CHART_DIR}/templates/*.yaml
	mkdir -p ${CHART_DIR}/templates
	shell curl -sS ${CHART_MANIFEST_URL} | python split_yaml.py ${CHART_DIR}/templates
	# move content of data: from feature-slags-cm.yaml to featureFlags: in values.yaml
	yq -i '.featureFlags = load("$(CHART_DIR)/templates/feature-flags-cm.yaml").data' $(CHART_DIR)/values.yaml
	yq -i '.data = null' $(CHART_DIR)/templates/feature-flags-cm.yaml
	# move content of data: from config-defaults-cm.yaml to configDefaults: in values.yaml
	yq -i '.configDefaults = load("$(CHART_DIR)/templates/config-defaults-cm.yaml").data' $(CHART_DIR)/values.yaml
	yq -i '.data = null' $(CHART_DIR)/templates/config-defaults-cm.yaml
	# kustomize the resources to include some helm template blocs
	shell kustomize build ${CHART_DIR} | sed '/helmTemplateRemoveMe/d' | python split_yaml.py ${CHART_DIR}/templates
	cp src/templates/* ${CHART_DIR}/templates
ifneq ($(CHART_VERSION),latest)
	sed -i "s/^appVersion:.*/appVersion: ${CHART_VERSION}/" ${CHART_DIR}/Chart.yaml
	sed -Ei '/(version|release):/{s/v'${CHART_VERSION}'/v{{ .Chart.AppVersion }}/}' ${CHART_DIR}/templates/*.yaml
endif

build:
	rm -rf Chart.lock
	#helm dependency build
	helm lint ${NAME}

install: clean build
	helm install . --name ${NAME}

upgrade: clean build
	helm upgrade ${NAME} .

delete:
	helm delete --purge ${NAME}

clean:

release: clean
	sed -i -e "s/version:.*/version: $(VERSION)/" Chart.yaml

	helm dependency build
	helm lint
	helm package .
	helm repo add jx-labs $(CHART_REPO)
	helm gcs push ${NAME}*.tgz jx-labs --public
	rm -rf ${NAME}*.tgz%

test:
	cd tests && go test -v

test-regen:
	cd tests && export HELM_UNIT_REGENERATE_EXPECTED=true && go test -v


verify:
	jx kube test run
