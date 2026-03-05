# DDEV Coder Templates

Coder workspace template for DDEV-based development with Docker-in-Docker support, Node.js, and Git.

## Features

- **Custom Base Image**: Ubuntu 24.04 LTS with essential development tools
- **Docker-in-Docker**: Full Docker support for DDEV (using Sysbox runtime)
- **DDEV**: Pre-installed and ready to use
- **VS Code for Web**: Browser-based IDE with full extension support

## Configuration

**Container:**
- User: `coder` (UID 1000)
- Runtime: `sysbox-runc` (for secure Docker-in-Docker)
- Docker daemon: Runs inside the container

**Installed Tools:**
- Docker CLI and daemon (latest stable)
- ddev (latest stable)
- Git, vim, build tools

## Docker Image and Template Management

### Building and Deploying

The base Docker image is built from the `image/Dockerfile` and the Coder template is in `template/`. Use the provided Makefile to manage everything:

```bash
# Full deployment (build, push image, push template)
make deploy-user-defined-web

# Full deployment without cache
make deploy-user-defined-web-no-cache

# Image operations
make build              # Build the image with cache
make build-no-cache     # Build without cache (useful for clean builds)
make push               # Push to Docker Hub
make build-and-push     # Build and push in one command

# Template operations
make push-template-user-defined-web      # Push user-defined-web template to Coder

# Utility commands
make test               # Test the built image
make info               # Show version and configuration
make help               # See all available commands
```

### Version Management

The `VERSION` file in the root directory controls the image tag. The Makefile automatically copies it into the template directory before pushing, and `template.tf` reads it from there — no manual edits to `template.tf` are needed.

**To release a new version:**
1. Update the `VERSION` file (e.g., `v0.7`)
2. Run `make deploy-user-defined-web` to build image, push image, and push template

**Quick deployment:**
```bash
make deploy-user-defined-web        # Build with cache and deploy
# or
make deploy-user-defined-web-no-cache  # Clean build and deploy
```

## Documentation

**New to Coder?**
- 📘 [Getting Started Guide](./docs/user/getting-started.md) - Create your first workspace
- 📗 [Using Workspaces](./docs/user/using-workspaces.md) - Daily workflows and tips

**Administrators:**
- 📕 [Operations Guide](./docs/admin/operations-guide.md) - Deploy and manage template
- 📙 [User Management](./docs/admin/user-management.md) - Users, roles, permissions
- 📔 [Troubleshooting](./docs/admin/troubleshooting.md) - Debug common issues

**DDEV Experts:**
- 🔍 [Comparison to Local DDEV](./docs/architecture/comparison-to-local.md) - Architecture, tradeoffs, migration

**Developers/Contributors:**
- 🤖 [CLAUDE.md](./CLAUDE.md) - AI-assisted development guide

📚 **[Full Documentation Index](./docs/README.md)**

## Template Structure

```
coder-ddev/
├── user-defined-web/          # General-purpose DDEV template
│   ├── template.tf
│   └── README.md
├── drupal-core/   # Drupal core development template
│   ├── template.tf
│   └── README.md
├── image/              # Shared Docker image
└── Makefile           # Build and deploy automation
```

## Available Templates

### user-defined-web (General Purpose)
Basic DDEV development environment for any project type.

- **Resources**: 4 cores, 8 GB RAM (default)
- **Setup**: Manual (clone your own repository)
- **Use Case**: Any DDEV-compatible project (Drupal, WordPress, Laravel, etc.)
- **Start Time**: < 1 minute
- **Template Directory**: `user-defined-web/`

**Create workspace:**
```bash
coder create --template user-defined-web my-workspace
```

### drupal-core (Drupal Core Development)
Fully automated Drupal core development environment.

- **Setup**: Automatic (Drupal core cloned and installed)
- **Use Case**: Drupal core development, contribution, testing
- **Template Directory**: `drupal-core/`
- **Includes**:
  - Pre-cloned Drupal core main branch (shallow clone, 50 commits depth)
  - Configured DDEV (PHP 8.5, Drupal HEAD/main config, port 80)
  - Installed demo_umami site
  - Admin account (admin/admin)

**Create workspace:**
```bash
coder create --template drupal-core my-drupal-dev
```

### Choosing a Template

- Use **user-defined-web** for:
  - Contrib module development
  - Site building
  - General Drupal/PHP projects
  - Maximum flexibility

- Use **drupal-core** for:
  - Drupal core patches
  - Core issue queue work
  - Testing Drupal core changes
  - Learning Drupal internals

## Usage

Create a new workspace using your chosen template:

```bash
# General-purpose DDEV environment
coder create --template user-defined-web <workspace-name>

# Drupal core development environment
coder create --template drupal-core <workspace-name>
```

**Access your project:**
- Open Coder dashboard
- Find your workspace
- Click on port **80** or **443** under "Apps"

**📖 [Full Getting Started Guide](./docs/user/getting-started.md)**

### For Administrators

Deploy template and manage infrastructure:

```bash
# Build and push Docker image
cd image
docker build -t ddev/coder-ddev:v0.1 .
docker push ddev/coder-ddev:v0.1

# Deploy template to Coder
coder templates push --directory user-defined-web user-defined-web --yes

# Or use Makefile
make deploy-user-defined-web  # Build + push image + push template
```

**📖 [Full Operations Guide](./docs/admin/operations-guide.md)**
