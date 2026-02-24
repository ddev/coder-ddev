# Server Setup Guide

This guide covers setting up a new Coder server with the DDEV template from scratch. It assumes a fresh Ubuntu 22.04 or 24.04 server.

## Overview

The full stack requires:
1. Docker (non-snap) — for running workspace containers
2. Sysbox — for safe nested Docker inside workspaces
3. PostgreSQL — for Coder's database (required for multi-server HA)
4. TLS certificate — via Let's Encrypt DNS challenge
5. Coder server — the control plane
6. This template — deployed to Coder

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

## Step 3: Install PostgreSQL

Coder ships with a built-in SQLite database that works fine for a single server. PostgreSQL is needed if you ever want to run multiple Coder server replicas (for redundancy or handling larger user load) — and migrating later is painful, so it's worth setting up now.

```bash
# Install PostgreSQL (Ubuntu ships a current version in its default repos)
sudo apt-get install -y postgresql

# Verify it's running
sudo systemctl enable --now postgresql
sudo systemctl status postgresql
```

### Create the Coder database and user

```bash
sudo -u postgres psql <<'EOF'
CREATE USER coder WITH PASSWORD 'strongpasswordhere';
CREATE DATABASE coder OWNER coder;
EOF
```

Replace `strongpasswordhere` with a strong password and record it — you'll need it in the Coder config.

### Verify the connection

```bash
psql -U coder -h localhost -d coder -c '\conninfo'
# Enter the password when prompted
```

If this fails with a peer authentication error, confirm `/etc/postgresql/*/main/pg_hba.conf` has a `md5` or `scram-sha-256` entry for local TCP connections (the default Ubuntu config should allow this for `localhost`).

---

## Step 4: Get a TLS Certificate

Coder has no built-in Let's Encrypt support — it reads certificate files directly. Obtain the certificate before configuring Coder. The DNS-01 challenge is the recommended approach because it works without opening port 80, supports wildcard certificates, and works even if your server isn't yet reachable on its final DNS name.

### Install certbot and a DNS provider plugin

```bash
sudo apt-get install -y certbot
```

Then install the plugin for your DNS provider. Common providers:

| Provider | Package |
|---|---|
| Cloudflare | `python3-certbot-dns-cloudflare` |
| AWS Route 53 | `python3-certbot-dns-route53` |
| DigitalOcean | `python3-certbot-dns-digitalocean` |
| Google Cloud DNS | `python3-certbot-dns-google` |

```bash
# Example for Cloudflare:
sudo apt-get install -y python3-certbot-dns-cloudflare
```

See [certbot's DNS plugin list](https://eff-certbot.readthedocs.io/en/stable/using.html#dns-plugins) for all supported providers.

### Create the provider credentials file

Each plugin needs API credentials. Example for Cloudflare:

```bash
sudo mkdir -p /etc/letsencrypt/secrets
sudo chmod 700 /etc/letsencrypt/secrets
sudo tee /etc/letsencrypt/secrets/cloudflare.ini > /dev/null <<'EOF'
dns_cloudflare_api_token = YOUR_CLOUDFLARE_API_TOKEN
EOF
sudo chmod 600 /etc/letsencrypt/secrets/cloudflare.ini
```

Create a Cloudflare API token scoped to **Zone / DNS / Edit** for the specific zone only (not a Global API Key).

### Request the certificate

```bash
sudo certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials /etc/letsencrypt/secrets/cloudflare.ini \
  -d coder.ddev.com \
  --email accounts@ddev.com \
  --agree-tos \
  --non-interactive
```

Replace `--dns-cloudflare` and `--dns-cloudflare-credentials` with the flag and credentials file for your provider. Replace `coder.ddev.com` with your actual hostname.

Certbot stores certificates in `/etc/letsencrypt/live/coder.ddev.com/`.

### Set up renewal with Coder restart

Certbot installs a systemd timer for automatic renewal. Add a deploy hook that fixes certificate permissions and restarts Coder. This hook runs after every renewal — and you'll also run it manually right now to fix permissions on the freshly-issued cert.

```bash
sudo tee /etc/letsencrypt/renewal-hooks/deploy/coder.sh > /dev/null <<'EOF'
#!/bin/bash
# The live/ directory contains symlinks into archive/ — permissions must
# be set on the archive files and all parent directories.
chmod 0755 /etc/letsencrypt/live
chmod 0755 /etc/letsencrypt/archive
chmod 0755 /etc/letsencrypt/live/coder.ddev.com
chmod 0755 /etc/letsencrypt/archive/coder.ddev.com
# Public cert files: world-readable
chmod 0644 /etc/letsencrypt/archive/coder.ddev.com/fullchain*.pem
chmod 0644 /etc/letsencrypt/archive/coder.ddev.com/chain*.pem
chmod 0644 /etc/letsencrypt/archive/coder.ddev.com/cert*.pem
# Private key: readable by coder group only
chmod 0640 /etc/letsencrypt/archive/coder.ddev.com/privkey*.pem
chgrp coder /etc/letsencrypt/archive/coder.ddev.com/privkey*.pem
# Restart Coder to pick up renewed cert
systemctl restart coder
EOF
sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/coder.sh
```

Run the hook now to fix permissions on the cert you just issued:

```bash
sudo /etc/letsencrypt/renewal-hooks/deploy/coder.sh
```

Test that automatic renewal will work:

```bash
sudo certbot renew --dry-run
```

### DNS note

If you're migrating an existing DNS name (e.g., `coder.ddev.com`) from another server, simply update the A record to point at the new server's IP once it is ready. The DNS-01 challenge succeeds regardless of which IP the A record points to, so you can get the certificate before the cutover.

---

## Step 5: Install Coder

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

#### Listening on port 443 (recommended for production)

Coder terminates TLS itself — no reverse proxy needed:

```bash
# Externally-reachable URL
CODER_ACCESS_URL=https://coder.ddev.com

# Serve HTTPS directly on port 443
CODER_TLS_ENABLE=true
CODER_TLS_ADDRESS=0.0.0.0:443
CODER_TLS_CERT_FILE=/etc/letsencrypt/live/coder.ddev.com/fullchain.pem
CODER_TLS_KEY_FILE=/etc/letsencrypt/live/coder.ddev.com/privkey.pem

# Redirect HTTP on port 80 to HTTPS
CODER_HTTP_ADDRESS=0.0.0.0:80
CODER_REDIRECT_TO_ACCESS_URL=true

# PostgreSQL connection (set up in Step 3)
CODER_PG_CONNECTION_URL=postgresql://coder:strongpasswordhere@localhost/coder?sslmode=disable
```

#### Alternative: plain HTTP or non-standard port

If you're running behind a reverse proxy (nginx, Caddy) that handles TLS, or just testing on a LAN:

```bash
CODER_ACCESS_URL=http://coder.ddev.com:3000
CODER_HTTP_ADDRESS=0.0.0.0:3000
# No TLS variables needed; your proxy handles termination
```

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

Navigate to `https://coder.ddev.com` and create the initial admin user.

### Authenticate the CLI

On the machine where you'll manage templates (can be your local machine):

```bash
coder login https://coder.ddev.com
```

### Configure GitHub OAuth (recommended)

The initial admin account must be created with username/password via the web UI (above). Once that's done, configure GitHub OAuth so all subsequent logins — including `coder login` from the CLI — can use GitHub instead.

**1. Create a GitHub OAuth App**

Go to [GitHub Developer Settings → OAuth Apps → New OAuth App](https://github.com/settings/developers) and fill in:

- **Application name**: `Coder (coder.ddev.com)` (or similar)
- **Homepage URL**: `https://coder.ddev.com`
- **Authorization callback URL**: `https://coder.ddev.com/api/v2/users/oauth2/github/callback`

After creating the app, generate a client secret. Note the **Client ID** and **Client Secret**.

**2. Add to `/etc/coder.d/coder.env`**

```bash
# GitHub OAuth
CODER_OAUTH2_GITHUB_CLIENT_ID=your-client-id
CODER_OAUTH2_GITHUB_CLIENT_SECRET=your-client-secret

# Allow sign-ups via GitHub (new users are created automatically on first login)
CODER_OAUTH2_GITHUB_ALLOW_SIGNUPS=true

# Restrict to members of a specific GitHub org (recommended):
CODER_OAUTH2_GITHUB_ALLOWED_ORGS=ddev

# Or allow any GitHub user (not recommended for a shared server):
# CODER_OAUTH2_GITHUB_ALLOW_EVERYONE=true
```

**3. Restart Coder**

```bash
sudo systemctl restart coder
```

GitHub will now appear as a login option in the web UI and `coder login` will open a browser for GitHub authentication.

**If you see "Signups are disabled":**

This means `CODER_OAUTH2_GITHUB_ALLOW_SIGNUPS` is not set or Coder wasn't restarted after it was added. Verify the env var is present and restart:

```bash
grep ALLOW_SIGNUPS /etc/coder.d/coder.env
sudo systemctl restart coder
```

There is also a toggle in the Coder admin UI at **Admin → Security** that can override the env var. Check that user sign-ups are not disabled there.

---

## Step 6: Deploy the DDEV Template

With Coder running and the CLI authenticated, follow the [Operations Guide](./operations-guide.md) to build the Docker image and push the template.

Quick summary:

```bash
# Clone this repository
git clone https://github.com/ddev/coder-ddev
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
export CODER_URL=https://coder.ddev.com
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
