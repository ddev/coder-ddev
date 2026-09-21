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

### Using GitHub Actions (push-image workflow)

The repository has a manually triggered workflow (`.github/workflows/push-image.yml`) that builds and pushes the image to Docker Hub from GitHub's infrastructure. This is the preferred approach for official releases.

**Prerequisites — configure once in GitHub repository settings:**

- **Secret** `PUSH_SERVICE_ACCOUNT_TOKEN` — 1Password service account token (from the `push-secrets` vault)
- **Variable** `DOCKERHUB_USERNAME` — Docker Hub username (e.g. `ddev`)

The workflow reads `DOCKERHUB_TOKEN` from 1Password at `op://push-secrets/DOCKERHUB_TOKEN/credential` using the service account token.

**To trigger a push:**

1. Update `VERSION` and commit/merge to the branch you want to build from.
2. Go to **Actions → Push Image → Run workflow** in the GitHub UI, select the branch, and click **Run workflow**.
3. The workflow builds `linux/amd64`, tags the image as both `ddev/coder-ddev:<version>` and `ddev/coder-ddev:latest`, and pushes to Docker Hub.

Alternatively, trigger via the CLI:

```bash
gh workflow run push-image.yml --ref <branch>
```

## Deploying the Template

### Using the Makefile

```bash
# Push all templates (no image build — use when only HCL changed)
make push-all-templates

# Push a single template
make push-template-drupal-core
make push-template-drupal-contrib
make push-template-freeform

# Full deployment: build image, push image, push all templates
make deploy-all

# Full deployment without cache (clean image build)
make build-and-push-no-cache && make push-all-templates
```

### Auto-stop TTL

Set a default auto-stop so idle workspaces shut down and free resources. Run once after initial deployment (or after adding a new template):

```bash
coder templates edit drupal-core      --default-ttl 2h --yes
coder templates edit drupal-contrib   --default-ttl 2h --yes
coder templates edit freeform         --default-ttl 2h --yes
```

Users can override the TTL on their individual workspaces if needed.

### Template Configuration

The template is defined in `freeform/template.tf`. Key configuration parameters:

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
3. Push template: `coder templates push --directory freeform freeform --yes`

## Version Management

### Version Files

The `VERSION` file in the root directory controls the image tag. The Makefile automatically copies it into the template directory before pushing, and `template.tf` reads it from there — no manual edits to `template.tf` are needed.

### Releasing a New Version

```bash
# 1. Update VERSION file
echo "v0.7" > VERSION

# 2. Build image, push image, and push template (VERSION is synced automatically)
make build-and-push && make push-template-freeform

# Or without cache for clean build
make build-and-push-no-cache && make push-template-freeform
```

## Managing Workspaces

### Creating Workspaces

**Via Web UI:**
1. Log into Coder dashboard
2. Click "Create Workspace"
3. Select "freeform" template
4. Enter workspace name
5. Configure parameters (optional: CPU, memory)
6. Click "Create Workspace"

**Via CLI:**
```bash
# Create with defaults
coder create --template freeform my-workspace --yes

# Create with custom parameters
coder create --template freeform my-workspace \
  --parameter cpu=8 \
  --parameter memory=16 \
  --yes
```

### Listing Workspaces

```bash
# List all workspaces
coder list

# List workspaces for specific template
coder list --template freeform

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
for ws in workspace1 workspace2 workspace3; do coder delete "$ws" --yes; done
```

**Deleting a workspace removes:**

- Workspace container
- `/var/lib/docker` Docker named volume (Docker daemon data for that workspace)
- Host directory at `/coder-workspaces/<owner>-<workspace>` — via destroy-time provisioner in the template

If the provisioner doesn't run (e.g. Terraform error, or directories orphaned before this feature was added), use `scripts/cleanup-deleted-workspaces.sh`. See [Orphaned Workspace Cleanup](#orphaned-workspace-cleanup) below.

## Template Updates

### Updating Template Configuration

```bash
# 1. Edit template.tf
vim freeform/template.tf

# 2. Push updated template
make push-template-freeform
```

### Updating Docker Image

```bash
# 1. Edit image/Dockerfile (if needed)
# 2. Increment version (template reads this automatically)
echo "v0.7" > VERSION

# 3. Build and push the image, then push the templates that use it
make build-and-push
make push-all-templates

# Users must rebuild workspaces to get new Docker image
```

### Testing a Template Change Before Activating

Push a new version without making it the default, test it on a single workspace, then promote it when satisfied. This lets you validate changes without affecting other users.

```bash
# 1. Push without activating
make push-template-drupal-core ACTIVATE=false

# 2. Find the new version name (top row, status "Unused")
coder templates versions list drupal-core

# 3. Create a test workspace pinned to that version
coder create --template drupal-core --template-version <version-name> test-workspace --yes

# 4. Verify — e.g. for drupal-core, check setup completed correctly
coder ssh test-workspace -- grep -E "Drush|Drupal install" ~/drupal-core/drupal-setup.log

# 5. Promote to active once satisfied
coder templates versions promote drupal-core <version-name>

# 6. Clean up test workspace
coder delete test-workspace --yes
```

If you push again with `ACTIVATE=true` (the default) rather than using `promote`, that also activates the version — the `promote` step is only needed when you pushed with `ACTIVATE=false` and want to activate without re-pushing.

### Rolling Back

```bash
# Revert to previous template version
git checkout <previous-commit> freeform/template.tf
coder templates push --directory freeform freeform --yes

# Users on old version are unaffected
# Users can update to rollback version via: coder update <workspace>
```

## Backup and Maintenance

### Workspace Data Backup

Each workspace stores persistent data in:
- **Home directory**: `/coder-workspaces/<owner>-<workspace>` on host
- **Docker volume**: Named volume `coder-<owner>-<workspace>-dind-cache`

**Backup strategy:**

```bash
# Backup home directory
tar -czf workspace-backup.tar.gz /coder-workspaces/<owner>-<workspace>

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

### Disk Space Cleanup

When disk space is running low, reclaim it in this order:

#### 1. List all workspaces (including other users')

```bash
coder list -a
```

#### 2. Delete unused workspaces

Stopped or dormant workspaces that are no longer needed can be deleted. This removes the workspace container, Docker volume, and host directory:

```bash
# Delete a single workspace
coder delete <owner>/<workspace-name> --yes

# Delete multiple workspaces
for ws in <owner>/<workspace1> <owner>/<workspace2>; do coder delete "$ws" --yes; done

# Delete all workspaces (use with caution)
for ws in $(coder list -a -c workspace | grep -v WORKSPACE); do coder delete "$ws" --yes; done
```

Check the Coder dashboard for "Last used" times to identify dormant workspaces before deleting.

#### 3. Prune the Docker BuildKit cache

BuildKit caches can accumulate across workspace image builds:

```bash
docker buildx prune -f
```

#### 4. Check remaining disk usage

```bash
df -h /data /coder-workspaces
docker system df
```

---

### Automated Idle Workspace Cleanup

A systemd timer runs `scripts/workspace-lifecycle-cleanup.sh` daily, directly on coder.ddev.com (production only — see [Server Setup Guide: Step 14](./server-setup.md#step-14-set-up-workspace-lifecycle-cleanup) for why staging doesn't need it), to keep idle workspaces from accumulating and slowly filling `/data` with `*-dind-cache` Docker volumes (each workspace keeps its full Docker-in-Docker cache volume until it's deleted, even while stopped).

Policy per workspace, based on `last_used_at`:

- **7 days idle** — owner gets a notice email (via Mailgun) explaining the workspace will be deleted, and pointing to the auth/access announcement if they can no longer log in.
- **7 more days idle after the notice** — the workspace is deleted with `coder delete --yes`.
- If the owner uses the workspace again before deletion, the pending notice is cleared automatically.

Both the notice and the eventual deletion are visible in Discord if [coder-discord-relay](./server-setup.md#step-11-set-up-discord-notifications) is set up: the notice email triggers a direct **Workspace Deletion Threatened** post to the relay (`DISCORD_RELAY_URL`, best-effort — a missing or unreachable relay never blocks the email), and the later `coder delete` call is picked up natively as Coder's own **Workspace Deleted** event, same as any other deletion.

State (which workspaces have been notified and when) is tracked in a local JSON file on the server (`/var/lib/workspace-lifecycle-cleanup/state.json` by default) — it never needs to leave the box, so there's no commit-back-to-git step to manage.

```bash
# Dry run — shows what would be notified/deleted, sends no email, deletes nothing
./scripts/workspace-lifecycle-cleanup.sh

# Actually send notices, delete workspaces past their grace period, and persist state
./scripts/workspace-lifecycle-cleanup.sh --force
```

#### One-off purge (owners already notified out of band)

`--purge-idle-days=N` bypasses the notify/grace state machine entirely and deletes every workspace idle at least `N` days (owners in `EXCLUDE_OWNERS` are still skipped). It sends no email, needs no Mailgun credentials, and neither reads nor writes the state file — the next normal timer run prunes any state entries for workspaces purged this way. Use it when owners have already been warned by other means (e.g. a manual email blast) and you need disk back now:

```bash
# Preview what a 14-day purge would delete — deletes nothing
./scripts/workspace-lifecycle-cleanup.sh --purge-idle-days=14

# Actually delete every workspace idle >= 14 days
./scripts/workspace-lifecycle-cleanup.sh --purge-idle-days=14 --force
```

Like the normal flow, purge requires the `coder` CLI authenticated with the `owner` role (see below). Always run the preview first and eyeball the list — purge has no grace period and no second chance.

**Prerequisites:** `coder` CLI on `PATH` and authenticated (either via `coder login` or the `CODER_URL`/`CODER_SESSION_TOKEN` env vars) as a user with the `owner` role (see below); `MAILGUN_API_KEY` and `MAILGUN_DOMAIN` set for `--force` runs — DDEV's existing Mailgun account credentials are in the shared **DDEV** 1Password vault, item **Mailgun** (same account/domain used to send other DDEV mail; no new domain or DNS verification needed). See the script header for all environment overrides (`NOTIFY_DAYS`, `DELETE_AFTER_DAYS`, `EXCLUDE_OWNERS`, `STATE_FILE`, etc.).

On the server, all of this is supplied via `/etc/workspace-lifecycle-cleanup.env`, loaded by the `workspace-lifecycle-cleanup.service` systemd unit — see the install steps linked above. Check `sudo systemctl status workspace-lifecycle-cleanup.timer` and `sudo journalctl -u workspace-lifecycle-cleanup -q -f` to inspect runs.

#### Provisioning the `CODER_SESSION_TOKEN` credential

The script needs to list *every* user's workspaces (`coder list --all`) and delete workspaces it doesn't own. On this deployment (no Premium license, so no custom RBAC roles), `owner` is the only built-in role that can do both — there's no narrower "workspace admin" role available. That makes this token effectively full site-admin, so it's provisioned as a dedicated non-human account rather than a personal token:

```bash
# 0. Raise the server's max *admin* token lifetime first — Coder caps --lifetime
#    for owner-role accounts at CODER_MAX_ADMIN_TOKEN_LIFETIME (default 168h/1
#    week; the much larger CODER_MAX_TOKEN_LIFETIME default doesn't apply to
#    owner accounts), which is too short for an unattended daily timer. Add to
#    /etc/coder.d/coder.env, then `sudo systemctl restart coder`:
#      CODER_MAX_ADMIN_TOKEN_LIFETIME=8760h

# 1. Create a machine identity — no GitHub OAuth login required
coder users create --username workspace-janitor \
  --email workspace-janitor@ddev.com \
  --full-name "Workspace Lifecycle Janitor" \
  --login-type none

# 2. Grant it owner — the only built-in role that covers list-all + delete-any-workspace
coder users edit-roles workspace-janitor --roles owner --yes

# 3. Mint a long-lived token for it (run as an existing owner/admin, e.g. your own account)
coder tokens create -u workspace-janitor --name workspace-lifecycle-cleanup --lifetime 8760h
```

Put the resulting token in `/etc/workspace-lifecycle-cleanup.env` as `CODER_SESSION_TOKEN` (see the install steps). Using a dedicated account rather than a personal token keeps deletions attributable to the bot (not an individual) in the audit log, and means the janitor doesn't break if the admin's own account is later deactivated or re-authenticated.

If you can't raise `CODER_MAX_TOKEN_LIFETIME` on a given deployment, use the max allowed instead and set a reminder to rotate the token before it expires — an expired token makes the timer fail silently until someone notices (`journalctl -u workspace-lifecycle-cleanup` will show the auth error).

`--login-type none` is deprecated in favor of `--service-account` (Premium-only) but remains functional for this purpose.

---

### Orphaned Workspace Cleanup

When a workspace is deleted, the destroy provisioner automatically removes the host directory at `/coder-workspaces/<owner>-<workspace>`. Directories can still be orphaned if the provisioner fails or for workspaces deleted before the provisioner was added. Run the cleanup script to reclaim disk space in those cases.

```bash
# Dry run — shows what would be deleted without removing anything
./scripts/cleanup-deleted-workspaces.sh

# Actually delete orphaned directories and Docker volumes
./scripts/cleanup-deleted-workspaces.sh --force
```

Run as your normal user (not root) — the script calls `sudo /usr/local/bin/coder-delete-workspace-dir` internally for directory removal, and uses `docker volume rm` (requires docker group membership).

The script:

- Queries `coder list --all` to get the current list of active workspaces
- Compares against directories in `/coder-workspaces/` and Docker volumes named `coder-*-dind-cache`
- Reports sizes before deleting
- Refuses to delete anything if the Coder CLI returns no workspaces (guards against misconfigured auth)

**Prerequisites:** `coder` CLI authenticated as an admin; user in the `docker` group; `sudo` access for directory removal.

### Template Versioning

Store template versions in git:

```bash
# Tag releases
git tag -a v0.1 -m "Release v0.1"
git push origin v0.1

# Track changes
git log --oneline freeform/template.tf
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
df -h /coder-workspaces/
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

- Use clear, descriptive names: `drupal-core`, `ddev-developer`
- Version templates for major changes: `drupal-core-v2`
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
