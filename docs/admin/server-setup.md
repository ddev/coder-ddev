# Server Setup Guide

This guide covers setting up a new Coder server with the DDEV template from scratch. It assumes a fresh Ubuntu 22.04 or 24.04 server.

## Overview

The full stack requires:
1. Docker (non-snap) — for running workspace containers
2. Sysbox — for safe nested Docker inside workspaces
3. Coder server — the control plane
4. This template — deployed to Coder

---

## Step 1: Install Docker

Docker must be installed from the official apt repository, **not** via snap (Sysbox requires the non-snap version).

```bash
# Install prerequisites
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg

# Add Docker's official GPG key and apt repo
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Verify
docker --version
sudo systemctl enable --now docker
```

---

## Step 2: Install Sysbox

Sysbox provides secure Docker-in-Docker without `--privileged`. It has no apt repository — install via `.deb` package.

```bash
# Install prerequisite
sudo apt-get install -y jq

# Download package (check https://github.com/nestybox/sysbox/releases for latest)
SYSBOX_VERSION=0.6.7
wget https://downloads.nestybox.com/sysbox/releases/v${SYSBOX_VERSION}/sysbox-ce_${SYSBOX_VERSION}-0.linux_amd64.deb

# Install (this will restart Docker)
sudo apt-get install -y ./sysbox-ce_${SYSBOX_VERSION}-0.linux_amd64.deb

# Verify
sysbox-runc --version
sudo systemctl status sysbox -n20
```

See [Sysbox install docs](https://github.com/nestybox/sysbox/blob/master/docs/user-guide/install-package.md) for details.

---

## Step 3: Install Coder

### Install the binary

```bash
curl -L https://coder.com/install.sh | sh
```

This installs the `coder` binary and a systemd service unit.

### Configure the service

Edit `/etc/coder.d/coder.env`:

```bash
sudo vim /etc/coder.d/coder.env
```

Key variables to set:

```bash
# The externally-reachable URL for your Coder deployment
# Use your server's hostname or IP. Must be reachable by users and workspaces.
CODER_ACCESS_URL=https://coder.example.com

# Address and port Coder listens on
CODER_HTTP_ADDRESS=0.0.0.0:3000

# PostgreSQL connection string (optional; Coder has a built-in database for small deployments)
# For production, use an external PostgreSQL instance:
# CODER_PG_CONNECTION_URL=postgresql://user:password@localhost/coder?sslmode=disable

# Optional: TLS configuration if not terminating TLS upstream
# CODER_TLS_ENABLE=true
# CODER_TLS_CERT_FILE=/etc/coder.d/coder.crt
# CODER_TLS_KEY_FILE=/etc/coder.d/coder.key
```

**Note:** For production deployments, an external PostgreSQL database is recommended over the built-in one. Install PostgreSQL with `sudo apt-get install -y postgresql` and create a `coder` database and user before setting `CODER_PG_CONNECTION_URL`.

### Start and enable Coder

```bash
sudo systemctl enable --now coder
sudo systemctl status coder
```

View logs:

```bash
journalctl -u coder -f
```

### First-run admin setup

Navigate to `http://<your-server>:3000` (or your `CODER_ACCESS_URL`) and create the initial admin user.

### Authenticate the CLI

On the machine where you'll manage templates (can be your local machine):

```bash
coder login https://coder.example.com
```

---

## Step 4: Deploy the DDEV Template

With Coder running and the CLI authenticated, follow the [Operations Guide](./operations-guide.md) to build the Docker image and push the template.

Quick summary:

```bash
# Clone this repository
git clone https://github.com/rfay/coder-ddev
cd coder-ddev

# Build and deploy
make deploy-ddev-user
```

---

## Adding Capacity: Additional Provisioner Nodes

Coder separates the **control plane** (the Coder server) from **provisioners** (the processes that run Terraform to create workspaces). By default, the Coder server includes a built-in provisioner. For additional capacity or to run workspaces on separate machines, you can run **external provisioner daemons**.

Each provisioner handles one concurrent workspace build. Running N provisioners allows N simultaneous workspace starts.

> **Note:** This section is a placeholder. Multi-node provisioner setup for this DDEV/Sysbox template has not yet been documented or tested. The notes below reflect the general Coder external provisioner model — verify against your setup before relying on them.

### How it works

- External provisioners connect to the Coder server over HTTP/S
- They need network access to the Coder server and to the Docker socket on their host
- Each provisioner host needs Docker + Sysbox installed (same as the primary server)
- Provisioners can be tagged to route specific templates to specific hosts

### General steps

**On the Coder server:**

```bash
# Create a provisioner key (scoped to your organization)
coder provisioner keys create my-provisioner-key --org default
# Save the output key — you'll need it on the provisioner node
```

**On each additional provisioner node:**

```bash
# Install Docker and Sysbox (same as Steps 1-2 above)

# Install the Coder binary (provisioner daemon only — no server needed)
curl -L https://coder.com/install.sh | sh

# Set credentials
export CODER_URL=https://coder.example.com
export CODER_PROVISIONER_DAEMON_KEY=<key-from-above>

# Start the provisioner daemon
coder provisioner start
```

For persistent operation, wrap this in a systemd service.

See [Coder external provisioner docs](https://coder.com/docs/admin/provisioners) for full details including Kubernetes and Docker deployment options.

---

## Troubleshooting

**Coder service won't start:**
```bash
journalctl -u coder -n50
# Check CODER_ACCESS_URL is set and reachable
# Check PostgreSQL is running if using external DB
```

**Sysbox containers fail to start:**
```bash
sysbox-runc --version          # Verify sysbox is installed
sudo systemctl status sysbox   # Check sysbox services are running
docker info | grep -i runtime  # Verify sysbox-runc appears as a runtime
```

**Workspaces can't reach Docker:**
```bash
# Inside a workspace
docker ps   # Should work if Sysbox is functioning
cat /tmp/dockerd.log
```

See [Troubleshooting Guide](./troubleshooting.md) for more.
