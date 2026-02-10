# DDEV Drupal Core Development Template

Automated Coder workspace for Drupal core development. Clones Drupal core, configures DDEV, and installs a demo site automatically.

## Features

- **Automatic Setup**: Drupal core cloned and configured on first start
- **Demo Site**: Umami demo profile pre-installed
- **Full DDEV**: Complete DDEV environment with PHP 8.5, Drupal 12 config
- **VS Code**: Opens directly to Drupal core directory
- **Port Forwarding**: HTTP (80), HTTPS (443), Mailpit (8025)
- **Custom Launch Command**: `ddev launch` shows Coder-specific instructions

## Initial Setup Time

First workspace creation takes approximately 10-15 minutes:
- Git clone: 2-3 minutes (Drupal core repository main branch)
- Composer install: 5-7 minutes (dependencies)
- Drupal installation: 2-3 minutes (demo_umami profile)

Subsequent starts are fast (< 1 minute) as everything is cached.

## Quick Start

```bash
# Create workspace
coder create --template ddev-drupal-core my-drupal-dev

# Wait for setup to complete (monitor in Coder UI logs)
# Then access via Coder dashboard "DDEV Web" app
```

## Access

- **Website**: Click "DDEV Web" in Coder dashboard
- **Admin Login**: Username `admin`, Password `admin`
- **One-time Login**: Run `ddev drush uli` in terminal

## Project Structure

```
/home/coder/
├── drupal-core/          # Drupal core repository (VS Code opens here)
│   ├── .ddev/            # DDEV configuration
│   ├── core/             # Drupal core
│   ├── vendor/           # Composer dependencies
│   ├── composer.json     # Drupal dependencies
│   └── ...
├── WELCOME.txt           # Welcome message
├── SETUP_STATUS.txt      # Setup completion status
└── projects/             # Additional projects (if needed)
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

### Resources
- **Minimum**: 6 CPU cores, 12 GB RAM, 50 GB disk
- **Recommended**: 8 CPU cores, 16 GB RAM, 100 GB disk

### Network Access
- Git: https://git.drupalcode.org
- Composer: https://packagist.org
- Docker Hub: https://hub.docker.com

## Troubleshooting

### Setup Failed
Check the status and logs:
```bash
cat ~/SETUP_STATUS.txt
tail -50 /tmp/drupal-setup.log
```

Common issues:
- **Git clone failed**: Network connectivity, try manual clone
- **Composer install failed**: Insufficient memory (need 12GB+)
- **DDEV start failed**: Docker daemon issue, check `docker ps`
- **Drupal install failed**: Database connection, check DDEV logs

### Manual Recovery
If automatic setup fails, you can complete steps manually:
```bash
cd ~/drupal-core
ddev start
ddev composer install
ddev composer require drush/drush
ddev drush si -y demo_umami --account-pass=admin
```

### Workspace Won't Start
- Check Coder server has Sysbox runtime enabled
- Verify resource allocation (6+ cores, 12+ GB RAM)
- Check Docker daemon is running: `docker ps`

### Port Conflicts
If port 80 is unavailable, DDEV will use alternative ports. Check with:
```bash
ddev describe
```

## Customization

### Change Drupal Profile
Edit the startup script in `template.tf` and change:
```bash
ddev drush si -y demo_umami --account-pass=admin
```
To use `minimal`, `standard`, or other profiles.

### Change PHP Version
Edit DDEV config command in `template.tf`:
```bash
ddev config --project-type=drupal12 --php-version=8.4
```

### Add Custom Commands
Create scripts in `~/.ddev/commands/host/` or `.ddev/commands/web/`

## Architecture

- **Base Image**: `randyfay/coder-ddev:v0.4` (Ubuntu 24.04, DDEV, Docker, Node.js)
- **Runtime**: Sysbox (secure Docker-in-Docker)
- **Volumes**:
  - `/home/coder` - Persistent workspace data
  - `/var/lib/docker` - Docker images and containers
- **Drupal**: Latest main branch from https://git.drupalcode.org/project/drupal

## Development Workflow

1. Make changes in VS Code (automatically opens to `/home/coder/drupal-core`)
2. Test changes via DDEV Web app
3. Run tests: `ddev exec phpunit ...`
4. Commit changes: `git add . && git commit -m "..."`
5. Push to fork: `git remote add fork <url> && git push fork`

## Support

- **DDEV Docs**: https://docs.ddev.com/
- **Drupal Docs**: https://www.drupal.org/docs
- **Coder Docs**: https://coder.com/docs
- **Template Issues**: File issues in this repository
