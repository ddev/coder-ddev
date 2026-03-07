# Drupal Core Development Template

Automated Coder workspace for Drupal core development using [joachim-n/drupal-core-development-project](https://github.com/joachim-n/drupal-core-development-project). Sets up a professional development environment with Drupal core, DDEV, and a demo site.

**New? See the [quickstart guide](../docs/user/quickstart.md).**

[![Open in Coder](https://coder.ddev.com/open-in-coder.svg)](https://coder.ddev.com/templates/coder/drupal-core/workspace?mode=manual)

## Features

- **Professional Setup**: Uses the drupal-core-development-project template
- **Clean Git Clone**: Drupal core in `repos/drupal/` directory
- **Proper Structure**: Web root at `web/` with Composer management
- **Demo Site**: Umami demo profile pre-installed (configurable)
- **Full DDEV**: Complete DDEV environment with automatic PHP version selection
- **Issue Fork Support**: Check out any Drupal.org issue branch, with automatic Composer dependency resolution
- **VS Code**: Opens directly to Drupal core project root
- **Port Forwarding**: HTTP (80)
- **Custom Launch Command**: `ddev launch` shows Coder-specific instructions

## Initial Setup Time

When a seed cache is available on the server (the default), first workspace creation takes approximately **15-30 seconds**:
- rsync from seed cache: ~3s
- git fetch: ~1s
- composer install: ~2s
- Database import: ~9s
- DDEV start: ~15s

Without a seed cache, first setup takes 10-15 minutes (full composer create + Drupal install).

Subsequent starts are fast (< 1 minute) as everything is already present.

## Quick Start

**Standard Drupal core workspace:**
```bash
coder create --template drupal-core my-drupal-dev
# Then access via Coder dashboard "DDEV Web" app
```

**Working on a specific issue:**

Use the **[Drupal Issue Picker](https://start.coder.ddev.com/drupal-issue)** — enter an issue URL or number and it opens a pre-configured workspace with the issue branch already checked out and composer dependencies resolved.

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
├── drupal-core/              # Project root (VS Code opens here)
│   ├── repos/
│   │   └── drupal/          # Drupal core git clone (clean)
│   ├── web/                 # Web docroot
│   │   ├── core/            # Symlinked from repos/drupal/core
│   │   ├── index.php        # Patched for correct app root
│   │   └── ...
│   ├── .ddev/               # DDEV configuration
│   ├── vendor/              # Composer dependencies
│   ├── composer.json        # Project dependencies
│   └── ...
├── WELCOME.txt              # Welcome message
├── SETUP_STATUS.txt         # Setup completion status
└── projects/                # Additional projects directory (pre-created)
```

## Common Commands

```bash
# Drupal administration
ddev drush status           # Check Drupal status
ddev drush uli              # Get one-time admin login link
ddev drush cr               # Clear cache
ddev drush updb             # Run database updates

# Development
ddev composer require ...   # Add dependencies
ddev composer update        # Update dependencies
ddev exec phpunit ...       # Run tests

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
- GitHub: https://github.com (for drupal-core-development-project)
- Git: https://git.drupalcode.org (for Drupal core clone)
- Docker Hub: https://hub.docker.com

## Troubleshooting

### Setup Failed
Check the status and logs:
```bash
cat ~/SETUP_STATUS.txt
tail -50 /tmp/drupal-setup.log
```

Common issues:
- **DDEV config failed**: Check DDEV installation and Docker daemon
- **DDEV start failed**: Docker daemon issue, check `docker ps`
- **DDEV composer create failed**: Network connectivity or memory issue
- **Drupal install failed**: Database connection, check DDEV logs

### Manual Recovery
If automatic setup fails, you can complete steps manually:
```bash
cd ~
mkdir -p drupal-core && cd drupal-core
ddev config --project-type=drupal12 --docroot=web --php-version=8.5
ddev start
ddev composer create joachim-n/drupal-core-development-project
ddev composer require drush/drush
ddev drush si -y demo_umami --account-pass=admin
```

## Customization

### Change Drupal Profile
Set the `install_profile` parameter when creating the workspace:
```bash
coder create --template drupal-core my-workspace --parameter install_profile=standard
```
Options: `demo_umami` (default), `minimal`, `standard`.

Note: issue fork workspaces always run a full site install regardless of profile; `demo_umami` only uses the cached DB snapshot for standard workspaces.

### Add Custom Commands
Create scripts in `~/.ddev/commands/host/` or `.ddev/commands/web/`

## Architecture

- **Base Image**: `ddev/coder-ddev` (Ubuntu 24.04, DDEV, Docker, Node.js)
- **Runtime**: Sysbox (secure Docker-in-Docker)
- **Project Template**: [joachim-n/drupal-core-development-project](https://github.com/joachim-n/drupal-core-development-project)
- **Volumes**:
  - `/home/coder` - Persistent workspace data
  - `/var/lib/docker` - Docker images and containers
- **Drupal**: Main branch from https://git.drupalcode.org/project/drupal (cloned via template)

## Development Workflow

1. Make changes in VS Code (automatically opens to `/home/coder/drupal-core`)
2. Edit Drupal core files in `repos/drupal/` directory
3. Test changes via DDEV Web app (web root is at `web/`)
4. Run tests: `ddev exec phpunit ...`
5. Commit changes in `repos/drupal/`: `cd repos/drupal && git add . && git commit -m "..."`
6. Push to fork: `git remote add fork <url> && git push fork`

**Note**: The `repos/drupal/` directory contains the clean Drupal core git repository. Changes here are reflected in the `web/` directory via symlinks.

## Support

- **DDEV Docs**: https://docs.ddev.com/
- **Drupal Docs**: https://www.drupal.org/docs
- **Coder Docs**: https://coder.com/docs
- **Template Issues**: File issues in this repository
