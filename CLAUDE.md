# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This project provides a Coder v2+ template for DDEV-based development environments using Docker-in-Docker via Sysbox runtime. It creates isolated workspaces with full Docker daemon support for running DDEV projects.

**Key Technologies:**
- **Terraform (HCL)** - Infrastructure as Code for Coder templates
- **Docker + Sysbox** - Nested containerization without privileged mode
- **DDEV v1.24.10** - PHP/Node/Python development environment tool
- **VS Code for Web** - Browser-based IDE via official Coder module
- **Ubuntu 24.04** - Base container OS

## Essential Commands

### Template Management
```bash
# Deploy or update template
coder templates push --directory coder-ddev coder-ddev --yes

# List all templates
coder templates list

# Delete template (must delete workspaces first)
coder templates delete coder-ddev --yes
```

### Workspace Management
```bash
# Create workspace
coder create --template coder-ddev <workspace-name> --yes

# List workspaces
coder list

# SSH into workspace
coder ssh <workspace-name>

# Stop/start workspace
coder stop <workspace-name>
coder start <workspace-name>

# Delete workspace
coder delete <workspace-name> --yes
```

### Docker Image Management
```bash
# Build the base image (from image/ directory)
cd image
docker build -t randyfay/coder-ddev:v0.1 .

# Push to Docker Hub
docker push randyfay/coder-ddev:v0.1

# Update version for new releases
echo "v0.2" > ../coder-ddev/VERSION
docker build -t randyfay/coder-ddev:v0.2 .
docker push randyfay/coder-ddev:v0.2
```

### DDEV Commands (within workspace)
```bash
# Initialize DDEV in project directory
ddev config --project-type=drupal10 --docroot=web

# Start DDEV environment
ddev start

# Stop DDEV environment
ddev stop

# Check DDEV status
ddev describe
```

### IDE Access
```bash
# VS Code for Web is automatically available via Coder's official module
# Access via Coder dashboard under "Apps" section
# Opens at /home/coder directory with full IDE features
# Module: registry.coder.com/coder/vscode-web/coder v1.0.20
```

### OpenSpec Workflow
```bash
# List active change proposals
openspec list

# List existing specifications
openspec list --specs

# Validate a change proposal
openspec validate <change-id> --strict

# Archive completed change
openspec archive <change-id> --yes
```

## Architecture

### Sysbox Runtime Model
The template uses **Sysbox-runc** instead of privileged Docker containers:
- Provides safe nested Docker without `--privileged` flag
- Each workspace gets its own isolated Docker daemon inside the container
- Docker data persisted in dedicated volume at `/var/lib/docker`
- Security profiles: `apparmor:unconfined`, `seccomp:unconfined`

### Directory Structure
```
/home/coder/                    # Persistent workspace home (volume-backed)
├── projects/                   # DDEV projects location
├── .ddev/                      # DDEV global configuration
│   └── global_config.yaml      # Copied from image on first run
├── WELCOME.txt                 # Workspace welcome message
└── .npm-global/                # User-scoped npm packages

/home/coder-files/              # Image-embedded files (outside volume)
├── .ddev/global_config.yaml    # DDEV defaults
└── WELCOME.txt                 # Welcome template
```

**Critical:** The `/home/coder` volume mount hides image contents, so files must be copied from `/home/coder-files/` during startup script execution.

### Startup Script Flow
The startup script in `coder-ddev/scripts/startup.sh` performs:
1. **Permissions** - Fix ownership of `/home/coder` volume
2. **Home initialization** - Copy skeleton files if first run
3. **Git SSH setup** - Configure Coder's GitSSH wrapper
4. **File copy** - Transfer `/home/coder-files/*` to home directory
5. **Docker daemon** - Start `dockerd` via sudo, wait for socket
6. **DDEV config** - Copy `global_config.yaml` to `~/.ddev/`
7. **DDEV verification** - Verify DDEV installation and Docker connectivity
8. **Environment** - Set locale, PATH, workspace variables

**Note:** VS Code for Web is managed by the official Coder module and starts automatically.

### Volume Strategy
- **Home directory**: Host path `/home/coder/workspaces/<owner>-<workspace>` → Container `/home/coder`
- **Docker cache**: Named volume `coder-<owner>-<workspace>-dind-cache` → `/var/lib/docker`
- **Isolation**: Each workspace gets separate host directory and Docker volume

### Terraform Variables
Key template variables in `coder-ddev/template.tf`:
- `workspace_image_registry` - Docker registry URL (default: `index.docker.io/randyfay/coder-ddev`)
- `image_version` - Image tag (default: read from `VERSION` file or `v0.1`)
- `cpu` / `memory` - Resource limits (defaults: 4 cores, 8GB RAM)
- `node_version` - Node.js version (default: `20`)
- `docker_gid` - Docker group GID (default: `988`)
- `registry_username` / `registry_password` - Registry authentication (optional)

## Project Conventions

### Minimalist Philosophy
- **No bundled dev tools** - Avoid pre-installing AI agents, custom shells, or opinionated tooling
- **Infrastructure-only** - This is a base template; users add their own content
- **Manual project setup** - Template does NOT auto-clone repositories or bootstrap projects
- **Standard paths** - Always use `/home/coder` as workspace home

### Git Workflow
- This is an **infrastructure repository** managing Coder templates
- Use feature branches for changes
- Always use OpenSpec for architectural changes (see AGENTS.md)

### OpenSpec Integration
This project uses OpenSpec for spec-driven development:
- **Trigger OpenSpec** for: new features, breaking changes, architecture shifts, performance/security work
- **Skip OpenSpec** for: bug fixes, typos, config tweaks, dependency updates
- Always check `openspec/AGENTS.md` when planning significant changes
- Read `openspec/project.md` for project-specific conventions

**When to create change proposals:**
- Adding/modifying DDEV configuration patterns
- Changing Terraform template structure
- Updating Sysbox integration approach
- Modifying Docker image build process
- Altering workspace lifecycle (startup/shutdown)

## Docker Image Build

The `image/Dockerfile` builds the base workspace image:

### Layer Strategy
1. **Base packages** - curl, wget, git, vim, sudo, build tools, bash-completion
2. **User setup** - Rename ubuntu user → coder (UID 1000)
3. **Scripts copy** - `COPY scripts /home/coder-files` (outside volume mount)
4. **Python/Node** - Install Python 3, Node.js 22.x LTS
5. **Global npm tools** - OpenSpec, TypeScript (in image, re-attempted in startup)
6. **Docker daemon** - `docker-ce`, `docker-ce-cli`, `containerd`, systemd for Sysbox
7. **DDEV** - v1.24.10 from official apt package (pkg.ddev.com)

### Important Build Notes
- User `coder` gets passwordless sudo: `coder ALL=(ALL) NOPASSWD:ALL`
- npm global packages go to `/home/coder/.npm-global` (user-scoped)
- Docker service enabled via systemd: `systemctl enable docker`
- PATH additions for `.local/bin` and `.npm-global/bin` in `/etc/profile.d/`

## Key Constraints

### Sysbox Requirement
- **Host must have Sysbox installed**: `apt-get install sysbox-ce` (or sysbox-ee)
- Coder agent nodes must use `sysbox-runc` runtime
- Workspaces must specify `runtime = "sysbox-runc"` in Terraform

### Port Forwarding
- DDEV uses Coder's port forwarding (not direct host binding)
- Default ports: HTTP 80/8080, HTTPS 443/8443, Mailpit 8025/8026
- Configure `host_webserver_port` in `.ddev/global_config.yaml` if needed

### Docker Socket Access
- Do NOT mount host Docker socket (`/var/run/docker.sock`)
- Each workspace has isolated Docker daemon via Sysbox
- Container user must be in docker group (GID 988): `group_add = ["988"]`

## Debugging

### Startup Script Logs
All startup output goes to Coder agent logs. Check with:
```bash
# View agent logs in Coder UI or:
docker logs coder-<workspace-id>
```

Additional logs in workspace:
- `/tmp/dockerd.log` - Docker daemon output

### Common Issues

**Docker daemon not starting:**
- Check Sysbox is installed on host: `sysbox-runc --version`
- Verify container uses `runtime = "sysbox-runc"`
- Check AppArmor/seccomp profiles in `security_opts`

**DDEV containers fail to start:**
- Ensure Docker daemon is running: `docker ps`
- Check socket permissions: `ls -la /var/run/docker.sock`
- Verify Docker volume mounted: `df -h /var/lib/docker`

**File ownership issues:**
- Startup script runs `chown coder:coder /home/coder` on each start
- Volume may have host UID, fixed automatically

**npm global packages missing:**
- Packages pre-installed in image, re-attempted in startup script
- Check PATH includes `~/.npm-global/bin` and `~/.local/bin`
- Manual install: `npm install -g @fission-ai/openspec`

## Important Code Locations

- `coder-ddev/template.tf` - Main Terraform template definition
- `coder-ddev/scripts/startup.sh` - Workspace startup script with Docker/DDEV initialization
- `coder-ddev/template.tf:183-239` - Coder agent configuration
- `coder-ddev/template.tf:242-248` - VS Code for Web module (official Coder module)
- `coder-ddev/template.tf:250-263` - Graceful DDEV shutdown script
- `coder-ddev/template.tf:268-332` - Docker container resource
- `image/Dockerfile` - Base image build instructions
- `image/scripts/.ddev/global_config.yaml` - DDEV defaults
- `VERSION` - Image version used by template (read automatically)
- `openspec/project.md` - Project conventions and constraints
- `openspec/AGENTS.md` - OpenSpec workflow instructions
