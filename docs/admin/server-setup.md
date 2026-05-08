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

# Configure containerd to use /data as well.
# containerd runs as a separate daemon from Docker and has its own data root
# (default: /var/lib/containerd). Without this, /var fills up with image snapshots.
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's|^root = .*|root = "/data/containerd"|' /etc/containerd/config.toml

# Verify
docker --version
sudo systemctl enable --now containerd
sudo systemctl enable --now docker
```

### Configure the firewall

Enable UFW and open the ports needed by Coder and the registry mirror. Port 5665 is for the Icinga2 monitoring agent and should be restricted to the monitoring server's IP:

```bash
sudo ufw allow 22
sudo ufw allow 80
sudo ufw allow 443
sudo ufw allow 5000
sudo ufw allow from 45.79.99.253 to any port 5665/tcp
sudo ufw enable
sudo ufw status
```

Expected output:

```text
Status: active

To                         Action      From
--                         ------      ----
443                        ALLOW       Anywhere
80                         ALLOW       Anywhere
22                         ALLOW       Anywhere
5000                       ALLOW       Anywhere
5665/tcp                   ALLOW       45.79.99.253
443 (v6)                   ALLOW       Anywhere (v6)
80 (v6)                    ALLOW       Anywhere (v6)
22 (v6)                    ALLOW       Anywhere (v6)
5000 (v6)                  ALLOW       Anywhere (v6)
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

Coder terminates TLS itself — no reverse proxy needed. Replace `coder.example.com` with your actual hostname throughout:

```bash
# Externally-reachable URL — replace with your hostname
CODER_ACCESS_URL=https://coder.example.com

# Serve HTTPS directly on port 443
CODER_TLS_ENABLE=true
CODER_TLS_ADDRESS=0.0.0.0:443
CODER_TLS_CERT_FILE=/etc/letsencrypt/live/coder.example.com/fullchain.pem
CODER_TLS_KEY_FILE=/etc/letsencrypt/live/coder.example.com/privkey.pem

# Redirect HTTP on port 80 to HTTPS
CODER_HTTP_ADDRESS=0.0.0.0:80
CODER_REDIRECT_TO_ACCESS_URL=true

# Wildcard domain for workspace app subdomain routing (requires *.coder.example.com DNS + cert)
CODER_WILDCARD_ACCESS_URL=*.coder.example.com

# PostgreSQL connection (set up in Step 5) — replace the password
CODER_PG_CONNECTION_URL=postgresql://coder:strongpasswordhere@localhost/coder?sslmode=disable

# Telemetry — disable if you prefer not to send usage data to Coder
CODER_TELEMETRY=false
```

#### Alternative: plain HTTP or non-standard port

If you're running behind a reverse proxy (nginx, Caddy) that handles TLS, or just testing on a LAN:

```bash
CODER_ACCESS_URL=http://coder.example.com:3000
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

### Allow Coder to delete workspace directories

When a workspace is deleted, a Terraform destroy-time provisioner calls a wrapper script to remove the workspace's host directory. The Coder service runs as the `coder` system user (UID 999) and needs root to delete entries from `/coder-workspaces/` (owned by root).

The Coder systemd service sets `NoNewPrivileges`, which blocks sudo. Override that, install the wrapper, and configure sudoers:

```bash
# Allow the coder service to use sudo (needed for workspace directory cleanup)
sudo mkdir -p /etc/systemd/system/coder.service.d/
printf '[Service]\nNoNewPrivileges=no\nCapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK CAP_NET_BIND_SERVICE CAP_SETUID CAP_SETGID CAP_AUDIT_WRITE CAP_DAC_OVERRIDE\n' \
  | sudo tee /etc/systemd/system/coder.service.d/allow-privileges.conf
sudo systemctl daemon-reload && sudo systemctl restart coder

# Install the wrapper script
sudo install -m 755 scripts/coder-delete-workspace-dir.sh /usr/local/bin/coder-delete-workspace-dir

# Grant coder user sudo access to only that script (runs as root)
echo 'coder ALL=(root) NOPASSWD: /usr/local/bin/coder-delete-workspace-dir' \
  | sudo tee /etc/sudoers.d/coder-workspace-cleanup
sudo chmod 0440 /etc/sudoers.d/coder-workspace-cleanup
sudo visudo -c
```

The wrapper validates that the argument matches exactly `/coder-workspaces/<alphanumeric-name>` before deleting, preventing path traversal even though the script runs as root.

Without this setup, workspace deletion will log permission errors and leave the directory behind (recoverable with `scripts/cleanup-deleted-workspaces.sh`).

### First-run admin setup

Navigate to `https://coder.example.com` (your hostname) and create the initial admin user.

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

Create the app under your **GitHub organization**, not your personal account — apps created under a personal account show "by \<username\>" on the authorization screen instead of "by \<org\>". Go to **github.com/organizations/ddev/settings/applications → New OAuth App** and fill in:

- **Application name**: `Coder (coder.ddev.com)`
- **Homepage URL**: `https://coder.ddev.com`
- **Authorization callback URL**: `https://coder.ddev.com/api/v2/users/oauth2/github/callback`
- **Enable Device Flow**: leave unchecked (see note below)

After creating the app, generate a client secret. Note the **Client ID** and **Client Secret**.

#### Two OAuth Apps: staging and production

Register **two separate OAuth Apps** — one for staging, one for production. Separate apps isolate credentials between environments so that a staging secret compromise cannot affect production, and secret rotation on one environment does not require touching the other.

**Staging app settings:**

- **Application name**: `Coder (staging-coder.ddev.com)`
- **Homepage URL**: `https://staging-coder.ddev.com`
- **Authorization callback URL**: `https://staging-coder.ddev.com/api/v2/users/oauth2/github/callback`
- **Enable Device Flow**: leave unchecked

**Production app settings** (same as above):

- **Application name**: `Coder (coder.ddev.com)`
- **Homepage URL**: `https://coder.ddev.com`
- **Authorization callback URL**: `https://coder.ddev.com/api/v2/users/oauth2/github/callback`
- **Enable Device Flow**: leave unchecked

Use the staging app's Client ID and Client Secret in `/etc/coder.d/coder.env` on staging-coder.ddev.com, and the production app's credentials on coder.ddev.com.

**2. Add to `/etc/coder.d/coder.env`**

```bash
# GitHub OAuth
CODER_OAUTH2_GITHUB_CLIENT_ID=your-client-id
CODER_OAUTH2_GITHUB_CLIENT_SECRET=your-client-secret

# Allow sign-ups via GitHub (new users are created automatically on first login)
CODER_OAUTH2_GITHUB_ALLOW_SIGNUPS=true

# Access control: ddev org members, coder-ddev-com managed list, and $100+/month sponsor orgs
# Institute-for-Advanced-Studies is included but not yet verified — confirm the org identity before deploying
CODER_OAUTH2_GITHUB_ALLOWED_ORGS=ddev,coder-ddev-com,tag1consulting,upsun,platformsh,Institute-for-Advanced-Studies,CPS-IT,redfinsolutions,Lullabot,b13,pixelandtonic,Cambrico,centarro,8mylez,dkd,liip,i-gelb,FameHelsinki,Gizra,mobilistics,OPTASY,passbolt,vaersaagod,affinitybridge,AGILEDROP,NPO-Applications-GmbH,AtenDesignGroup

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

### Managing individual access via `coder-ddev-com`

The `coder-ddev-com` GitHub organization is the managed access list for individuals who do not belong to the `ddev` org or one of the sponsor orgs. Adding someone to `coder-ddev-com` grants them signup access to coder.ddev.com without requiring a Coder server restart.

**To grant access to an individual:**

1. Go to **github.com/coder-ddev-com** → **People** → **Invite member**
2. Enter the person's GitHub username and send the invitation
3. Once they accept, they can log in to coder.ddev.com via GitHub OAuth

**Initial members** (add these when creating the org):

- `dougvann` — individual $100/month GitHub Sponsor
- `claudiu-cristea` — Webikon sponsor (linked as individual on ddev.com)
- Add LetsTalk, Amedick Sommer, and Pottkinder GmbH contacts when their GitHub usernames are confirmed

**Note on private membership:** Users do not need to make their `coder-ddev-com` membership public. Private membership is sufficient — the `read:org` OAuth scope allows Coder to verify membership regardless of visibility setting.

### Sponsor org access policy

All $100+/month DDEV sponsors receive access as an org-level benefit: every member of a sponsor's GitHub org can sign in to coder.ddev.com without individual enrollment in `coder-ddev-com`. MacStadium and JetBrains are excluded (in-kind, not cash sponsors).

| Company | GitHub org | Source |
| ------- | ---------- | ------ |
| Tag1 | `tag1consulting` | invoiced |
| Upsun | `upsun` | invoiced |
| Platform.sh (Upsun predecessor) | `platformsh` | invoiced |
| Institute for Advanced Studies | `Institute-for-Advanced-Studies` ⚠️ | invoiced |
| CPS-IT | `CPS-IT` | invoiced |
| Redfin Solutions | `redfinsolutions` | invoiced + featured |
| Lullabot | `Lullabot` | invoiced |
| B13 | `b13` | invoiced + featured |
| Pixel & Tonic (Craft CMS) | `pixelandtonic` | invoiced + featured |
| Cambrico | `Cambrico` | invoiced + featured |
| Centarro | `centarro` | invoiced + featured |
| 8mylez | `8mylez` | invoiced |
| dkd Internet Service GmbH | `dkd` | GitHub Sponsors |
| Liip | `liip` | GitHub Sponsors |
| i-gelb GmbH | `i-gelb` | featured |
| Fame Helsinki | `FameHelsinki` | featured |
| Gizra | `Gizra` | featured |
| mobilistics GmbH | `mobilistics` | featured |
| OPTASY | `OPTASY` | featured |
| Passbolt | `passbolt` | featured |
| Værsågod | `vaersaagod` | featured |
| Affinity Bridge | `affinitybridge` | featured |
| Agiledrop | `AGILEDROP` | featured |
| NPO Applications GmbH | `NPO-Applications-GmbH` | featured |
| Aten Design Group | `AtenDesignGroup` | featured |

⚠️ `Institute-for-Advanced-Studies` — GitHub org exists but has no public name or description. Confirm with an operator that this is the correct org before deploying.

Sponsors with no confirmed GitHub org (access via `coder-ddev-com` individual membership instead): LetsTalk, Amedick Sommer, Pottkinder GmbH.

#### Adding a new sponsor org

When a new organization reaches the $100+/month sponsorship level:

1. **Find their GitHub org slug**: Check the sponsor's GitHub profile or ask them directly. Verify with `gh api orgs/<slug> --jq '.login'` — if the command returns the slug, the org exists.

2. **Add the slug to `ALLOWED_ORGS`** on both staging and production:

   ```bash
   # On the server, edit /etc/coder.d/coder.env
   # Append the new slug to CODER_OAUTH2_GITHUB_ALLOWED_ORGS (comma-separated, no spaces)
   sudo systemctl restart coder
   ```

3. **Test on staging first**: Ask someone from the org to attempt login on staging-coder.ddev.com before updating production.

4. **Update the table above**: Add the org to the sponsor org table so the list stays accurate.

5. **Notify the sponsor**: Send the sponsor notification (see `docs/admin/coder-ddev-com/sponsor-notification.md`) letting them know their org members now have access.

**If the sponsor has no GitHub org**: Add their individual GitHub username to the `coder-ddev-com` org instead (see "Managing individual access" above). No server restart needed.

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

The `drupal-core` template can provision a Drupal core development environment faster on new workspaces using a **seed cache** on the host. Without the cache, first-time workspace setup downloads a full git clone and all composer dependencies (~10-13 minutes). With the cache, the composer install phase is nearly instant; total workspace startup is 3-5 minutes (the remaining time is the Drupal site install, which always runs fresh).

The cache is a standing DDEV project on the host that is periodically refreshed. New workspaces copy the git checkout and vendor directory from it. The database is always installed fresh via `ddev drush si` — this avoids schema-drift reliability problems with pre-built DB snapshots.

### Prerequisites

DDEV must be installed on the Coder server itself (not just inside workspaces). The host DDEV project runs on the host Docker daemon, separate from the Sysbox workspace containers.

Follow the [DDEV Linux installation instructions](https://docs.ddev.com/en/stable/users/install/ddev-installation/#ddev-installation-linux) to install DDEV on the host.

> **User note:** The seed cache must be owned and operated by a normal (non-root) user. DDEV refuses to run as root. All the commands below, and the systemd service, must run as that user — not with `sudo`.

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
```

After this runs, the seed directory contains:

| Path | Contents |
|------|----------|
| `composer.json` / `composer.lock` | Project definition |
| `repos/drupal/` | Git clone of Drupal core |
| `vendor/` | All Composer packages |
| `web/` | Docroot (symlinked) |
| `.ddev/` | Host DDEV config — **not** copied to workspaces |

### Install the hourly update timer

The update script runs `composer update` to keep the cache current with Drupal HEAD. Install it as an hourly systemd timer:

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

# Edit the service to set the correct user (required — YOURUSER is a placeholder):
sudo sed -i "s/User=YOURUSER/User=$(whoami)/" /etc/systemd/system/drupal-cache-updater.service
# If your seed directory differs from ~/cache/drupal-core-seed, also add --seed-dir:
#   sudo vim /etc/systemd/system/drupal-cache-updater.service
# and change ExecStart to: /usr/local/bin/update-drupal-cache --seed-dir /your/cache/path

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

The template uses a `cache_path` variable for the host-side seed directory. The `Makefile` defaults `DRUPAL_CACHE_PATH` to `~/cache/drupal-core-seed` (resolved to the home directory of whoever runs `make`), so `make push-template-drupal-core` works without any override as long as your seed directory is at that path.

If your seed directory is elsewhere, override at deploy time:

```bash
make push-template-drupal-core DRUPAL_CACHE_PATH=/your/cache/path
```

### How new workspaces use the cache

When a workspace starts for the first time:

1. The startup script checks for a valid seed at `/home/coder-cache-seed` (the read-only bind mount of `cache_path`)
2. **Cache hit:** `rsync` copies the project files (excluding `.ddev/`), `ddev composer install` ensures vendor is current (near-instant with vendor already present), then `ddev drush si` installs Drupal fresh (~2-3 min)
3. **Cache miss** (path absent or incomplete): falls back to full `ddev composer create-project` + `ddev drush si` — slower but always works

The database is always installed fresh — there is no pre-built DB snapshot. This avoids schema-drift failures that occurred when the cached DB became stale relative to Drupal HEAD.

Check workspace startup logs in the Coder dashboard or at `/tmp/drupal-setup.log` inside the workspace to confirm which path was taken.

### Troubleshooting

**Cache not being used:**

- Verify the seed directory exists and is populated: `ls $SEED_DIR/composer.json $SEED_DIR/vendor`
- Confirm `cache_path` in the deployed template matches your actual seed directory (check with `coder templates versions list drupal-core`)
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

## Step 12: Set Up Icinga2 Monitoring

New Coder servers should be monitored by `monitor.ddev.com` using icinga2. This connects the server as an icinga2 agent to the central monitoring master.

See also: [DDEV testmachine setup docs](https://docs.ddev.com/en/stable/developers/buildkite-testmachine-setup/) and [maintainer-info monitoring](https://github.com/ddev/maintainer-info/blob/main/topics/monitoring.md) (private repo) for broader context on the monitoring infrastructure.

### Install icinga2 and monitoring plugins

```bash
sudo apt-get install -y icinga2 icinga2-bin icinga2-common icinga2-doc \
  monitoring-plugins monitoring-plugins-basic monitoring-plugins-common \
  monitoring-plugins-contrib monitoring-plugins-standard \
  libmonitoring-plugin-perl nmon
```

### Generate a ticket on monitor.ddev.com

```bash
sudo icinga2 pki ticket --cn <new-server-hostname>
```

Copy the hex ticket string — you'll need it in the next step.

### Run the node wizard on the new server

```bash
sudo icinga2 node wizard
```

Answer the prompts as follows:

| Prompt | Answer |
| ------ | ------ |
| Agent/satellite setup? | `Y` (default) |
| Common name (CN) | `<new-server-hostname>` (e.g. `staging-coder.ddev.com`) |
| Parent endpoint CN | `monitor.ddev.com` |
| Establish connection to parent? | `Y` (default) |
| Parent endpoint host | `monitor.ddev.com` |
| Parent endpoint port | (enter, default 5665) |
| Add more endpoints? | `N` (default) |
| Parent zone name | `master` (default) |
| Request ticket | paste the ticket from above |
| Accept config from parent? | `y` |
| Accept commands from parent? | `y` |

Then restart icinga2:

```bash
sudo systemctl restart icinga2
```

### Configure the host in Icinga Director

In the Icinga Director web UI at [monitor.ddev.com/icingaweb2](https://monitor.ddev.com/icingaweb2):

1. Clone the `coder.ddev.com` host entry
2. Set the name and address to the new server hostname
3. Deploy the configuration

The new host will appear in the monitoring dashboard once the agent connects and the deploy completes.

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

## Step 13: Configure GitHub Actions CI

The repository runs integration tests against `staging-coder.ddev.com` on every push to `main` and nightly. Three workflows are involved: `validate.yml` (static HCL checks, no credentials needed), `staging-push.yml` (pushes templates with `--activate=false`), and `integration-test.yml` / `drupal-integration-test.yml` (create and verify real workspaces on the self-hosted runner).

### One-time setup on staging-coder.ddev.com

#### 1. Register the self-hosted GitHub Actions runner

The integration tests run on a self-hosted runner tagged `sysbox` so they have access to the Sysbox-capable Docker daemon. Register one runner instance per concurrent matrix job (currently 2 for `integration-test.yml` and 3 for `drupal-integration-test.yml`):

```bash
sudo apt-get install -y unzip
sudo useradd -m -s /bin/bash github-runner

for N in 1 2 3 4 5; do
  sudo -u github-runner mkdir -p /home/github-runner/actions-runner-${N}
  # Download runner binaries from GitHub Settings → Actions → Runners → New self-hosted runner
  # Copy binaries to each directory, then:
  sudo -u github-runner /home/github-runner/actions-runner-${N}/config.sh \
    --url https://github.com/ddev/coder-ddev \
    --token <token-from-github> \
    --name staging-coder-${N} \
    --labels sysbox \
    --unattended
  sudo /home/github-runner/actions-runner-${N}/svc.sh install github-runner
  sudo /home/github-runner/actions-runner-${N}/svc.sh start
done
```

Get a fresh registration token for each batch from **GitHub → Settings → Actions → Runners → New self-hosted runner**.

#### 2. Create the CI bot user on staging

```bash
coder users create --email ci@staging-coder.ddev.com --username ci-bot --login-type none
coder users edit-roles ci-bot --roles template-admin --yes
coder tokens create --user ci-bot --lifetime 8760h
```

Store the token in 1Password at `op://test-secrets/TEST_CODER_SESSION_TOKEN/credential`.

### GitHub repository configuration

Go to **GitHub → Settings → Secrets and variables → Actions** and add:

**Secrets:**

| Name                      | Value                                                                          |
|---------------------------|--------------------------------------------------------------------------------|
| `OP_SERVICE_ACCOUNT_TOKEN` | 1Password service account token with read access to the `test-secrets` vault |

**Variables:**

| Name                     | Value                                   |
|--------------------------|-----------------------------------------|
| `TEST_CODER_URL`         | `https://staging-coder.ddev.com`        |
| `DRUPAL_TEST_ISSUE_FORK` | A drupal.org issue number (see below)   |

### Choosing a test issue for `DRUPAL_TEST_ISSUE_FORK`

The `drupal-integration-test.yml` workflow creates a workspace from a real drupal.org issue fork and verifies the site comes up correctly. The issue number is the only thing you need to configure — the branch name and Drupal version are resolved automatically from the drupal.org and GitLab APIs.

Pick an issue that:

- Is **Needs review** status (not Needs work or Closed)
- Targets **main** (12.x) — search at `drupal.org/project/issues/drupal?status=8&version=12.x-dev`
- Has an **issue fork** on `git.drupalcode.org/issue/drupal-{number}`
- Is a modest change (under ~10 files) with no database schema changes

Set the bare issue number (e.g. `3585397`) or the prefixed form (`drupal-3585397`) — both work.

Update this variable whenever the issue is closed or merged. The current default (`3585397`) is a PHP 8.4 compatibility fix targeting Drupal 12.x main.

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
