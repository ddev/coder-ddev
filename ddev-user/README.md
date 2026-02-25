# DDEV User Template

General-purpose DDEV workspace for developing any project type supported by DDEV (PHP, WordPress, Laravel, Drupal, Magento, and more). Provides a full Docker environment via Sysbox with VS Code for Web and DDEV pre-configured.

## Features

- **Any Project Type**: PHP, WordPress, Laravel, Drupal, Magento, Symfony, and 20+ others
- **Full Docker**: Isolated Docker daemon via Sysbox — no privileged mode required
- **VS Code for Web**: Browser-based IDE opens to your home directory
- **DDEV Pre-installed**: Ready to configure and start DDEV projects
- **Persistent Storage**: Home directory and Docker layer cache survive workspace restarts
- **Port Forwarding**: DDEV web server (port 80) accessible via Coder dashboard

## Quick Start

```bash
# Create workspace
coder create --template ddev-user my-workspace

# SSH in
coder ssh my-workspace

# Create a new project
mkdir ~/projects/mysite && cd ~/projects/mysite

# Configure DDEV for your project type
ddev config --project-type=php --docroot=web
# Or: ddev config --project-type=wordpress --docroot=web
# Or: ddev config --project-type=laravel --docroot=public
# Or: ddev config --project-type=drupal --docroot=web

# Start DDEV
ddev start
```

Then click **DDEV Web** in the Coder dashboard to open your site.

## Project Types

DDEV supports many project types. Pass `--project-type=<type>` to `ddev config`:

| Type | Docroot | Notes |
|------|---------|-------|
| `php` | varies | Generic PHP projects |
| `wordpress` | web | WordPress installations |
| `laravel` | public | Laravel framework |
| `drupal` | web | Drupal 7, 8, 9, 10, 11 |
| `magento2` | pub | Magento 2 |
| `symfony` | public | Symfony framework |
| `craftcms` | web | Craft CMS |
| `typo3` | public | TYPO3 CMS |

See [DDEV project types](https://ddev.readthedocs.io/en/stable/users/quickstart/) for the full list.

## Cloning an Existing Project

```bash
# Clone your project
cd ~/projects
git clone git@github.com:your-org/your-project.git mysite
cd mysite

# Configure DDEV (or use an existing .ddev/config.yaml)
ddev config --project-type=wordpress --docroot=web
ddev start

# Import a database (if you have one)
ddev import-db --file=dump.sql.gz
```

## Common DDEV Commands

```bash
# Project lifecycle
ddev start               # Start DDEV containers
ddev stop                # Stop containers
ddev restart             # Restart containers
ddev describe            # Show project URLs and status

# Database
ddev import-db --file=dump.sql.gz   # Import database
ddev export-db --file=dump.sql.gz   # Export database
ddev mysql                          # Open MySQL CLI

# Running commands
ddev exec php --version  # Run command in web container
ddev ssh                 # SSH into web container
ddev composer install    # Run Composer
ddev npm install         # Run npm

# Logs and debugging
ddev logs                # View container logs
ddev logs -f             # Follow logs
```

## Project Structure

```
/home/coder/
├── projects/            # Suggested location for DDEV projects
│   └── mysite/          # Your project directory
│       ├── .ddev/       # DDEV configuration
│       └── web/         # Project files (docroot varies by type)
├── WELCOME.txt          # Welcome message
└── .ddev/               # DDEV global configuration
```

## Requirements

### Coder Server
- Coder v2.13+
- Sysbox runtime enabled on the Docker host

### Resources
- **Minimum**: 2 CPU cores, 4 GB RAM
- **Recommended**: 4 CPU cores, 8 GB RAM, 20 GB disk per project

## Troubleshooting

### Docker not running
```bash
# Check Docker daemon
docker ps
# If not running, check logs
cat /tmp/dockerd.log
```

### DDEV won't start
```bash
ddev describe          # Check current state
ddev logs              # View error output
docker ps              # Verify containers exist
```

### Port conflicts
```bash
ddev describe          # Shows actual ports in use
# DDEV auto-selects alternative ports if 80/443 are taken
```

### Workspace won't start
- Verify the Coder server has Sysbox installed: `sysbox-runc --version`
- Check resource allocation meets minimums

## Customization

### Change PHP version
```bash
ddev config --php-version=8.3
ddev restart
```

### Add DDEV services
```bash
# Add Redis
ddev get ddev/ddev-redis
ddev restart

# Add Memcached
ddev get ddev/ddev-memcached
ddev restart
```

### Change database type
```bash
ddev config --database=mariadb:11.4
ddev restart
```

## Support

- **DDEV Docs**: https://ddev.readthedocs.io/
- **Coder Docs**: https://coder.com/docs
- **Template Issues**: File issues in this repository
