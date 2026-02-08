# DDEV Coder Template

Coder workspace template for Drupal development with ddev, Docker-in-Docker support, Node.js, and Git.

## Features

- **Custom Base Image**: Ubuntu LTS with curl/wget/sudo pre-installed
- **Docker-in-Docker**: Full Docker support for ddev (using Sysbox runtime)
- **Node.js/npm**: LTS version
- **ddev**: Latest version pre-installed
- **PHP/Composer**: Via ddev containers

## Configuration

**Container:**
- User: `coder` (UID 1000)
- Runtime: `sysbox-runc` (for secure Docker-in-Docker)
- Docker daemon: Runs inside the container

**Installed Tools:**
- Docker CLI and daemon (latest stable)
- ddev (latest)
- Node.js LTS (configurable via `node_version` variable)
- Git, vim, build tools

## Docker Image and Template Management

### Building and Deploying

The base Docker image is built from the `image/Dockerfile` and the Coder template is in `template/`. Use the provided Makefile to manage everything:

```bash
# Full deployment (build, push image, push template)
make deploy

# Full deployment without cache
make deploy-no-cache

# Image operations
make build              # Build the image with cache
make build-no-cache     # Build without cache (useful for clean builds)
make push               # Push to Docker Hub
make build-and-push     # Build and push in one command

# Template operations
make push-template      # Push template to Coder

# Utility commands
make test               # Test the built image
make info               # Show version and configuration
make help               # See all available commands
```

### Version Management

The Docker image and template versions are managed via two files:

1. **`VERSION` file** (root directory): Used by the Makefile when building/tagging Docker images
2. **`template/template.tf`**: The `image_version` variable default value

**To release a new version:**
1. Update the `VERSION` file (e.g., `v0.5`)
2. Update the `image_version` default in `template/template.tf` to match
3. Run `make deploy` to build image, push image, and push template

**Quick deployment:**
```bash
# After updating both VERSION and template.tf:
make deploy              # Build with cache and deploy
# or
make deploy-no-cache     # Clean build and deploy
```

**Note:** Keep the VERSION file and template.tf `image_version` in sync manually when releasing new versions.

## Template Structure

Templates are organized in directories where **the directory name is the template name**:

```
coder-ddev/
├── ddev-user/          # ddev-user template
│   └── template.tf
├── ddev-developer/     # Future: ddev-developer template (more tools)
│   └── template.tf
├── image/              # Shared Docker image
└── Makefile           # Build and deploy automation
```

## Usage

Create a new workspace using the template:

```bash
coder create --template ddev-user <workspace-name>
```
