IMAGE ?= miharekar/postgres-backup-s3
POSTGRES_VERSION ?= 18.1
SUFFIX ?=

TAG := $(POSTGRES_VERSION)$(SUFFIX)

.PHONY: build-push
buildx-init:
	docker buildx create --name multiarch --driver docker-container --use
	docker buildx inspect --bootstrap

.PHONY: build-push
build-push:
	@docker buildx inspect multiarch >/dev/null 2>&1 || docker buildx create --name multiarch --driver docker-container --use
	@docker buildx inspect --builder multiarch --bootstrap >/dev/null
	docker buildx build \
		--builder multiarch \
		--build-arg POSTGRES_VERSION=$(POSTGRES_VERSION) \
		--platform linux/amd64,linux/arm64 \
		-t $(IMAGE):$(TAG) \
		--push \
		.
