# Freeform DDEV Template

Coder workspace for one or more DDEV projects in a single workspace. Each project gets its own stable subdomain URL via ddev-router (Traefik) Host-header routing — no port numbers in links, no conflicts between projects.

## Features

- **Multi-Project Support**: Run multiple DDEV projects in one workspace; each gets its own Coder app button and URL
- **Coder-Aware Routing**: DDEV web server and Mailpit get stable subdomain URLs via ddev-router Host-header dispatch
- **VS Code for Web**: Opens directly to your project directory
- **Mailpit**: Email testing UI available as a Coder app
- **Optional Adminer**: Database UI available when enabled via template variable
- **Post-Start Hook**: Traefik routes are refreshed after each `ddev start` to pick up add-on services
- **Persistent Storage**: Home directory and Docker layer cache survive restarts

## How Routing Works

The workspace name is the Coder app slug. After running `ddev coder-setup` and `ddev start`, routing rules are written automatically. URLs follow this pattern:

```
Web:     https://{workspace}--{workspace}--{owner}.{coder-domain}
Mailpit: https://mailpit--{workspace}--{owner}.{coder-domain}
Adminer: https://adminer--{workspace}--{owner}.{coder-domain}  (if enabled)
```

The web URL always uses the workspace name as its subdomain prefix regardless of what the DDEV project is named internally. `ddev coder-routes` reads the running DDEV project from DDEV and writes a Traefik rule that maps the Coder subdomain to the correct container.

## Quick Start

```bash
# Create workspace
coder create --template freeform myworkspace

# SSH in
coder ssh myworkspace

# Clone your project into any directory you choose
git clone git@github.com:your-org/your-project.git <yourdir>
cd <yourdir>

# Configure DDEV
ddev config --project-type=wordpress --docroot=web

# Install the Coder routing hook (once per project)
ddev coder-setup

# Start DDEV — routing activates automatically
ddev start
```

Then click **DDEV Web** or **Mailpit** in the Coder dashboard.

## Project Structure

- `<yourdir>/` — your project directory (any name, any location)
  - `.ddev/config.yaml` — DDEV project configuration
  - `.ddev/config.coder.yaml` — Coder post-start hook (written by `ddev coder-setup`, gitignored)
  - `.ddev/docker-compose.coder-describe.yaml` — Coder URLs for `ddev describe` (written by `ddev coder-routes`, gitignored)
  - your project files
- `~/WELCOME.txt`
- `~/.ddev/global_config.yaml` — DDEV global settings
- `~/.ddev/traefik/custom-global-config/coder-routes-<project>.yaml` — Traefik routing rules (auto-generated per project)

## Coder Setup Command

`ddev coder-setup` is a one-time command run from your project directory after `ddev config`. It:

1. Writes `.ddev/config.coder.yaml` with a post-start hook that runs `ddev coder-routes` after every `ddev start`
2. Adds `.ddev/config.coder.yaml` to `~/.config/git/ignore` so it stays out of your repo

After `ddev coder-setup`, routing updates are fully automatic — no need to run anything manually after adding add-ons or restarting.

## Add-On Services

### Adminer (Database UI)

Enable Adminer when creating or updating the workspace:

```bash
coder create --template freeform myworkspace
# Select: enable_adminer = true
```

Then install the DDEV add-on inside the workspace:

```bash
ddev get ddev/ddev-adminer
ddev restart
```

After `ddev restart`, the post-start hook updates `coder-routes.yaml` to include the Adminer router. Click **Adminer** in the Coder dashboard.

### Other Add-Ons

```bash
ddev get ddev/ddev-redis
ddev get ddev/ddev-memcached
ddev get ddev/ddev-solr
ddev restart
```

After restart, `coder-routes` runs automatically and adds any new service routes.

## Common DDEV Commands

```bash
# Project lifecycle
ddev start               # Start containers (refreshes Traefik routes)
ddev stop                # Stop containers
ddev restart             # Restart containers
ddev describe            # Show URLs and service status

# Database
ddev import-db --file=dump.sql.gz   # Import database
ddev export-db --file=dump.sql.gz   # Export database
ddev mysql                          # Open MySQL CLI

# Running commands
ddev exec php --version  # Run command in web container
ddev ssh                 # SSH into web container
ddev composer install    # Run Composer
ddev npm install         # Run npm

# Logs
ddev logs                # View container logs
ddev logs -f             # Follow logs
```

## Template Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `cpu` | 4 | CPU cores (1–32) |
| `memory` | 8 | Memory in GB (2–128) |
| `enable_adminer` | false | Show Adminer app button (requires `ddev get ddev/ddev-adminer`) |
| `workspace_image_registry` | `index.docker.io/ddev/coder-ddev` | Base image registry |
| `docker_gid` | 988 | Docker group GID on host |

## Requirements

### Coder Server
- Coder v2.13+
- Sysbox runtime enabled on the Docker host
- `VSCODE_PROXY_URI` environment variable set (Coder sets this automatically)

### Resources
- **Minimum**: 2 CPU cores, 4 GB RAM
- **Recommended**: 4 CPU cores, 8 GB RAM, 20 GB disk

## Troubleshooting

### Traefik routes not working

Check that `ddev coder-setup` was run and routes were generated:
```bash
cat ~/.ddev/traefik/custom-global-config/coder-routes.yaml
```

If missing, run from your project directory:
```bash
ddev coder-setup
ddev start
```

### Routes missing after adding an add-on

The post-start hook updates routes automatically after `ddev start`. If routes are missing, verify `ddev coder-setup` was run, then:
```bash
ddev restart
# or manually:
ddev coder-routes
```

### Docker not running
```bash
docker ps
cat /tmp/dockerd.log
```

## Support

- **DDEV Docs**: https://ddev.readthedocs.io/
- **Coder Docs**: https://coder.com/docs
- **Template Issues**: File issues in this repository
