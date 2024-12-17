
.PHONY: help

TAG	?= 4.5.4
CI_TAG ?= ci
HUB	?= quay.io/3scale
IMAGE	?= quay.io/3scale/soyuz
CONTAINER_TOOL ?= podman

help:
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null \
		| awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' \
		| egrep -v -e '^[^[:alnum:]]' -e '^$@$$' | sort

get-new-release:
	@hack/new-release.sh v$(TAG)

build-all-release: build build-$(CI_TAG)

push-all-release: push push-$(CI_TAG)

build-all-latest: build-latest build-$(CI_TAG)-latest

push-all-latest: push-latest push-$(CI_TAG)-latest

build-all: build build-ci

build:
	${CONTAINER_TOOL} manifest rm $(IMAGE):$(TAG) || echo "No manifest found"
	${CONTAINER_TOOL} manifest create $(IMAGE):$(TAG)
	${CONTAINER_TOOL} build \
		--platform linux/amd64,linux/arm64 \
		--manifest $(IMAGE):$(TAG) . -f Dockerfile

push:
	${CONTAINER_TOOL} manifest push $(IMAGE):$(TAG)

build-latest: build
	${CONTAINER_TOOL} tag $(IMAGE):$(TAG) $(IMAGE):latest

push-latest: build-latest
	${CONTAINER_TOOL} push $(IMAGE):latest

build-$(CI_TAG):
	${CONTAINER_TOOL} manifest rm $(IMAGE):$(TAG)-$(CI_TAG) || echo "No manifest found"
	${CONTAINER_TOOL} manifest create $(IMAGE):$(TAG)-$(CI_TAG)
	${CONTAINER_TOOL} build \
		--platform linux/amd64,linux/arm64 \
		--manifest $(IMAGE):$(TAG)-$(CI_TAG) . -f Dockerfile-$(CI_TAG)

push-$(CI_TAG): build-$(CI_TAG)
	${CONTAINER_TOOL} manifest push $(IMAGE):$(TAG)-$(CI_TAG)

build-$(CI_TAG)-latest: build-$(CI_TAG)
	${CONTAINER_TOOL} tag $(IMAGE):$(TAG)-$(CI_TAG) $(IMAGE):latest-$(CI_TAG)

push-$(CI_TAG)-latest: build-$(CI_TAG)-latest
	${CONTAINER_TOOL} push $(IMAGE):latest-$(CI_TAG)
