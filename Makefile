# Makefile for building and pushing coder-ddev Docker image and templates

# Configuration
IMAGE_NAME := ddev/coder-ddev
VERSION := $(shell cat VERSION 2>/dev/null || echo "1.0.0-beta1")
DOCKERFILE_DIR := image
DOCKERFILE := $(DOCKERFILE_DIR)/Dockerfile

# Template directories (name == directory)
DDEV_USER_DIR          := ddev-user
DDEV_DRUPAL_CORE_DIR   := ddev-drupal-core

# Full image tag
IMAGE_TAG := $(IMAGE_NAME):$(VERSION)
IMAGE_LATEST := $(IMAGE_NAME):latest

# Default target
.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help message
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-30s %s\n", $$1, $$2}'

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
	@echo "Templates:      $(DDEV_USER_DIR) $(DDEV_DRUPAL_CORE_DIR)"

.PHONY: push-template-ddev-user
push-template-ddev-user: ## Push ddev-user template to Coder
	@echo "Syncing VERSION to $(DDEV_USER_DIR)..."
	cp VERSION $(DDEV_USER_DIR)/VERSION
	@echo "Pushing Coder template $(DDEV_USER_DIR)..."
	coder templates push --directory $(DDEV_USER_DIR) $(DDEV_USER_DIR) --yes
	@echo "Template push complete"

.PHONY: push-template-ddev-drupal-core
push-template-ddev-drupal-core: ## Push ddev-drupal-core template to Coder
	@echo "Syncing VERSION to $(DDEV_DRUPAL_CORE_DIR)..."
	cp VERSION $(DDEV_DRUPAL_CORE_DIR)/VERSION
	@echo "Pushing Coder template $(DDEV_DRUPAL_CORE_DIR)..."
	coder templates push --directory $(DDEV_DRUPAL_CORE_DIR) $(DDEV_DRUPAL_CORE_DIR) --yes
	@echo "Template push complete"

.PHONY: deploy-ddev-user
deploy-ddev-user: build-and-push push-template-ddev-user ## Build image, push image, and push ddev-user template
	@echo "Deployment of ddev-user complete!"

.PHONY: deploy-ddev-user-no-cache
deploy-ddev-user-no-cache: build-and-push-no-cache push-template-ddev-user ## Build image (no cache), push image, and push ddev-user template
	@echo "Deployment of ddev-user complete!"

.PHONY: deploy-ddev-drupal-core
deploy-ddev-drupal-core: push-template-ddev-drupal-core ## Push ddev-drupal-core template (uses existing image)
	@echo "Deployment of ddev-drupal-core complete!"

.PHONY: deploy-all
deploy-all: deploy-ddev-user push-template-ddev-drupal-core ## Deploy image and all templates
	@echo "All templates deployed!"
