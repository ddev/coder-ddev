# Drupal Core Development Template

Automated Coder workspace for Drupal core development using the [amateescu/ddev-drupal-dev](https://github.com/amateescu/ddev-drupal-dev) DDEV add-on. Sets up a professional development environment with Drupal core, DDEV, and a demo site.

**New? See the [quickstart guide](../docs/user/quickstart.md).**

[![Open in Coder](https://coder.ddev.com/open-in-coder.svg)](https://coder.ddev.com/templates/coder/drupal-core/workspace?mode=manual)

## Features

- **Direct Git Clone**: Drupal core cloned as the project root — no composer project wrapper
- **Add-on Overlay**: [`amateescu/ddev-drupal-dev`](https://github.com/amateescu/ddev-drupal-dev) provides `ddev add-module`, `ddev phpunit`, and a `composer.local.json` overlay so core's `composer.json` stays untouched
- **Demo Site**: Umami demo profile pre-installed (configurable)
- **Full DDEV**: Complete DDEV environment with automatic PHP version selection
- **Issue Fork Support**: Check out any Drupal.org issue branch via git remote
- **VS Code**: Opens directly to the Drupal core project root
- **Port Forwarding**: HTTP (80)
- **Custom Launch Command**: `ddev launch` shows Coder-specific instructions


## Quick Start

**Standard Drupal core workspace:**
```bash
coder create --template drupal-core my-drupal-dev
# Then access via Coder dashboard "DDEV Web" app
```

**Working on a specific issue:**

Use the **[Drupal Issue Picker](https://start.coder.ddev.com/drupal-issue)** — enter an issue URL or number and it opens a pre-configured workspace with the issue branch already checked out.

Or manually via CLI:
```bash
coder create --template drupal-core my-issue-3568144 \
  --parameter issue_fork=3568144 \
  --parameter issue_branch=3568144-editorfilterxss-11.x \
  --parameter drupal_version=11
```

## Access

- **Website**: Click "DDEV Web" in Coder dashboard
- **Admin Login**: Username `admin`, Password `admin`
- **One-time Login**: Run `ddev drush uli` in terminal

## Project Structure

```
/home/coder/
├── drupal-core/              # Drupal core git clone (VS Code opens here)
│   ├── core/                 # Drupal core source
│   ├── index.php             # Entry point (at project root, not web/)
│   ├── .ddev/               # DDEV configuration
│   └── composer.local.json  # Local dependencies (drush, dev modules)
├── WELCOME.txt              # Welcome message
├── SETUP_STATUS.txt         # Setup completion status
└── projects/                # Additional projects directory
```

## Common Commands

```bash
# Drupal administration
ddev drush status           # Check Drupal status
ddev drush uli              # Get one-time admin login link
ddev drush cr               # Clear cache
ddev drush updb             # Run database updates

# Development (provided by ddev-drupal-dev add-on)
ddev add-module token       # Install a contrib module for development
ddev phpunit core/modules/node  # Run Drupal tests

# DDEV management
ddev launch                 # Show access instructions
ddev logs                   # View container logs
ddev ssh                    # SSH into web container
ddev describe               # Show project details
ddev restart                # Restart containers

# Debugging
ddev logs -f                # Follow logs
cat ~/SETUP_STATUS.txt      # Check setup status
tail -f /tmp/drupal-setup.log  # View setup logs
```

## Requirements

### Coder Server
- Coder v2.13+
- Sysbox runtime enabled

### Network Access
- Packagist: https://packagist.org (for Composer)
- Git: https://git.drupalcode.org (for Drupal core clone and issue forks)
- GitHub: https://github.com (for ddev-drupal-dev add-on)
- Docker Hub: https://hub.docker.com

## Troubleshooting

### Setup Failed
Check the status and logs:
```bash
cat ~/SETUP_STATUS.txt
tail -50 /tmp/drupal-setup.log
```

Common issues:

- **git clone failed**: Network connectivity to git.drupalcode.org
- **DDEV start failed**: Docker daemon issue, check `docker ps`
- **composer install failed**: Network connectivity or memory issue
- **Drupal install failed**: Database connection, check DDEV logs

### Manual Recovery
If automatic setup fails, you can complete steps manually:
```bash
cd ~/drupal-core
ddev config --project-type=drupal12
ddev start
ddev add-on get amateescu/ddev-drupal-dev
ddev restart
ddev composer install
ddev composer require drush/drush
ddev drush si -y demo_umami --account-pass=admin
```

## Customization

### Choose Drupal Version
Set the `drupal_version` parameter to target a specific major version:
```bash
# Default: 12.x (main branch, latest development)
coder create --template drupal-core my-workspace

# Stable 11.x branch
coder create --template drupal-core my-11x-workspace --parameter drupal_version=11

# Stable 10.x branch
coder create --template drupal-core my-10x-workspace --parameter drupal_version=10
```
The version controls the DDEV project type (PHP version) and the git branch checked out.

### Change Drupal Profile
Set the `install_profile` parameter when creating the workspace:
```bash
coder create --template drupal-core my-workspace --parameter install_profile=standard
```
Options: `demo_umami` (default), `minimal`, `standard`.

### Add Custom Commands
Create scripts in `~/.ddev/commands/host/` or `.ddev/commands/web/`

## Architecture

- **Base Image**: `ddev/coder-ddev` (Ubuntu 24.04, DDEV, Docker, Node.js)
- **Runtime**: Sysbox (secure Docker-in-Docker)
- **Add-on**: [amateescu/ddev-drupal-dev](https://github.com/amateescu/ddev-drupal-dev)
- **Volumes**:
  - `/home/coder` - Persistent workspace data
  - `/var/lib/docker` - Docker images and containers
- **Drupal**: Cloned from https://git.drupalcode.org/project/drupal — defaults to `main` (12.x); select 11.x or 10.x via the `drupal_version` parameter

## Development Workflow

1. Make changes in VS Code (automatically opens to `/home/coder/drupal-core`)
2. Edit Drupal core files directly in `~/drupal-core/`
3. Test changes via DDEV Web app
4. Run tests: `ddev phpunit core/modules/...`
5. Commit: `cd ~/drupal-core && git add . && git commit -m "..."`
6. Push to fork: `git push issue HEAD`

## Support

- **Add-on docs**: [amateescu/ddev-drupal-dev](https://github.com/amateescu/ddev-drupal-dev)
- **DDEV Docs**: [docs.ddev.com](https://docs.ddev.com/)
- **Drupal Docs**: [drupal.org/docs](https://www.drupal.org/docs)
- **Coder Docs**: [coder.com/docs](https://coder.com/docs)
- **Template Issues**: File issues in this repository
