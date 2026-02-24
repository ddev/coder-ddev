# Administrator Operations Guide

This guide covers the deployment and management of the DDEV Coder template for administrators.

## Prerequisites

Before deploying this template, ensure the following are in place:

### Coder Server

- Coder v2+ server installed and running
- Administrative access to Coder
- Coder CLI installed and authenticated (`coder login <url>`)

> **Setting up a new server?** See the [Server Setup Guide](./server-setup.md) for step-by-step installation of Docker, Sysbox, and Coder.

### Docker Host Infrastructure

- **Sysbox runtime installed** on all Coder agent nodes:
  ```bash
  # Install prerequisites
  sudo apt-get install -y jq

  # Download Sysbox CE package (check https://github.com/nestybox/sysbox/releases for latest version)
  SYSBOX_VERSION=0.6.7
  wget https://downloads.nestybox.com/sysbox/releases/v${SYSBOX_VERSION}/sysbox-ce_${SYSBOX_VERSION}-0.linux_amd64.deb

  # Install the package (note: sysbox-ce is not in standard apt repos)
  sudo apt-get install -y ./sysbox-ce_${SYSBOX_VERSION}-0.linux_amd64.deb

  # Verify installation
  sudo systemctl status sysbox -n20
  sysbox-runc --version
  ```
  **Note:** Docker must be installed (not via snap) before installing Sysbox. The installer will restart Docker. See [Sysbox install docs](https://github.com/nestybox/sysbox/blob/master/docs/user-guide/install-package.md) for details.

- Docker configured to use Sysbox runtime for appropriate containers
- Sufficient storage for Docker volumes (each workspace uses dedicated `/var/lib/docker` volume)

### Docker Registry Access

- Access to push images (Docker Hub or private registry)
- Registry credentials configured if using private registry
- For Docker Hub: `docker login`

### Local Tools

- Docker installed locally for building images
- Coder CLI installed and configured
- Git for version management
- Make (`sudo apt-get install -y make` on Ubuntu, pre-installed on macOS)

## Building the Docker Image

The base image contains Ubuntu, Docker daemon, DDEV, Node.js, and essential development tools.

### Using the Makefile

The Makefile automates all build and deployment tasks:

```bash
# Show available commands
make help

# Build image with cache
make build

# Build without cache (clean build)
make build-no-cache

# Push to registry
make push

# Build and push in one step
make build-and-push

# Test the built image
make test

# Show version info
make info
```

See `image/README.md` for details on customizing the Docker image.

## Deploying the Template

### Using the Makefile

```bash
# Push template only
make push-template-ddev-user

# Full deployment (build image + push image + push template)
make deploy-ddev-user

# Full deployment without cache
make deploy-ddev-user-no-cache
```

### Template Configuration

The template is defined in `ddev-user/template.tf`. Key configuration parameters:

```hcl
variable "workspace_image_registry" {
  default = "index.docker.io/ddev/coder-ddev"
}

variable "image_version" {
  default = "v0.1"  # Update this when releasing new image versions
}

variable "cpu" {
  default = 4  # CPU cores per workspace
}

variable "memory" {
  default = 8  # RAM in GB per workspace
}

variable "docker_gid" {
  default = 988  # Docker group ID (must match host)
}
```

**To use a private registry:**

1. Update `workspace_image_registry` in `template.tf`
2. Configure `registry_username` and `registry_password` variables
3. Push template: `coder templates push --directory ddev-user ddev-user --yes`

## Version Management

### Version Files

The `VERSION` file in the root directory controls the image tag. The Makefile automatically copies it into the template directory before pushing, and `template.tf` reads it from there — no manual edits to `template.tf` are needed.

### Releasing a New Version

```bash
# 1. Update VERSION file
echo "v0.7" > VERSION

# 2. Build, push image, and push template (VERSION is synced automatically)
make deploy-ddev-user

# Or without cache for clean build
make deploy-ddev-user-no-cache
```

## Managing Workspaces

### Creating Workspaces

**Via Web UI:**
1. Log into Coder dashboard
2. Click "Create Workspace"
3. Select "ddev-user" template
4. Enter workspace name
5. Configure parameters (optional: CPU, memory)
6. Click "Create Workspace"

**Via CLI:**
```bash
# Create with defaults
coder create --template ddev-user my-workspace --yes

# Create with custom parameters
coder create --template ddev-user my-workspace \
  --parameter cpu=8 \
  --parameter memory=16 \
  --yes
```

### Listing Workspaces

```bash
# List all workspaces
coder list

# List workspaces for specific template
coder list --template ddev-user

# Show detailed workspace info
coder show my-workspace
```

### Starting/Stopping Workspaces

```bash
# Stop workspace (saves state, stops billing)
coder stop my-workspace

# Start workspace
coder start my-workspace

# Restart workspace
coder restart my-workspace
```

### Updating Workspaces

When you push a new template version, existing workspaces don't automatically update.

**To update a workspace to new template version:**

```bash
# Update in place (preserves /home/coder)
coder update my-workspace

# Or from web UI: Click workspace → Update button
```

**Notes:**
- Updates template configuration but NOT the Docker image
- To update Docker image, workspace must be rebuilt (delete and recreate)
- Updating preserves `/home/coder` volume
- DDEV containers may need to be restarted after update

### Deleting Workspaces

```bash
# Delete workspace (warns if running)
coder delete my-workspace

# Force delete
coder delete my-workspace --yes

# Delete multiple workspaces
coder delete workspace1 workspace2 workspace3 --yes
```

**Note:** Deleting a workspace removes:
- Workspace container
- `/home/coder` volume (host directory)
- `/var/lib/docker` volume (Docker daemon data)
- All DDEV containers and volumes inside the workspace

## Template Updates

### Updating Template Configuration

```bash
# 1. Edit template.tf
vim ddev-user/template.tf

# 2. Push updated template
make push-template-ddev-user
```

### Updating Docker Image

```bash
# 1. Edit image/Dockerfile (if needed)
# 2. Increment version (template reads this automatically)
echo "v0.7" > VERSION

# 3. Build and deploy
make deploy-ddev-user

# Users must rebuild workspaces to get new Docker image
```

### Rolling Back

```bash
# Revert to previous template version
git checkout <previous-commit> ddev-user/template.tf
coder templates push --directory ddev-user ddev-user --yes

# Users on old version are unaffected
# Users can update to rollback version via: coder update <workspace>
```

## Backup and Maintenance

### Workspace Data Backup

Each workspace stores persistent data in:
- **Home directory**: `/home/coder/workspaces/<owner>-<workspace>` on host
- **Docker volume**: Named volume `coder-<owner>-<workspace>-dind-cache`

**Backup strategy:**

```bash
# Backup home directory
tar -czf workspace-backup.tar.gz /home/coder/workspaces/<owner>-<workspace>

# Backup Docker volume
docker run --rm \
  -v coder-<owner>-<workspace>-dind-cache:/source \
  -v $(pwd):/backup \
  ubuntu:24.04 \
  tar -czf /backup/docker-volume-backup.tar.gz -C /source .

# Restore Docker volume
docker volume create coder-<owner>-<workspace>-dind-cache
docker run --rm \
  -v coder-<owner>-<workspace>-dind-cache:/target \
  -v $(pwd):/backup \
  ubuntu:24.04 \
  tar -xzf /backup/docker-volume-backup.tar.gz -C /target
```

### Template Versioning

Store template versions in git:

```bash
# Tag releases
git tag -a v0.1 -m "Release v0.1"
git push origin v0.1

# Track changes
git log --oneline ddev-user/template.tf
```

### Monitoring

**Check workspace health:**
```bash
# View workspace logs
coder ssh my-workspace -- journalctl -u coder-agent -f

# Check Docker daemon inside workspace
coder ssh my-workspace -- docker ps
coder ssh my-workspace -- docker info

# Check DDEV status
coder ssh my-workspace -- ddev list
```

**Resource usage:**
```bash
# Check workspace container resources
docker stats coder-<workspace-id>

# Check disk usage
df -h /home/coder/workspaces/
docker system df
```

## Troubleshooting

See [troubleshooting.md](./troubleshooting.md) for detailed debugging procedures.

**Quick checks:**

```bash
# Template deployment failed
coder templates list  # Check if template exists
terraform validate    # Validate template syntax

# Workspace won't start
coder logs my-workspace           # View startup logs
docker logs coder-<workspace-id>  # View container logs

# Docker daemon issues
coder ssh my-workspace -- cat /tmp/dockerd.log
coder ssh my-workspace -- systemctl status docker
```

## Security Considerations

### Sysbox Runtime

Sysbox provides **secure nested containers** without privileged mode:
- No `--privileged` flag required
- Isolated Docker daemon per workspace
- AppArmor and seccomp profiles configured

**Security profiles in template.tf:**
```hcl
security_opt = ["apparmor:unconfined", "seccomp:unconfined"]
```

These are required for Sysbox functionality and are safer than `--privileged`.

### User Isolation

- Each workspace has isolated Docker daemon
- Workspaces cannot access other workspaces' Docker containers
- Users have sudo access **inside their workspace only**

### Registry Security

- Store registry credentials in Coder secrets or environment variables
- Avoid hardcoding credentials in template.tf
- Use private registries for proprietary images

### Network Security

- DDEV uses Coder's port forwarding (not direct host binding)
- Ports are proxied through Coder server
- Configure firewall rules on Coder server, not individual workspaces

## Best Practices

### Resource Allocation

- **Default**: 4 CPU cores, 8GB RAM (suitable for most PHP/Node projects)
- **Large projects**: 8 cores, 16GB RAM
- **Small projects**: 2 cores, 4GB RAM

Monitor resource usage and adjust template defaults accordingly.

### Template Naming

- Use clear, descriptive names: `ddev-user`, `ddev-developer`
- Version templates for major changes: `ddev-user-v2`
- Avoid generic names: `template1`, `test`

### Image Management

- Always tag images with specific versions **and** `latest`
- Test images before pushing to production registry
- Document changes in git commit messages
- Keep Dockerfile layer count reasonable (current: ~10 layers)

### Workspace Lifecycle

- **Short-lived workspaces**: Ideal for temporary work, prototyping
- **Long-lived workspaces**: Personal development environments
- Stop workspaces when not in use to save resources

### Documentation

- Keep `CLAUDE.md` updated for AI-assisted development
- Update user docs in `/docs/user/` when template changes
- Document breaking changes in git tags and release notes

## Additional Resources

- [Server Setup Guide](./server-setup.md) - Fresh server installation (Docker, Sysbox, Coder)
- [User Management Guide](./user-management.md) - Managing users and permissions
- [Troubleshooting Guide](./troubleshooting.md) - Debugging workspace issues
- [Coder Documentation](https://coder.com/docs) - Official Coder docs
- [Sysbox Documentation](https://github.com/nestybox/sysbox) - Sysbox runtime details
- [DDEV Documentation](https://docs.ddev.com/) - DDEV usage and configuration
