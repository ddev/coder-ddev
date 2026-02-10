# Makefile for building and pushing coder-ddev Docker image and template

# Configuration
IMAGE_NAME := randyfay/coder-ddev
VERSION := $(shell cat VERSION 2>/dev/null || echo "1.0.0-beta1")
DOCKERFILE_DIR := image
DOCKERFILE := $(DOCKERFILE_DIR)/Dockerfile
TEMPLATE_DIR := ddev-user
TEMPLATE_NAME := ddev-user
TEMPLATE_DIR_DRUPAL := ddev-drupal-core
TEMPLATE_NAME_DRUPAL := ddev-drupal-core

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
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

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
	@echo "Template Dir:   $(TEMPLATE_DIR)"
	@echo "Template Name:  $(TEMPLATE_NAME)"

.PHONY: push-template
push-template: ## Push Coder template
	@echo "Pushing Coder template $(TEMPLATE_NAME)..."
	coder templates push --directory $(TEMPLATE_DIR) $(TEMPLATE_NAME) --yes
	@echo "Template push complete"

.PHONY: deploy
deploy: build-and-push push-template ## Build image, push image, and push template (full deployment)
	@echo "Full deployment complete!"

.PHONY: deploy-no-cache
deploy-no-cache: build-and-push-no-cache push-template ## Build image without cache, push image, and push template
	@echo "Full deployment complete!"

.PHONY: push-template-drupal
push-template-drupal: ## Push Drupal Core template to Coder
	@echo "Pushing Coder template $(TEMPLATE_NAME_DRUPAL)..."
	coder templates push --directory $(TEMPLATE_DIR_DRUPAL) $(TEMPLATE_NAME_DRUPAL) --yes
	@echo "Drupal template push complete"

.PHONY: deploy-drupal
deploy-drupal: push-template-drupal ## Deploy Drupal Core template (uses existing image)
	@echo "Drupal template deployment complete!"

.PHONY: deploy-all
deploy-all: deploy push-template-drupal ## Deploy both ddev-user and ddev-drupal-core templates
	@echo "All templates deployed!"
