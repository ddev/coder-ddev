# Makefile for building and pushing coder-ddev Docker image and templates

# Configuration
IMAGE_NAME := ddev/coder-ddev
VERSION := $(shell cat VERSION 2>/dev/null || echo "1.0.0-beta1")
DOCKERFILE_DIR := image
DOCKERFILE := $(DOCKERFILE_DIR)/Dockerfile

# Template directories (name == directory name == Coder template name)
TEMPLATES := user-defined-web drupal-core freeform

# Host path to the drupal-core seed cache (bind-mounted read-only into workspaces).
# This path is specific to the server where the template is deployed.
# Override with: make push-template-drupal-core DRUPAL_CACHE_PATH=/other/path/drupal-core-seed
DRUPAL_CACHE_PATH ?= /home/rfay/cache/drupal-core-seed

# Full image tag
IMAGE_TAG := $(IMAGE_NAME):$(VERSION)
IMAGE_LATEST := $(IMAGE_NAME):latest

# Per-template extra variables passed to `coder templates push`
TEMPLATE_VARS_user-defined-web := --variable workspace_image_registry=index.docker.io/$(IMAGE_NAME)
TEMPLATE_VARS_drupal-core      := --variable workspace_image_registry=index.docker.io/$(IMAGE_NAME) \
                                   --variable cache_path=$(DRUPAL_CACHE_PATH)
TEMPLATE_VARS_freeform         := --variable workspace_image_registry=index.docker.io/$(IMAGE_NAME)

# Per-template display metadata set via `coder templates edit` after push
# (coder templates push only supports --name, not --description)
TEMPLATE_EDIT_user-defined-web := --display-name "DDEV Web Workspace"
TEMPLATE_EDIT_drupal-core      := --display-name "Drupal Core Development" \
                                   --description "Drupal core dev environment: full DDEV stack, core clone, Umami demo site. Ready in ~30 seconds."
TEMPLATE_EDIT_freeform         := --display-name "DDEV Freeform (Traefik)"

# Shared recipe for pushing any template (call with template name as argument)
define push_template
	@echo "Syncing VERSION to $(1)..."
	cp VERSION $(1)/VERSION
	@echo "Pushing Coder template $(1)..."
	coder templates push --directory $(1) $(1) --yes $(TEMPLATE_VARS_$(1))
	@echo "Setting template metadata for $(1)..."
	coder templates edit $(1) --yes $(TEMPLATE_EDIT_$(1))
	@echo "Template $(1) push complete"
endef

# Default target
.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help message
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-42s %s\n", $$1, $$2}'

.PHONY: build
build: ## Build Docker image with cache
	@echo "Building $(IMAGE_TAG)..."
	docker build -t $(IMAGE_TAG) -t $(IMAGE_LATEST) $(DOCKERFILE_DIR)
	@echo "Build complete: $(IMAGE_TAG)"

.PHONY: build-no-cache
build-no-cache: ## Build Docker image without cache
	@echo "Building $(IMAGE_TAG) without cache..."
	docker build --no-cache -t $(IMAGE_TAG) -t $(IMAGE_LATEST) $(DOCKERFILE_DIR)
	@echo "Build complete: $(IMAGE_TAG)"

.PHONY: push
push: ## Push Docker image to registry
	@echo "Pushing $(IMAGE_TAG)..."
	docker push $(IMAGE_TAG)
	@echo "Pushing $(IMAGE_LATEST)..."
	docker push $(IMAGE_LATEST)
	@echo "Push complete"

.PHONY: build-and-push
build-and-push: build push ## Build and push Docker image with cache

.PHONY: build-and-push-no-cache
build-and-push-no-cache: build-no-cache push ## Build and push Docker image without cache

.PHONY: login
login: ## Login to Docker registry
	@echo "Logging in to Docker Hub..."
	docker login

.PHONY: test
test: ## Test the built image by running it
	@echo "Testing $(IMAGE_TAG)..."
	docker run --rm $(IMAGE_TAG) ddev --version
	docker run --rm $(IMAGE_TAG) docker --version
	docker run --rm $(IMAGE_TAG) node --version
	@echo "Test complete"

.PHONY: clean
clean: ## Remove local image
	@echo "Removing local images..."
	docker rmi $(IMAGE_TAG) $(IMAGE_LATEST) 2>/dev/null || true
	@echo "Clean complete"

.PHONY: info
info: ## Show image and template information
	@echo "Version:        $(VERSION)"
	@echo "Image Name:     $(IMAGE_NAME)"
	@echo "Image Tag:      $(IMAGE_TAG)"
	@echo "Latest Tag:     $(IMAGE_LATEST)"
	@echo "Dockerfile:     $(DOCKERFILE)"
	@echo "Templates:      $(TEMPLATES)"

# --- Template push targets ---

.PHONY: push-template-user-defined-web
push-template-user-defined-web: ## Push user-defined-web template to Coder
	$(call push_template,user-defined-web)

.PHONY: push-template-drupal-core
push-template-drupal-core: ## Push drupal-core template to Coder
	$(call push_template,drupal-core)

.PHONY: push-template-freeform
push-template-freeform: ## Push freeform template to Coder
	$(call push_template,freeform)

# --- Deploy targets ---

.PHONY: deploy-user-defined-web
deploy-user-defined-web: build-and-push push-template-user-defined-web ## Build image, push image, and push user-defined-web template
	@echo "Deployment of user-defined-web complete!"

.PHONY: deploy-user-defined-web-no-cache
deploy-user-defined-web-no-cache: build-and-push-no-cache push-template-user-defined-web ## Build image (no cache), push, and push user-defined-web template
	@echo "Deployment of user-defined-web complete!"

.PHONY: deploy-drupal-core
deploy-drupal-core: push-template-drupal-core ## Deploy drupal-core template (uses existing image)
	@echo "Deployment of drupal-core complete!"

.PHONY: deploy-freeform
deploy-freeform: push-template-freeform ## Deploy freeform template (uses existing image)
	@echo "Deployment of freeform complete!"

.PHONY: deploy-all
deploy-all: deploy-user-defined-web push-template-drupal-core push-template-freeform ## Deploy image and all templates
	@echo "All templates deployed!"
