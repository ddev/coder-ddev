# DDEV Coder Templates

Coder workspace template for DDEV-based development with Docker-in-Docker support, Node.js, and Git.

**Get started (recommended paths):**

- **Drupal.org issue or project** → [Drupal Issue Picker](https://start.coder.ddev.com/drupal-issue) (auto-detects core vs contrib and prefills sensible defaults)
- **Multiple DDEV projects in one workspace** → [DDEV Freeform](https://coder.ddev.com/templates/coder/freeform/workspace?mode=manual)
- **Clean Drupal core without an issue fork** → [Guided Drupal core](https://start.coder.ddev.com/drupal-core) (short context page, then the same manual template)
- **Browse all templates** → [coder.ddev.com/templates](https://coder.ddev.com/templates)

**Advanced:** open the [manual Drupal core template](https://coder.ddev.com/templates/coder/drupal-core/workspace?mode=manual) directly if you already know every parameter you need.

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

The base Docker image is built from the `image/Dockerfile` and shared by all templates. Use the provided Makefile to manage everything:

```bash
# Full deployment (build image, push image, push a template)
make deploy-drupal-core
make deploy-drupal-contrib
make deploy-freeform

# Image operations
make build              # Build the image with cache
make build-no-cache     # Build without cache (useful for clean builds)
make push               # Push to Docker Hub
make build-and-push     # Build and push in one command

# Template operations
make push-template-drupal-core       # Push drupal-core template to Coder
make push-template-drupal-contrib    # Push drupal-contrib template to Coder
make push-template-freeform          # Push freeform template to Coder
make push-all-templates              # Push all templates (no image build)

# Utility commands
make test               # Test the built image
make info               # Show version and configuration
make help               # See all available commands
```

### Version Management

The `VERSION` file in the root directory controls the image tag. The Makefile automatically copies it into each template directory before pushing, and `template.tf` reads it from there — no manual edits to `template.tf` are needed.

**To release a new version:**
1. Update the `VERSION` file (e.g., `v0.7`)
2. Run `make build-and-push` to build and push the image, then `make push-all-templates` to update the templates

**Quick deployment:**
```bash
make deploy-all                # Build with cache, push image, and push all templates
# or
make build-and-push-no-cache && make push-all-templates  # Clean build and deploy
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
├── freeform/           # Multi-project, general-purpose DDEV template
│   ├── template.tf
│   └── README.md
├── drupal-core/        # Drupal core development template
│   ├── template.tf
│   └── README.md
├── drupal-contrib/     # Drupal contrib module/theme development template
│   ├── template.tf
│   └── README.md
├── image/              # Shared Docker image
└── Makefile            # Build and deploy automation
```

## Available Templates

### freeform (General Purpose)
DDEV development environment for one or more projects of any type, each reachable at its own stable URL via ddev-router Host-header routing.

- **Resources**: 4 cores, 8 GB RAM (default)
- **Setup**: Manual (clone your own repository)
- **Use Case**: Any DDEV-compatible project (Drupal, WordPress, Laravel, etc.); multiple projects can coexist in one workspace
- **Start Time**: < 1 minute
- **Template Directory**: `freeform/`

**Create workspace:**
```bash
coder create --template freeform my-workspace
```

### drupal-core (Drupal Core Development)
Fully automated Drupal core development environment, including issue fork support.

- **Setup**: Automatic (Drupal core cloned and installed)
- **Use Case**: Drupal core development, contribution, patch testing
- **Template Directory**: `drupal-core/`
- **Issue Picker**: [start.coder.ddev.com/drupal-issue](https://start.coder.ddev.com/drupal-issue) — paste any drupal.org issue URL; the picker auto-detects core vs. contrib and routes to the right template
- **Includes**:
  - Pre-cloned Drupal core (main branch by default)
  - Issue fork checkout with automatic Composer dependency resolution (Drupal 10, 11, and 12/main)
  - Configured DDEV with automatic PHP version selection
  - Installed demo_umami site (or standard/minimal via parameter)
  - Admin account (admin/admin)

**Create workspace:**
```bash
coder create --template drupal-core my-drupal-dev
```

### drupal-contrib (Drupal Contrib Development)

Automated environment for developing Drupal contrib modules and themes, with optional issue branch support.

- **Setup**: Automatic (module/theme cloned, Drupal installed as dev dependency via `ddev-drupal-contrib`)
- **Use Case**: Contrib module/theme development, issue queue work on any drupal.org project
- **Template Directory**: `drupal-contrib/`
- **Issue Picker**: [start.coder.ddev.com/drupal-issue](https://start.coder.ddev.com/drupal-issue) — paste a drupal.org issue or project URL; auto-detects contrib
- **Includes**:
  - Any drupal.org project cloned (modules and themes)
  - Issue fork checkout via `issue_fork` + `issue_branch` parameters
  - DDEV with [`ddev-drupal-contrib`](https://github.com/ddev/ddev-drupal-contrib) addon (adds `ddev phpunit`, `ddev phpcs`, `ddev phpstan`)
  - Drupal installed as a dev dependency (module/theme auto-symlinked into web root)

**Create workspace:**
```bash
coder create --template drupal-contrib my-contrib-dev \
  --parameter project_name=token \
  --parameter drupal_version=11
```

### Choosing a Template

- Use **freeform** for:
  - Site building and custom site projects
  - General Drupal/PHP projects
  - Multiple DDEV projects in one workspace
  - Maximum flexibility

- Use **drupal-core** for:
  - Drupal core patches and issue queue work
  - Testing Drupal core changes
  - Learning Drupal internals

- Use **drupal-contrib** for:
  - Contrib module or theme development
  - Working on drupal.org contrib issue queues

## Usage

Create a new workspace using your chosen template:

```bash
# General-purpose DDEV environment
coder create --template freeform <workspace-name>

# Drupal core development environment
coder create --template drupal-core <workspace-name>

# Drupal contrib module/theme development
coder create --template drupal-contrib <workspace-name> \
  --parameter project_name=token --parameter drupal_version=11
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
coder templates push --directory freeform freeform --yes

# Or use Makefile
make build-and-push       # Build + push image
make deploy-freeform       # Push freeform template (uses existing image)
```

**📖 [Full Operations Guide](./docs/admin/operations-guide.md)**
