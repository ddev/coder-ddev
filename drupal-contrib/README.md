# Drupal Contrib Development Template

A Coder workspace template for developing Drupal contrib modules and themes, with full support for working on specific issue branches from drupal.org.

## Features

- **Full DDEV environment** — DDEV with the official [`ddev-drupal-contrib`](https://github.com/ddev/ddev-drupal-contrib) addon
- **Any contrib project** — Clone any module or theme from git.drupalcode.org by machine name
- **Issue branch support** — Automatically fetch and checkout issue forks from drupal.org
- **Symlinked module** — Module/theme is symlinked into the Drupal web root automatically (`ddev symlink-project`)
- **Dev tools included** — PHPUnit, PHPStan, PHPCS, ESLint, Stylelint via DDEV commands
- **Multiple Drupal versions** — Supports Drupal 10.x, 11.x, and 12.x as the dev dependency
- **VS Code for Web** — Opens at your module root; PHP Debug, Intelephense, and more

## Quick Start

### Via the Issue Picker (recommended)

Visit the Drupal Issue Picker at your Coder instance. Paste any drupal.org project or issue URL — the picker detects contrib projects automatically and routes to this template.

### Via CLI

```bash
# Plain development on a contrib module (HEAD)
coder create --template drupal-contrib my-workspace \
  --parameter project_name=token \
  --parameter drupal_version=11 \
  --yes

# Working on a specific issue
coder create --template drupal-contrib issue-3568144 \
  --parameter project_name=views \
  --parameter issue_fork=3568144 \
  --parameter issue_branch=3568144-fix-something-2.x \
  --parameter drupal_version=11 \
  --yes
```

## Setup Time

| Scenario | Time |
|----------|------|
| First workspace creation | 5–10 min (downloads Drupal + dependencies) |
| Subsequent starts | ~1 min (restarts existing containers) |

## Workspace Structure

```
/home/coder/{project_name}/          # Module/theme git repo
├── {source files}
├── composer.json                    # Module's own composer.json (unchanged)
├── composer.contrib.json            # Temp file by ddev poser (gitignored)
├── .ddev/                           # DDEV configuration
├── vendor/                          # Installed dependencies
└── web/                             # Drupal docroot
    └── modules/custom/{name}  ->  /home/coder/{name}  (symlink)
                                     # (or themes/custom/{name} for themes)
```

The module/theme repo is the project root. Drupal core is installed as a dev dependency in `web/`. A symlink makes Drupal aware of your module without copying files.

## Workspace Parameters

| Parameter | Default | Notes |
|-----------|---------|-------|
| `project_name` | — | Drupal.org machine name (required, not mutable after creation) |
| `project_type` | `module` | `module` or `theme` (not mutable after creation) |
| `drupal_version` | `11` | `10`, `11`, or `12` |
| `issue_fork` | — | Issue number; empty = plain HEAD |
| `issue_branch` | — | Branch name; empty = default branch HEAD |
| `install_profile` | `minimal` | `minimal`, `standard`, or `demo_umami` |

## Access

After setup, access your Drupal site through:

1. **Coder dashboard** — Click the "Drupal Site" app button
2. **CLI** — `coder ssh <workspace-name>` then `ddev launch`

**Admin credentials:** admin / admin

## Development Commands

```bash
# Inside the workspace (via coder ssh or VS Code terminal):

ddev launch              # Show site URL and one-time login link
ddev describe            # Show project details and URLs

# Testing and quality (from ddev-drupal-contrib addon)
ddev phpunit             # Run PHPUnit tests for your module
ddev phpcs               # Check Drupal coding standards
ddev phpcbf              # Auto-fix coding standard issues
ddev phpstan             # Run PHPStan static analysis
ddev eslint              # JavaScript linting
ddev stylelint           # CSS linting

# Drupal management
ddev drush en {module}   # Enable a module
ddev drush cr            # Rebuild cache
ddev drush uli           # One-time login link
ddev drush status        # Check status

# DDEV management
ddev start / ddev stop   # Start or stop containers
ddev logs                # View container logs
ddev ssh                 # SSH into the web container
ddev restart             # Restart containers
```

## Working on an Issue

1. Find an issue at `drupal.org/project/{module}/issues`
2. Use the Drupal Issue Picker on your Coder instance to launch a workspace, OR pass `issue_fork` and `issue_branch` parameters manually
3. The issue branch is automatically checked out in `/home/coder/{project_name}`
4. Make your changes, run tests, commit and push

```bash
# View your working branch
git -C ~/views branch --show-current

# Run tests for your module
cd ~/views
ddev phpunit web/modules/custom/views/tests

# Check coding standards
ddev phpcs web/modules/custom/views
```

## Themes

When `project_type=theme`, the symlink is placed at `web/themes/custom/{name}` instead of `web/modules/custom/{name}`. Enable your theme with:

```bash
ddev drush theme:enable {theme_name} -y
ddev drush config-set system.theme default {theme_name} -y
```

## Requirements

- Coder v2.13+
- Sysbox runtime on agent nodes (`sysbox-runc`)
- Network access to git.drupalcode.org and packagist.org

## Troubleshooting

**Clone failed:** Check that `project_name` is a valid drupal.org machine name. Verify it exists at `git.drupalcode.org/project/{name}`.

**Issue fork not found:** The issue fork URL (`git.drupalcode.org/issue/{module}-{issue}`) may not exist yet. Create it from the issue page on drupal.org by clicking "Create issue fork."

**ddev poser failed:** Check setup logs with `cat /tmp/drupal-setup.log`. The module's `composer.json` may need adjustments for the target Drupal version.

**Module not found after symlink:** Run `ddev restart` to retrigger `ddev symlink-project`. Then `ddev drush en {module_name}`.

**Full setup log:** `cat /tmp/drupal-setup.log`

**Setup status summary:** `cat ~/SETUP_STATUS.txt`
