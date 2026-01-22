# DDEV Coder Template

Coder workspace template for DDEV-based development with Docker-in-Docker support via Sysbox, VS Code for Web, and comprehensive tooling for modern web development.

## Features

- **Sysbox Runtime**: Safe nested Docker without privileged mode
- **Docker-in-Docker**: Full Docker daemon isolated per workspace
- **DDEV v1.24.10**: Installed via official apt package
- **VS Code for Web**: Browser-based IDE via official Coder module
- **Node.js 22.x LTS**: With npm and global package support
- **Port Forwarding**: DDEV Web (8080) and Mailpit (8025) apps
- **Bash Completion**: Enabled for git, ddev, and other commands
- **Base Image**: Ubuntu 24.04 (`randyfay/coder-ddev:v0.1`)

## Configuration

**Container:**
- Runtime: `sysbox-runc` (required for safe Docker-in-Docker)
- User: `coder` (UID 1000)
- Docker group: GID 988 (configurable via `docker_gid`)
- Security: `apparmor:unconfined`, `seccomp:unconfined`
- Volumes: Persistent home directory + Docker cache volume

**Installed Tools:**
- Docker CE + Compose plugin (via systemd)
- DDEV v1.24.10 (official apt package)
- Node.js 22.x LTS + npm (configurable via `node_version`)
- Python 3, pipx, jq, build-essential
- Git, vim, nano, bash-completion

## Template Management

### Deploy or Update Template

Push the template to your Coder server:

```bash
# Initial push or update
coder templates push --directory coder-ddev coder-ddev --yes

# Push with custom message
coder templates push --directory coder-ddev coder-ddev --yes --message "Add feature X"
```

### List Templates

```bash
coder templates list
```

### Delete Template

```bash
# Note: Must delete all workspaces using the template first
coder templates delete coder-ddev --yes
```

## Workspace Management

### Create Workspace (CLI)

```bash
# Create workspace with default parameters
coder create --template coder-ddev my-workspace --yes

# Create interactively (prompts for parameters)
coder create --template coder-ddev my-workspace
```

### Create Workspace (Web UI)

1. Navigate to your Coder dashboard (e.g., `https://coder.example.com`)
2. Click **"New Workspace"** or **"Create Workspace"**
3. Select the **coder-ddev** template
4. Enter a workspace name
5. Adjust parameters (CPU, memory, Node version, Docker GID) if needed
6. Click **"Create Workspace"**

### List Workspaces

```bash
coder list
```

### SSH into Workspace

```bash
coder ssh my-workspace
```

### Stop/Start Workspace

```bash
# Stop workspace
coder stop my-workspace

# Start workspace
coder start my-workspace
```

### Delete Workspace

```bash
coder delete my-workspace --yes
```

## Docker Image Management

### Build and Push Image

When updating the base image:

```bash
# 1. Update VERSION file
echo "v0.2" > coder-ddev/VERSION

# 2. Build image from image/ directory
cd image
docker build -t randyfay/coder-ddev:v0.2 .

# 3. Push to Docker Hub
docker push randyfay/coder-ddev:v0.2

# 4. Update template
cd ..
coder templates push --directory coder-ddev coder-ddev --yes
```

**Note:** The template automatically reads the version from `coder-ddev/VERSION` file. Always update this file when building new image versions.

## Using DDEV in Workspace

Once your workspace is running:

```bash
# SSH into workspace
coder ssh my-workspace

# Create a new DDEV project
mkdir ~/my-project && cd ~/my-project
ddev config --project-type=drupal10 --docroot=web
ddev start

# Access DDEV web interface
# Click "DDEV Web" in Coder dashboard Apps section
# Or use the Mailpit app for email testing
```

## Accessing Apps

The template provides browser-accessible apps in the Coder dashboard:

- **VS Code for Web**: Full-featured VS Code IDE at `/home/coder`
- **DDEV Web**: DDEV project web interface (port 8080)
- **Mailpit**: Email catcher for testing (port 8025)

## Key Coder Commands Reference

```bash
# Templates
coder templates list
coder templates push --directory <dir> <name> --yes
coder templates delete <name> --yes

# Workspaces
coder list
coder create --template <template> <workspace> --yes
coder start <workspace>
coder stop <workspace>
coder delete <workspace> --yes
coder ssh <workspace>

# Configuration
coder login <url>
coder config-ssh
```

## Requirements

**Coder Server Requirements:**
- Sysbox runtime installed on agent nodes (`apt-get install sysbox-ce`)
- Docker provider configured in agent nodes
- Minimum recommended: 4 CPU cores, 8GB RAM per workspace

**Host Configuration:**
- Coder agent must use `sysbox-runc` runtime (not standard `runc`)
- Docker group GID must match host (default: 988, configurable)
- Host path `/home/coder/workspaces/` must exist for volume mounts
