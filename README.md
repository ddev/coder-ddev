# DDEV Coder Template

Coder workspace template for Drupal development with ddev, Docker-in-Docker support, Node.js, and Git.

## Features

- **Custom Base Image**: Ubuntu 24.04 with curl/wget/sudo pre-installed
- **Docker-in-Docker**: Full Docker support for ddev (using Sysbox runtime)
- **Node.js/npm**: LTS version (default: 22.x)
- **ddev**: v1.24.10 pre-installed
- **PHP/Composer**: Via ddev containers

## Configuration

**Container:**
- User: `coder` (UID 1000)
- Runtime: `sysbox-runc` (for secure Docker-in-Docker)
- Docker daemon: Runs inside the container

**Installed Tools:**
- Docker CLI and daemon (latest stable)
- ddev v1.24.10
- Node.js LTS (configurable via `node_version` variable)
- Git, vim, build tools

## Docker Image Management

### Building the Docker Image

The base Docker image is built from the `image/Dockerfile`. Use the provided Makefile to build and push images:

```bash
# Build the image with cache
make build

# Build without cache (useful for clean builds)
make build-no-cache

# Push to Docker Hub
make push

# Build and push in one command
make build-and-push

# Build without cache and push
make build-and-push-no-cache

# Test the built image
make test

# Show image info
make info

# See all available commands
make help
```

### Version Management

The Docker image version is managed in two places:

1. **`VERSION` file** (root directory): Single source of truth for the current version
   - Used by the Makefile when building images
   - Should be updated when releasing new versions

2. **`template/template.tf`**: The `image_version` variable
   - Default value should match the VERSION file
   - Can be overridden when deploying the template
   - Update this when bumping versions to ensure new workspaces use the latest image

**To release a new version:**
1. Update the `VERSION` file (e.g., `1.0.0-beta2`)
2. Update the `image_version` default in `template/template.tf`
3. Build and push the new image: `make build-and-push`
4. Deploy the updated template to Coder

## Deployment

Deploy the template to Coder:

```bash
coder templates push --directory template --name coder-ddev --yes
```

## Usage

Create a new workspace using the template:

```bash
coder create --template coder-ddev <workspace-name>
```
