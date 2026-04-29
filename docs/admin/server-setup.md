# Server Setup Guide

This guide covers setting up a new Coder server with the DDEV template from scratch. It assumes a fresh Ubuntu 24.04 LTS or higher LTS server. If you need to provision one on Hetzner, follow Step 1 below; otherwise skip to Step 2.

## Overview

The full stack requires:
1. Provisioning the server (Hetzner) — if starting from bare metal; skip if you already have a fresh Ubuntu 24.04 LTS or higher LTS install
2. Docker (non-snap) — for running workspace containers
3. Registry mirror — pull-through cache to speed up workspace starts and avoid Docker Hub rate limits
4. Sysbox — for safe nested Docker inside workspaces
5. PostgreSQL — for Coder's database (required for multi-server HA)
6. TLS certificate — via Let's Encrypt DNS challenge
7. Terraform — required before installing Coder (workaround for a Coder install bug)
8. Coder server — the control plane
9. This template — deployed to Coder

---

## Step 1: Provision the Server (Hetzner)

This section covers provisioning a fresh Ubuntu 24.04 LTS server on a Hetzner dedicated host. Skip it if you already have a clean Ubuntu 24.04 LTS or higher LTS install. The example matches the layout used for `staging-coder.ddev.com` (Intel i7-6700, 64 GB RAM, 2 × 512 GB NVMe), and scales unchanged to larger production hardware.

The recommended layout uses LVM on the system disk and a plain ext4 partition on the second disk:

| Mount | Source | Size (476 GiB disks) | Purpose |
| --- | --- | --- | --- |
| `/boot` | `/dev/nvme0n1p1` | 1 G | kernel and bootloader |
| `/` | `vg0/root` | 40 G | root filesystem |
| `/var` | `vg0/var` | 30 G | logs and packages |
| `/data` | `vg0/data` | rest of disk 1 (~400 G) | Docker data root (Step 2) |
| `/coder-workspaces` | `/dev/nvme1n1p1` | all of disk 2 (~470 G) | workspace files |

LVM means any of `root`, `var`, or `data` can be grown later with `lvextend -r`. Sizes above are deliberately generous for staging and scale up automatically on prod-sized disks because `data` claims the rest of the volume group.

> **Software RAID:** This guide uses `SWRAID 0` (no RAID) because the staging server has mismatched-purpose disks. For production with two matched disks, change to `SWRAID 1` with `SWRAIDLEVEL 1` and adjust the `PART` lines per Hetzner's installimage docs. RAID-1 across the system disk is recommended for prod; the second disk holding workspace files can be left out of the array if you intend to grow it independently.

> **Boot mode:** Hetzner servers default to Legacy/BIOS boot, and Hetzner Robot does not expose a UEFI toggle when activating the rescue system. Switching to UEFI requires firmware-level access via vKVM or a support ticket. For most installs Legacy/BIOS is fine; this guide assumes it. If you do switch to UEFI, add `PART /boot/efi esp 256M` as the first partition.

### Activate the rescue system

In [Hetzner Robot](https://robot.hetzner.com), go to your server → **Rescue** tab. Select **Linux**, leave the public key empty (you'll log in with the password Robot emails you), keyboard `us`, and click **Activate rescue system**. Then trigger a hardware reset from the **Reset** tab. After ~60 seconds, SSH in:

```bash
ssh root@YOUR_SERVER_IP
```

Confirm the rescue has come up by checking the banner — it should report your hardware and "Rescue System (via Legacy/CSM) up since…".

### Prepare the second-disk setup script

The Hetzner installer (`installimage`) only partitions the first drive when `SWRAID 0` is set. The second disk is set up after the first reboot. Stage the script in the rescue system now so it's ready to copy after install:

```bash
cat > /root/setup-disk2.sh <<'EOF'
#!/bin/bash
set -euo pipefail

DEV=/dev/nvme1n1
parted -s "$DEV" mklabel gpt mkpart primary ext4 1MiB 100%

udevadm settle
PART="${DEV}p1"

mkfs.ext4 -L coder-workspaces "$PART"
mkdir -p /coder-workspaces

UUID=$(blkid -s UUID -o value "$PART")
echo "UUID=$UUID  /coder-workspaces  ext4  defaults,nofail  0 2" >> /etc/fstab
EOF
chmod +x /root/setup-disk2.sh
```

`nofail` ensures a future flaky disk doesn't drop the server into emergency mode on boot.

### Write the installimage config file

`installimage` has an interactive `mcedit`-based editor, but pasting through SSH into it mangles whitespace and silently breaks the config. Skip the editor and feed `installimage` a config file with `-a -c`. Write it as a heredoc:

```bash
cat > /tmp/install.conf <<'EOF'
DRIVE1 /dev/nvme0n1
DRIVE2 /dev/nvme1n1
SWRAID 0
BOOTLOADER grub
HOSTNAME staging-coder.ddev.com

IMAGE /root/.oldroot/nfs/install/../images/Ubuntu-2404-noble-amd64-base.tar.gz

PART /boot  ext4  1G
PART lvm    vg0   all

LV vg0 root  /      ext4   40G
LV vg0 var   /var   ext4   30G
LV vg0 data  /data  ext4   all

SSHKEYS_URL https://github.com/YOUR_GITHUB_USERNAME.keys
EOF
```

Replace `staging-coder.ddev.com` with your hostname and `YOUR_GITHUB_USERNAME` with the GitHub account whose public keys should be installed on the new server.

> **Hostname note:** The Coder server's hostname must not collide with the wildcard subdomain reserved for workspace app routing. `*.coder.ddev.com` is used for workspaces, so the Coder server itself is `coder.ddev.com` and a parallel staging server lives at `staging-coder.ddev.com` (with `*.staging-coder.ddev.com` for its workspaces).

Verify the IMAGE filename actually exists in the rescue, since it changes occasionally:

```bash
ls /root/.oldroot/nfs/install/../images/ | grep -i ubuntu-2404
```

If the filename in `/tmp/install.conf` doesn't match, edit it before continuing.

### Run installimage

```bash
installimage -a -c /tmp/install.conf
```

`-a` skips the interactive editor; `-c` reads the config from the given file. installimage runs a syntax check, asks once to confirm it will wipe both drives, then partitions, installs Ubuntu, configures grub, and applies your `SSHKEYS_URL`. The whole process takes 3–6 minutes.

When it finishes, reboot:

```bash
reboot
```

### First login and second-disk setup

Wait ~60 seconds for the new system to boot. The rescue's SSH host key changes after install; clear the old entry and log in with your GitHub keys:

```bash
ssh-keygen -R YOUR_SERVER_IP
ssh root@YOUR_SERVER_IP
```

The second disk is now bare. Some installimage versions advertise a `POST_INSTALL` hook that runs scripts inside the freshly installed system, but it fails silently and is unreliable — set up the second disk by hand. Re-create the same script we staged in rescue, or paste these commands directly:

```bash
sudo parted -s /dev/nvme1n1 mklabel gpt mkpart primary ext4 1MiB 100%
sudo udevadm settle
sudo mkfs.ext4 -L coder-workspaces /dev/nvme1n1p1
sudo mkdir -p /coder-workspaces
UUID=$(sudo blkid -s UUID -o value /dev/nvme1n1p1)
echo "UUID=$UUID  /coder-workspaces  ext4  defaults,nofail  0 2" | sudo tee -a /etc/fstab
sudo mount -a
```

### Verify

```bash
hostnamectl
df -h
lsblk
```

You should see all five mounts (`/boot`, `/`, `/var`, `/data`, `/coder-workspaces`) sized as designed, and `lsblk` should show LVM logical volumes on `nvme0n1` plus a single ext4 partition on `nvme1n1`.

The server is now a clean Ubuntu 24.04 LTS host ready for the rest of this guide. Proceed to Step 2 (Install Docker).

---

## Step 2: Install Docker

Docker must be installed from the official apt repository, **not** via snap (Sysbox requires the non-snap version).

```bash
# Install prerequisites
sudo apt-get update
sudo apt-get install -y ca-certificates curl

# Add Docker's GPG key and apt repo (DEB822 format)
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo tee /etc/apt/keyrings/docker.asc > /dev/null
sudo chmod a+r /etc/apt/keyrings/docker.asc
printf "Types: deb\nURIs: https://download.docker.com/linux/ubuntu\nSuites: %s\nComponents: stable\nArch: %s\nSigned-By: /etc/apt/keyrings/docker.asc\n" \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" \
  "$(dpkg --print-architecture)" | \
  sudo tee /etc/apt/sources.list.d/docker.sources > /dev/null

# Install Docker
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Configure Docker to use /data as its data root
sudo tee /etc/docker/daemon.json > /dev/null <<'EOF'
{
  "data-root": "/data/docker"
}
EOF

# Verify
docker --version
sudo systemctl enable --now docker
```

---

## Step 3: Set Up the Registry Mirror

A pull-through registry mirror caches Docker Hub images locally, so workspace startups pull images from the host rather than Docker Hub. This dramatically speeds up first-start time and avoids Docker Hub rate limits.

The workspace image no longer hardcodes any mirror host. The startup script now uses this strategy:

1. If `docker_registry_mirror` is explicitly set, use it.
2. Otherwise, try `http://<coder-host>:5000` (derived from `CODER_AGENT_URL`) and use it only if `GET /v2/` is reachable.
3. If no reachable mirror is found, continue without a mirror.

This means `staging-coder.ddev.com` and `coder.ddev.com` work automatically when their local registry mirror is running.

Optional override (for nonstandard host/port, or to force a specific mirror) can still be set on the provisioner host:

```bash
sudo tee /etc/systemd/system/coder-provisioner.service.d/10-registry-mirror.conf > /dev/null <<'EOF'
[Service]
Environment=TF_VAR_docker_registry_mirror=http://coder.ddev.com:5000
EOF

sudo systemctl daemon-reload
sudo systemctl restart coder-provisioner
```

Replace `http://coder.ddev.com:5000` with your preferred mirror address when needed.
If your install uses a different provisioner service name, apply the same `TF_VAR_docker_registry_mirror=...` environment variable to that service instead.

### Create directories and config

```bash
sudo mkdir -p /opt/registry/data

sudo tee /opt/registry/config.yml > /dev/null <<'EOF'
version: 0.1
log:
  level: info
storage:
  filesystem:
    rootdirectory: /var/lib/registry
http:
  addr: :5000
proxy:
  remoteurl: https://registry-1.docker.io
EOF
```

### Open the firewall port

```bash
sudo ufw allow 5000/tcp
```

### Create a systemd unit

```bash
sudo tee /etc/systemd/system/registry-mirror.service > /dev/null <<'EOF'
[Unit]
Description=Docker Registry Pull-Through Cache (registry:3)
After=network-online.target docker.service
Wants=network-online.target docker.service

[Service]
Type=simple
Restart=always
RestartSec=5

# Clean up any previous instance
ExecStartPre=-/usr/bin/docker rm -f registry-mirror

ExecStart=/usr/bin/docker run --rm \
  --name registry-mirror \
  -p 0.0.0.0:5000:5000 \
  -v /opt/registry/config.yml:/etc/distribution/config.yml:ro \
  -v /opt/registry/data:/var/lib/registry \
  registry:3

ExecStop=/usr/bin/docker stop registry-mirror

[Install]
WantedBy=multi-user.target
EOF
```

### Enable and start

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now registry-mirror
sudo systemctl status registry-mirror
```

### Verify

```bash
# Should return an empty repository list (not a connection error)
curl http://localhost:5000/v2/_catalog
```

---

## Step 4: Install Sysbox

Sysbox provides secure Docker-in-Docker without `--privileged`. It has no apt repository — install via `.deb` package.

```bash
# Install prerequisite
sudo apt-get install -y jq

# Download package (check https://github.com/nestybox/sysbox/releases for latest)
SYSBOX_VERSION=0.6.7
wget https://downloads.nestybox.com/sysbox/releases/v${SYSBOX_VERSION}/sysbox-ce_${SYSBOX_VERSION}-0.linux_amd64.deb

# The Sysbox installer restarts Docker — stop any running containers first
sudo systemctl stop registry-mirror

# Install (this will restart Docker)
sudo apt-get install -y ./sysbox-ce_${SYSBOX_VERSION}-0.linux_amd64.deb

# Restart the registry mirror
sudo systemctl start registry-mirror

# Verify
sysbox-runc --version
sudo systemctl status sysbox -n20
```

See [Sysbox install docs](https://github.com/nestybox/sysbox/blob/master/docs/user-guide/install-package.md) for details.

---

## Step 5: Install PostgreSQL

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

## Step 6: Get a TLS Certificate

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

The cert must cover both the base domain and the wildcard — the wildcard is required for workspace app subdomain routing (e.g. `ddev-web--myworkspace--rfay.coder.ddev.com`). DNS-01 is the only challenge type that supports wildcards.

```bash
sudo certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials /etc/letsencrypt/secrets/cloudflare.ini \
  -d coder.ddev.com \
  -d '*.coder.ddev.com' \
  --email accounts@ddev.com \
  --agree-tos \
  --non-interactive
```

Replace `--dns-cloudflare` and `--dns-cloudflare-credentials` with the flag and credentials file for your provider. Replace `coder.ddev.com` with your actual hostname.

Certbot stores certificates in `/etc/letsencrypt/live/coder.ddev.com/`.

**If you already have a cert for just `coder.ddev.com`**, expand it in place with `--expand` (paths remain the same, no Coder config change needed):

```bash
sudo certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials /etc/letsencrypt/secrets/cloudflare.ini \
  -d coder.ddev.com \
  -d '*.coder.ddev.com' \
  --email accounts@ddev.com \
  --agree-tos \
  --non-interactive \
  --expand
```

### Set up renewal with Coder restart

Certbot installs a systemd timer for automatic renewal. Add a deploy hook that fixes certificate permissions and restarts Coder after each renewal.

```bash
sudo tee /etc/letsencrypt/renewal-hooks/deploy/restart-coder.sh > /dev/null <<'EOF'
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
sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/restart-coder.sh
```

> **Note:** The hook uses `chgrp coder`, which requires the `coder` system group to exist. That group is created when Coder is installed in Step 8. Run the hook and test renewal **after** completing Step 8 — see the "Fix cert permissions and test renewal" subsection there.

### DNS note

If you're migrating an existing DNS name (e.g., `coder.ddev.com`) from another server, simply update the A record to point at the new server's IP once it is ready. The DNS-01 challenge succeeds regardless of which IP the A record points to, so you can get the certificate before the cutover.

---

## Step 7: Install Terraform

Coder attempts to install Terraform automatically on first boot, but this fails due to a bug ([coder/coder#24578](https://github.com/coder/coder/issues/24578)). Install Terraform manually beforehand to work around it.

```bash
# Install prerequisites
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common

# Add HashiCorp's GPG key
wget -O- https://apt.releases.hashicorp.com/gpg | \
  gpg --dearmor | \
  sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null

# Add the official HashiCorp apt repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
  https://apt.releases.hashicorp.com \
  $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list

# Install Terraform
sudo apt-get update
sudo apt-get install -y terraform

# Verify
terraform --version
```

---

## Step 8: Install Coder

### Install the binary

Download and install the latest release directly from GitHub. The `install.sh` convenience script exists but has had version-resolution failures — the direct `.deb` approach is more reliable:

```bash
CODER_VERSION=$(curl -fsSL "https://api.github.com/repos/coder/coder/releases/latest" | \
  jq -r '.tag_name' | tr -d v)
curl -fsSL -o /tmp/coder.deb \
  "https://github.com/coder/coder/releases/download/v${CODER_VERSION}/coder_${CODER_VERSION}_linux_amd64.deb"
sudo apt-get install -y /tmp/coder.deb
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

# Wildcard domain for workspace app subdomain routing (requires *.coder.ddev.com DNS + cert)
CODER_WILDCARD_ACCESS_URL=*.coder.ddev.com

# PostgreSQL connection (set up in Step 5)
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

> **Important:** Use your GitHub username as the Coder username (e.g. `rfay`). When you later log in via GitHub OAuth, Coder matches on username — if the name is already taken it creates a second account with a random suffix (e.g. `rfay-wanderingortiz8`) which will not have admin permissions. Getting the username right here avoids that entirely.

### Authenticate the CLI

On the machine where you'll manage templates (can be your local machine):

```bash
coder login https://coder.ddev.com
```

### Configure GitHub OAuth (recommended)

The initial admin account must be created with username/password via the web UI (above). Once that's done, configure GitHub OAuth so all subsequent logins — including `coder login` from the CLI — can use GitHub instead.

> **If you already have a duplicate account** (e.g. `rfay` password account and `rfay-wanderingortiz8` GitHub account): Coder does not support renaming users in the UI or reliably via the API. Fix it directly in PostgreSQL:
> ```bash
> sudo -u postgres psql coder -c "UPDATE users SET username='rfay' WHERE username='rfay-wanderingortiz8';"
> sudo systemctl restart coder
> ```
> You will also need to delete the original password account (`rfay`) first if it still exists, or rename it out of the way the same way.

**1. Create a GitHub OAuth App**

Create the app under your **GitHub organization**, not your personal account — apps created under a personal account show "by \<username\>" on the authorization screen instead of "by \<org\>". Go to **github.com/organizations/\<your-org\>/settings/applications → New OAuth App** and fill in:

- **Application name**: `Coder (coder.ddev.com)` (or similar)
- **Homepage URL**: `https://coder.ddev.com`
- **Authorization callback URL**: `https://coder.ddev.com/api/v2/users/oauth2/github/callback`
- **Enable Device Flow**: leave unchecked (see note below)

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

> **Device Flow:** Do not set `CODER_OAUTH2_GITHUB_DEVICE_FLOW=true` when `CODER_OAUTH2_GITHUB_ALLOWED_ORGS` is set. Device flow routes all GitHub logins through a code-based flow that does not request `read:org` scope — org membership checks fail with a 403 and users cannot log in.

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

### Fix cert permissions and test renewal

Now that the `coder` system group exists, run the deploy hook you created in Step 6 to fix permissions on the certificate files:

```bash
sudo /etc/letsencrypt/renewal-hooks/deploy/restart-coder.sh
```

Then confirm that automatic renewal will work end-to-end:

```bash
sudo certbot renew --dry-run
```

A "Congratulations, all simulated renewals succeeded" message means the hook, DNS credentials, and timer are all wired up correctly.

---

## Step 9: Deploy the DDEV Templates

With Coder running and the CLI authenticated, follow the [Operations Guide](./operations-guide.md) to build the Docker image and push the templates.

Quick summary:

```bash
# Clone this repository
git clone https://github.com/ddev/coder-ddev
cd coder-ddev

# Build the image, push it, and deploy all three templates
make deploy-user-defined-web
make push-template-drupal-core
make push-template-freeform
```

This deploys three templates:
- **user-defined-web** — general-purpose DDEV workspace; users configure their own project type
- **freeform** — DDEV workspace using Traefik for more flexible routing
- **drupal-core** — Drupal core development environment (see Step 10 for the recommended seed cache setup)

---

## Step 10: Set Up the Drupal Core Seed Cache (optional, highly recommended)

The `drupal-core` template can provision a fully configured Drupal core development environment on new workspaces using a **seed cache** on the host. Without the cache, first-time workspace setup downloads a full git clone and all composer dependencies (~10-13 minutes). With the cache, the install phase drops to ~15 seconds, and total workspace startup is about a minute.

The cache is a standing DDEV project on the host that is periodically refreshed. New workspaces copy the git checkout, vendor directory, and a pre-built database snapshot from it.

### Prerequisites

DDEV must be installed on the Coder server itself (not just inside workspaces). The host DDEV project runs on the host Docker daemon, separate from the Sysbox workspace containers.

Follow the [DDEV Linux installation instructions](https://docs.ddev.com/en/stable/users/install/ddev-installation/#ddev-installation-linux) to install DDEV on the host.

> **User note:** The seed cache must be owned and operated by a normal (non-root) user. DDEV refuses to run as root. All the commands below, and the systemd service, must run as that user — not with `sudo`. On this server the user is `rfay`; adjust for your own setup.

### One-time initial setup

Run these commands as your normal (non-root) user — **not** as root:

```bash
mkdir -p ~/cache/drupal-core-seed
cd ~/cache/drupal-core-seed

# Configure DDEV project
ddev config --project-type=drupal12 --php-version=8.5 --docroot=web \
  --project-name=drupal-core-seed
ddev start

# Create the full drupal-core development project (takes 5-10 minutes)
ddev composer create-project joachim-n/drupal-core-development-project --no-interaction

# Add Drush
ddev composer require drush/drush

# Install Drupal with the demo_umami profile
ddev drush si -y demo_umami --account-pass=admin

# Export the database snapshot used by new workspaces
mkdir -p .tarballs
ddev export-db --file=.tarballs/db.sql.gz
```

After this runs, the seed directory contains:

| Path | Contents |
|------|----------|
| `composer.json` / `composer.lock` | Project definition |
| `repos/drupal/` | Git clone of Drupal core |
| `vendor/` | All Composer packages |
| `web/` | Docroot (symlinked) |
| `.tarballs/db.sql.gz` | Installed database snapshot |
| `.ddev/` | Host DDEV config — **not** copied to workspaces |

### Install the hourly update timer

The update script runs `composer update`, a fresh `drush si` (site install), and `export-db` to keep the cache current with Drupal HEAD. Install it as an hourly systemd timer:

```bash
REPO=~/workspace/coder-ddev   # adjust if your repo is elsewhere

# Install the update script to a standard system path
sudo install -m 755 $REPO/drupal-core/scripts/update-drupal-cache \
  /usr/local/bin/update-drupal-cache

# Install the systemd units
sudo install -m 644 $REPO/drupal-core/scripts/drupal-cache-updater.service \
  /etc/systemd/system/
sudo install -m 644 $REPO/drupal-core/scripts/drupal-cache-updater.timer \
  /etc/systemd/system/

# If your seed directory or cache user differs from the defaults, edit the service:
#   sudo vim /etc/systemd/system/drupal-cache-updater.service
# See the comments in that file for User and --seed-dir guidance.

sudo systemctl daemon-reload
sudo systemctl enable --now drupal-cache-updater.timer

# Verify the timer is scheduled
systemctl list-timers drupal-cache-updater.timer
```

### Manual refresh

Run an update at any time (e.g. after a major Drupal release):

```bash
/usr/local/bin/update-drupal-cache

# If your seed directory differs from the default:
/usr/local/bin/update-drupal-cache --seed-dir /your/cache/path

# Or via systemd to capture output in journald:
sudo systemctl start drupal-cache-updater.service
journalctl -u drupal-cache-updater.service -f
```

### Template variable

The template uses a `cache_path` variable for the host-side seed directory. The default in both `drupal-core/template.tf` and the `Makefile` is currently hardcoded to the path on this server (`/home/rfay/cache/drupal-core-seed`), so `make push-template-drupal-core` works without any override on this server.

**On a different server or with a different user**, update the defaults before deploying:

```bash
# In Makefile, change:
DRUPAL_CACHE_PATH ?= /home/youruser/cache/drupal-core-seed

# In drupal-core/template.tf, change:
variable "cache_path" {
  default = "/home/youruser/cache/drupal-core-seed"
}
```

Or override at deploy time without changing files:

```bash
make push-template-drupal-core DRUPAL_CACHE_PATH=/home/youruser/cache/drupal-core-seed
```

### How new workspaces use the cache

When a workspace starts for the first time:

1. The startup script checks for a valid seed at `/home/coder-cache-seed` (the read-only bind mount of `cache_path`)
2. **Cache hit:** `rsync` copies the project files (excluding `.ddev/`), `ddev composer install` ensures vendor is current, then `ddev import-db` loads the database dump (~15 seconds total)
3. **Cache miss** (path absent or incomplete): falls back to full `ddev composer create-project` + `ddev drush si` — slower but always works

Check workspace startup logs in the Coder dashboard or at `/tmp/drupal-setup.log` inside the workspace to confirm which path was taken.

### Troubleshooting

**Cache not being used:**
- Verify the seed directory exists and is populated: `ls $SEED_DIR/composer.json $SEED_DIR/.tarballs/db.sql.gz`
- Confirm `cache_path` in the deployed template matches your actual seed directory (check with `coder templates show drupal-core`)
- Check the workspace startup log for the "Cache mount check" diagnostic block — it shows exactly which files were found or missing at the bind mount path
- Look for "Cache hit" in the log; "No cache available" means the path is absent or the seed was never initialized

**Seed project won't start after server reboot:**
```bash
cd ~/cache/drupal-core-seed && ddev start
```

**Update script fails:**
```bash
cd ~/cache/drupal-core-seed
ddev describe   # verify DDEV is running
ddev logs       # check container logs for errors
```

---

## Step 11: Set Up Discord Notifications

Coder can send webhook notifications to Discord for events like new user signups, workspace creation/deletion, and workspace health alerts. This uses a small relay service that translates Coder's webhook format to Discord's.

### Create a Discord webhook

In Discord, go to the target channel → **Edit Channel** → **Integrations** → **Webhooks** → **New Webhook**. Copy the webhook URL and keep it secret — treat it like a password.

### Install the relay service

```bash
REPO=~/workspace/coder-ddev   # adjust if your repo is elsewhere

# Install the relay script
sudo install -m 755 $REPO/scripts/coder-discord-relay /usr/local/bin/

# Create the env file with your Discord webhook URL
sudo tee /etc/coder-discord-relay.env > /dev/null <<'EOF'
DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/YOUR_WEBHOOK_URL_HERE
LISTEN_PORT=9876
EOF
sudo chmod 600 /etc/coder-discord-relay.env

# Install and start the systemd service
sudo install -m 644 $REPO/scripts/coder-discord-relay.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now coder-discord-relay

# Verify it's running
curl -s http://localhost:9876/
```

### Configure Coder to send webhooks

Add to `/etc/coder.d/coder.env`:

```bash
CODER_NOTIFICATIONS_METHOD=webhook
CODER_NOTIFICATIONS_WEBHOOK_ENDPOINT=http://localhost:9876/
```

Then restart Coder:

```bash
sudo systemctl restart coder
```

### Configure which events to receive

**Deployment-level method** (admin): Go to `https://coder.ddev.com/deployment/notifications?tab=events` and set desired events to use the webhook method.

**User preferences** (per-user opt-in): Go to `https://coder.ddev.com/settings/notifications` and enable specific events. Some events (e.g. "Workspace Created") are disabled by default and must be explicitly enabled here — the deployment events page only sets the delivery method, not whether the event fires for you.

Recommended events to enable:
- **User account created** — fires when any user signs up (admin-facing, enabled by default)
- **Workspace Created** — fires when you or another user creates a workspace (must opt in at `/settings/notifications`)
- **Workspace Deleted** — workspace removed
- **Workspace Autobuild Failed**, **Workspace Marked as Dormant** — operational alerts

### Test it

```bash
curl -X POST http://localhost:9876/ \
  -H "Content-Type: application/json" \
  -d '{"title":"Test","body":"Relay is working"}'
```

This should post a message to your Discord channel.

### Notes

- The relay listens on `127.0.0.1` only — it is not exposed externally
- Logs: `sudo journalctl -u coder-discord-relay -q -f`
- The relay formats workspace and user events compactly; all other events fall back to Coder's pre-formatted title
- If you regenerate the Discord webhook URL, update `/etc/coder-discord-relay.env` and restart the relay

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
# Install Docker and Sysbox (same as Steps 2 and 4 above)

# Install the Coder binary (provisioner daemon only — no server needed)
CODER_VERSION=$(curl -fsSL "https://api.github.com/repos/coder/coder/releases/latest" | \
  jq -r '.tag_name' | tr -d v)
curl -fsSL -o /tmp/coder.deb \
  "https://github.com/coder/coder/releases/download/v${CODER_VERSION}/coder_${CODER_VERSION}_linux_amd64.deb"
sudo apt-get install -y /tmp/coder.deb

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
