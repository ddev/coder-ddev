# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This project provides a Coder v2+ template for DDEV-based development environments using Docker-in-Docker via Sysbox runtime. It creates isolated workspaces with full Docker daemon support for running DDEV projects.

**Key Technologies:**
- **Terraform (HCL)** - Infrastructure as Code for Coder templates
- **Docker + Sysbox** - Nested containerization without privileged mode
- **DDEV** - PHP/Node/Python development environment tool (supports 20+ project types)
- **VS Code for Web** - Browser-based IDE via official Coder module
- **Ubuntu 24.04** - Base container OS

**Note:** User-facing documentation has moved to `/docs/`. This file focuses on developer/contributor guidance.

## Coder CLI Commands in Docs

When writing or reviewing `coder` CLI commands in documentation, **always verify against the actual CLI** (`coder <subcommand> --help`) and the [Coder CLI reference docs](https://coder.com/docs/reference/cli). Common past mistakes to avoid:

- `coder delete` takes only **one** workspace argument — use a `for` loop for multiple
- `coder stop` / `coder start` take only **one** workspace argument
- `coder scp` does **not exist** — use `scp` after `coder config-ssh`
- `coder templates show` does **not exist** — use `coder templates list -o json | jq ...`
- `coder publickey` has no `add`/`list`/`remove` subcommands — it only outputs your key
- `coder list` has no `--user` flag — use `--search "owner:<username>"` with `-a`
- `coder tokens` uses `remove` not `revoke`; `create` takes `--name`, not a positional arg
- `coder templates list` has no `--organization` flag — use the global `--org`
- `coder sharing add` requires `--user <username>:<role>` (role required)

## DDEV Command Gotchas

- `ddev composer create` is **obsolete** — always use `ddev composer create-project <package> .` (note the trailing `.` for current directory)
- Do **not** pin packages to `:dev-main` (e.g. `package:dev-main`) — omit the version constraint and let Composer resolve it
- All templates omit `ddev-router` via `ddev config global --omit-containers=ddev-router`; each template uses direct port binding instead

## Template Architecture Overview

Three templates exist, each with a distinct routing model:

| Template             | Web port | Routing model                                         |
| -------------------- | -------- | ----------------------------------------------------- |
| `drupal-core`        | 80       | Direct bind, no ddev-router                           |
| `drupal-contrib`     | 8080     | Direct bind, no ddev-router                           |
| `freeform`           | 8080     | ddev-router on 8080, Host-header dispatch per project |

The `freeform` template is unique: it keeps ddev-router running so multiple DDEV projects can coexist in one workspace, distinguished by Host header.

## Tool Preferences

- Use `jq` (not `python3 -m json.tool`) for JSON pretty-printing and querying
- For `git commit -m` and `gh pr create --body`, write the message to a file first (e.g. under the scratchpad directory) and pass it via `git commit -F <file>` / `gh pr create --body-file <file>`, rather than inlining a heredoc on the command line. Multi-paragraph messages containing backticks, apostrophes, or other shell-special characters reliably break inline heredoc quoting.

## Before Pushing / Pre-push Checklist

Run these before every push to avoid CI failures:

```bash
# Terraform formatting (CI runs terraform fmt -check -recursive)
terraform fmt -recursive

# Vendor shared assets, then validate + test every template
make validate
make test-templates
```

`terraform fmt -recursive` must be run from the repo root. It is non-destructive (rewrites in place) and the CI check fails with exit code 3 if any file is not formatted.

**Always use `make validate` / `make test-templates`, not raw `terraform validate`/`terraform test` run directly in a template directory.** Both targets depend on `make sync-shared`, which vendors `modules/claude-remote-control` and `shared/vscode-extensions.tf` into each template directory first (see "Shared Terraform Assets" below). Running `terraform validate`/`test` directly against a template dir will happily validate against a stale vendored copy and miss the fact that it's out of sync with the canonical source.

## Shared Terraform Assets

Some Terraform config (currently `modules/claude-remote-control` and `shared/vscode-extensions.tf`) is shared across all three templates but must exist as a **physical copy inside each template directory** — `coder templates push` and CI's `terraform validate`/`test` only ever operate on a single template directory, so a relative `../modules` or `../shared` reference would not survive the push and would not be visible to CI.

- **Edit only the canonical source**: `modules/claude-remote-control/` or `shared/vscode-extensions.tf` at the repo root. Never hand-edit the vendored copies (`<template>/modules/claude-remote-control/`, `<template>/vscode-extensions.tf`) — they get overwritten the next time anyone runs the sync.
- **Always resync through `make`**, never by hand-copying: `make sync-shared` (or `make sync-claude-module` / `make sync-vscode-extensions` individually). `make validate`, `make test-templates`, and every `make push-template-*` / `make push-all-templates` target already depend on `sync-shared`, so day-to-day you rarely need to invoke it directly.
- **Commit the vendored copies.** They are tracked files, not build artifacts — CI validates each template directory standalone with no `make` step, so the vendored copies must already be correct and committed for CI to pass.

## Working with Coder Workspaces via SSH

After running `coder config-ssh --yes`, workspaces are available as SSH hosts named `<workspace>.coder`. Use `scp` to copy files in or out, then `ssh` to execute scripts non-interactively:

```bash
# Configure SSH (once)
coder config-ssh --yes

# Copy a file into a workspace
scp ./local-file.sh mp1.coder:/tmp/

# Execute a script non-interactively (preferred — avoids PTY/pipe issues)
ssh mp1.coder bash /tmp/local-file.sh

# One-liner for quick commands
ssh mp1.coder ddev list
```

When running commands via `coder ssh -- ...` or piped heredocs, the PTY allocation causes interactive prompts and pipe-stall issues. Writing a script to `/tmp/` and executing it via `ssh workspace.coder bash /tmp/script.sh` is reliable for multi-step operations.

**CI scripting rule**: In GitHub Actions, for any `coder ssh` invocation that does more than a single trivial command, push a script file and run it — do not use `bash -c "..."`. Single commands with standard flags (e.g. `git -C /path branch --show-current`) are fine inline. Anything with `&&`, conditionals, or multiple statements belongs in a script file under the template's `scripts/` directory.

To run a command in a specific directory without a shell wrapper, use `env -C <dir> <cmd>` (available on Ubuntu 24.04 via GNU coreutils): `coder ssh ws -- env -C /home/coder/myproject ddev drush status`

## Essential Commands

### Template Management
```bash
# Push all templates (no image build — use when only HCL changed)
make push-all-templates

# Push a single template
make push-template-drupal-core
make push-template-drupal-contrib
make push-template-freeform

# List all templates
coder templates list

# Delete template (must delete workspaces first)
coder templates delete <template-name> --yes
```

### Workspace Management
```bash
# Create workspace
coder create --template freeform <workspace-name> --yes

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
# Build image
make build

# Build and push to registry
make build-and-push

# Update version for new releases
echo "v0.2" > VERSION
make deploy-drupal-core
```

### DDEV Commands (within workspace)
```bash
# Initialize DDEV in project directory
# Replace <project-type> with your type: php, wordpress, laravel, drupal, etc.
ddev config --project-type=<project-type> --docroot=web

# Common examples:
# ddev config --project-type=wordpress --docroot=web
# ddev config --project-type=laravel --docroot=public
# ddev config --project-type=drupal --docroot=web
# ddev config --project-type=php --docroot=web

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
# Module: registry.coder.com/coder/vscode-web/coder ~> 1.0 (auto-updates to latest 1.0.x)
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
The startup script is inline in each template's `template.tf` (e.g. `freeform/template.tf`, inside the `coder_agent` resource's `startup_script` field). It performs:
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
- **Home directory**: Host path `/coder-workspaces/<owner>-<workspace>` → Container `/home/coder`
- **Docker cache**: Named volume `coder-<owner>-<workspace>-dind-cache` → `/var/lib/docker`
- **Homebrew**: Named volume `coder-<owner>-<workspace>-linuxbrew` → `/home/linuxbrew` — persists the Homebrew Cellar across workspace stop/start, so `brew upgrade`/`brew install` done inside a workspace survives restarts. Unlike the `/home/coder` bind mount, a fresh named volume is auto-populated by Docker from the image's existing `/home/linuxbrew` contents on first mount, so no manual copy step is needed — only an ownership fix (`sudo chown -R coder:coder /home/linuxbrew`) in the startup script. `HOMEBREW_CACHE` is set to `/home/linuxbrew/.cache/Homebrew` (via the Dockerfile) so the cache and Cellar always stay on the same filesystem, avoiding cross-device link (`EXDEV`) errors.
- **Isolation**: Each workspace gets separate host directory and Docker volumes

### Terraform Variables
Key template variables (e.g. in `freeform/template.tf`):
- `workspace_image_registry` - Docker registry URL (default: `index.docker.io/ddev/coder-ddev`)
- `image_version` - Image tag (default: `v0.1`; the Makefile passes `--variable image_version=$(cat VERSION)` at push time, so the root `VERSION` file is the single source of truth — no per-template copies)
- `cpu` / `memory` - Resource limits (defaults: 4 cores, 8GB RAM)
- `node_version` - Node.js version (default: `24`, informational only — Node is pre-installed in image)
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
- **Never use the local `main` branch** — always `git fetch upstream` and base branches on `upstream/main`. Use `upstream/main` for comparisons (e.g. `git diff upstream/main...HEAD`), not local `main`.
- **Never run `git push`, under any circumstances** — not to `main`, not to a feature branch, not to a fork. Commit locally and hand off to the user (or open a PR only if explicitly asked and only via a mechanism that doesn't require you to push, e.g. `gh pr create` from a branch the user has already pushed) — always let the user push.
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
4. **Python/Node** - Install Python 3, Node.js 24.x LTS
5. **Global npm tools** - OpenSpec, TypeScript (in image, re-attempted in startup)
6. **Docker daemon** - `docker-ce`, `docker-ce-cli`, `containerd`, systemd for Sysbox
7. **DDEV** - from official apt package (pkg.ddev.com)
8. **Homebrew (Linuxbrew)** - `bats-core`, `bats-support`, `bats-assert`, `go`, `golangci-lint`

### Important Build Notes
- User `coder` gets passwordless sudo: `coder ALL=(ALL) NOPASSWD:ALL`
- npm global packages go to `/home/coder/.npm-global` (user-scoped)
- Docker service enabled via systemd: `systemctl enable docker`
- PATH additions for `.local/bin` and `.npm-global/bin` in `/etc/profile.d/`

## Key Constraints

### Sysbox Requirement
- **Host must have Sysbox installed**: download `.deb` from [nestybox/sysbox releases](https://github.com/nestybox/sysbox/releases) and install with `apt-get install ./sysbox-ce_<version>.deb` (no apt repo available)
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

- `drupal-core/template.tf` - Drupal core development template (most actively developed)
- `drupal-contrib/template.tf` - Drupal contributed module development template
- `freeform/template.tf` - Multi-project freeform workspace template (keeps ddev-router)
- `image/Dockerfile` - Base image build instructions (shared by all templates)
- `image/scripts/.ddev/global_config.yaml` - DDEV defaults copied into workspaces
- `scripts/coder-delete-workspace-dir.sh` - Sudo wrapper for workspace host dir cleanup (must be installed on server)
- `scripts/cleanup-deleted-workspaces.sh` - Manual cleanup for orphaned workspace dirs/volumes
- `scripts/workspace-lifecycle-cleanup.sh` - Notifies then deletes idle workspaces; runs via systemd timer on coder.ddev.com (production only, see `scripts/workspace-lifecycle-cleanup.service`/`.timer`, must be installed on server)
- `VERSION` - Single source of truth for the image version; read by the Makefile and passed to every template as `--variable image_version=...` at push time (no per-template copies)
- `openspec/project.md` - Project conventions and constraints
- `openspec/AGENTS.md` - OpenSpec workflow instructions
