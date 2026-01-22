# DDEV Coder Template

Coder workspace template for Drupal development with ddev, Docker-in-Docker support, Node.js, and Git.

## Features

- **Custom Base Image**: Ubuntu 24.04 with curl/wget/sudo pre-installed
- **Docker-in-Docker**: Full Docker support for ddev
- **Node.js/npm**: LTS version (default: 20.x)
- **ddev**: v1.24.10 installed to `~/.ddev/bin/ddev`
- **PHP/Composer**: Via ddev containers

## Configuration

**Container:**
- User: `coder` (UID 1000)
- Docker group: GID 988 (via `group_add`)
- Privileged mode: `true` (required for ddev)
- Docker socket: Mounted from host

**Installed Tools:**
- Docker CLI (latest stable)
- ddev v1.24.10
- Node.js LTS (configurable via `node_version` variable)
- Git, vim, build tools

## Deployment

Deploy the template to Coder:

```bash
coder templates push --directory coder-ddev --name coder-ddev --yes
```

## Usage

Create a new workspace using the template:

```bash
coder create --template coder-ddev <workspace-name>
```
