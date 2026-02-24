# Using DDEV Coder Workspaces

This guide covers daily workflows, tips, and best practices for working with DDEV in Coder workspaces.

## Table of Contents

- [Workspace Lifecycle](#workspace-lifecycle)
- [VS Code for Web](#vs-code-for-web)
- [DDEV Workflows](#ddev-workflows)
- [Git Workflows](#git-workflows)
- [Port Forwarding](#port-forwarding)
- [Common Tasks](#common-tasks)
- [Tips and Tricks](#tips-and-tricks)
- [Performance Optimization](#performance-optimization)

## Workspace Lifecycle

### Understanding Persistence

Your workspace has two types of storage:

**Persistent (survives stop/restart):**
- `/home/coder` directory (all your files)
- Docker volumes (DDEV databases, images, containers)

**Non-persistent (reset on restart):**
- Running processes
- Temporary files in `/tmp`
- System packages installed with `apt-get` (unless in Docker image)

**What this means:**
- Your code, databases, and DDEV projects are safe when stopping workspace
- You need to restart DDEV projects after workspace restart
- System-level changes (installed packages) are lost unless in Docker image

### Starting Your Day

```bash
# 1. Start workspace (if stopped)
coder start my-workspace

# 2. SSH into workspace (or open VS Code)
coder ssh my-workspace

# 3. Navigate to project
cd ~/projects/my-site

# 4. Start DDEV
ddev start

# 5. Start developing!
```

### Ending Your Day

```bash
# 1. Commit your changes
git add .
git commit -m "End of day commit"
git push

# 2. Stop DDEV projects (optional, saves a few seconds on next start)
ddev stop

# 3. Exit workspace
exit

# 4. Stop workspace (saves costs)
coder stop my-workspace
```

**Note:** Stopping workspace is optional. Some teams leave workspaces running 24/7.

### Workspace States

| State | Description | Billing | Data Preserved |
|-------|-------------|---------|----------------|
| **Running** | Active, can SSH and access | Yes | Yes |
| **Stopped** | Powered off, cannot access | No | Yes |
| **Starting** | Booting up, wait a moment | No | Yes |
| **Deleting** | Being deleted | No | No |

### Managing Multiple Workspaces

```bash
# List all your workspaces
coder list

# Create second workspace
coder create --template ddev-user my-second-workspace --yes

# Switch between workspaces
coder ssh my-first-workspace
coder ssh my-second-workspace

# Stop all workspaces
coder stop my-first-workspace my-second-workspace
```

**Use cases for multiple workspaces:**
- Different projects with different requirements
- Testing configurations without affecting main workspace
- Separate staging and development environments
- Different resource configurations (small vs large projects)

## VS Code for Web

### Accessing VS Code

**From Coder dashboard:**
1. Find your workspace
2. Click **VS Code** under "Apps"
3. VS Code opens in new tab

**Direct URL** (bookmark this):
```
https://coder.example.com/@me/my-workspace/apps/code
```

### Initial Setup

**Install essential extensions:**
1. Open Extensions panel (Ctrl+Shift+X or Cmd+Shift+X)
2. Search and install:
   - **PHP** - Language support for PHP
   - **ESLint** - JavaScript/TypeScript linting
   - **Prettier** - Code formatting
   - **GitLens** - Enhanced Git features
   - **Docker** - Docker container management
   - **Live Share** - Real-time collaboration (optional)

**Configure settings:**
```json
// Settings → Open Settings (JSON)
{
  "editor.formatOnSave": true,
  "editor.tabSize": 2,
  "files.autoSave": "afterDelay",
  "terminal.integrated.defaultProfile.linux": "bash"
}
```

### Terminal in VS Code

**Open terminal:**
- Menu: Terminal → New Terminal
- Keyboard: Ctrl+` (backtick)

**Multiple terminals:**
- Click `+` to add terminal
- Split terminal with split button
- Switch between terminals with dropdown

**Terminal tips:**
```bash
# Terminal opens in /home/coder by default
# Navigate to project
cd ~/projects/my-site

# Run DDEV commands
ddev start
ddev describe

# Run composer/npm through DDEV
ddev composer install
ddev npm run dev
```

### File Management

**Opening projects:**
1. File → Open Folder
2. Navigate to `~/projects/my-site`
3. Click **OK**

**Drag and drop:**
- Drag files from your computer into VS Code to upload
- Works for single files and folders (up to reasonable size)

**File search:**
- **Ctrl+P** (Cmd+P): Quick file open
- **Ctrl+Shift+F** (Cmd+Shift+F): Search in files
- **Ctrl+Shift+E** (Cmd+Shift+E): File explorer

### Git Integration

**Built-in Git features:**
- **Source Control** panel (Ctrl+Shift+G)
- Stage changes (click `+` next to file)
- Commit (type message, click ✓)
- Push/pull (click `...` menu)
- View diff (click modified file)

**GitLens extension features:**
- Blame annotations (who changed each line)
- Commit history
- Repository explorer
- Compare branches

### Debugging

VS Code supports debugging for most languages:

**PHP (with Xdebug via DDEV):**
```bash
# Enable Xdebug
ddev xdebug on

# In VS Code:
# 1. Install PHP Debug extension
# 2. Add breakpoint (click left of line number)
# 3. F5 to start debugging
# 4. Refresh browser to trigger breakpoint
```

**Node.js:**
```json
// .vscode/launch.json
{
  "type": "node",
  "request": "launch",
  "name": "Launch Program",
  "program": "${workspaceFolder}/server.js"
}
```

Press **F5** to start debugging.

### Extensions for DDEV Projects

**PHP projects:**
- PHP Intelephense
- PHP DocBlocker
- PHPUnit Test Explorer

**WordPress:**
- WordPress Snippets
- WordPress Hooks Intellisense

**Drupal:**
- Drupal 8/9 Snippets
- Drupal Smart Snippets

**Laravel:**
- Laravel Blade Snippets
- Laravel Extra Intellisense

**Node.js:**
- npm Intellisense
- ES7+ React/Redux/React-Native snippets

### Keyboard Shortcuts

| Action | macOS | Windows/Linux |
|--------|-------|---------------|
| Command palette | Cmd+Shift+P | Ctrl+Shift+P |
| Quick open file | Cmd+P | Ctrl+P |
| Terminal | Cmd+` | Ctrl+` |
| Find in files | Cmd+Shift+F | Ctrl+Shift+F |
| Save | Cmd+S | Ctrl+S |
| Format document | Shift+Alt+F | Shift+Alt+F |
| Go to definition | F12 | F12 |
| Find references | Shift+F12 | Shift+F12 |

## DDEV Workflows

### Project Types

DDEV supports 20+ project types. Common examples:

**WordPress:**
```bash
mkdir ~/projects/my-wordpress
cd ~/projects/my-wordpress
ddev config --project-type=wordpress --docroot=web
ddev start
ddev composer create roots/bedrock
```

**Drupal:**
```bash
mkdir ~/projects/my-drupal
cd ~/projects/my-drupal
ddev config --project-type=drupal --docroot=web
ddev composer create drupal/recommended-project
ddev drush site:install --account-name=admin --account-pass=admin -y
```

**Laravel:**
```bash
mkdir ~/projects/my-laravel
cd ~/projects/my-laravel
ddev config --project-type=laravel --docroot=public
ddev composer create laravel/laravel
ddev exec php artisan key:generate
```

**Generic PHP:**
```bash
mkdir ~/projects/my-php-site
cd ~/projects/my-php-site
ddev config --project-type=php --docroot=web
mkdir web
echo "<?php phpinfo();" > web/index.php
ddev start
```

**Node.js:**
```bash
mkdir ~/projects/my-node-app
cd ~/projects/my-node-app
ddev config --project-type=php --docroot=.
npm init -y
npm install express
# Create server.js
ddev start
ddev exec node server.js
```

### Database Management

**Import database:**
```bash
# From SQL file
ddev import-db --file=dump.sql

# From compressed file
ddev import-db --file=dump.sql.gz

# From URL
ddev import-db --url=https://example.com/dump.sql.gz
```

**Export database:**
```bash
# Export to file
ddev export-db --file=dump.sql.gz

# Export to stdout (for piping)
ddev export-db > dump.sql
```

**Direct MySQL access:**
```bash
# MySQL CLI
ddev mysql

# Run SQL file
ddev mysql < query.sql

# One-line query
ddev mysql -e "SELECT * FROM users LIMIT 10;"
```

**Database GUI** (via browser):
```bash
# phpMyAdmin (if configured in .ddev/config.yaml)
ddev launch -p

# Or use MySQL Workbench/TablePlus via SSH tunnel:
coder port-forward my-workspace --tcp 3306:3306
# Connect to localhost:3306 from your machine
```

### Running Commands

**Execute commands in web container:**
```bash
# Generic command
ddev exec <command>

# Examples
ddev exec pwd
ddev exec ls -la
ddev exec which php

# Run as root
ddev exec sudo <command>
```

**SSH into web container:**
```bash
ddev ssh

# You're now inside the web container
# Run any command
composer install
npm run build
exit
```

**Composer commands:**
```bash
ddev composer install
ddev composer require vendor/package
ddev composer update
ddev composer dump-autoload
```

**npm/yarn commands:**
```bash
ddev npm install
ddev npm run dev
ddev npm run build
ddev yarn install
ddev yarn build
```

### Custom Commands

**Create custom DDEV commands:**
```bash
# Create .ddev/commands/web/ directory
mkdir -p .ddev/commands/web

# Create custom command
cat > .ddev/commands/web/mycommand <<'EOF'
#!/bin/bash
## Description: My custom command
## Usage: mycommand [args]
echo "Running my custom command"
# Your commands here
EOF

chmod +x .ddev/commands/web/mycommand

# Use it
ddev mycommand
```

### Multiple Projects

**Running multiple DDEV projects:**
```bash
# Start all projects
cd ~/projects/project1 && ddev start
cd ~/projects/project2 && ddev start
cd ~/projects/project3 && ddev start

# List running projects
ddev list

# Stop specific project
cd ~/projects/project1
ddev stop

# Stop all projects
ddev stop --all

# Power off all (removes containers)
ddev poweroff
```

**Port conflicts:**
If you run multiple projects simultaneously, they'll use different ports automatically. Check with:
```bash
ddev describe
# Shows URLs and ports for each project
```

## Git Workflows

### Initial Configuration

```bash
# Set your identity (one-time setup)
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Set default branch name
git config --global init.defaultBranch main

# Useful aliases
git config --global alias.st status
git config --global alias.co checkout
git config --global alias.br branch
git config --global alias.ci commit
```

### SSH Keys

**Your SSH key is managed by Coder** and automatically available in workspaces.

**Get your Coder public key:**
```bash
# Inside workspace
coder publickey

# Copy the output (starts with ssh-ed25519 or ssh-rsa)
```

**Add key to your Git host:**
1. **GitHub**: https://github.com/settings/keys → New SSH key
2. **GitLab**: https://gitlab.com/-/profile/keys → Add key
3. **Bitbucket**: https://bitbucket.org/account/settings/ssh-keys/ → Add key

**Test SSH:**
```bash
# Test GitHub
ssh -T git@github.com
# Should say: "Hi username! You've successfully authenticated..."

# Test GitLab
ssh -T git@gitlab.com
# Should say: "Welcome to GitLab, @username!"
```

**How it works:** Coder's GitSSH wrapper uses your Coder-managed SSH key automatically. No need to manage keys inside the workspace.

### Common Workflows

**Clone and start working:**
```bash
cd ~/projects
git clone git@github.com:username/repo.git
cd repo
ddev config --auto  # If .ddev/config.yaml exists
ddev start
```

**Daily workflow:**
```bash
# Pull latest changes
git pull

# Create feature branch
git checkout -b feature/my-feature

# Make changes
# ... edit files ...

# Check status
git status

# Stage changes
git add .

# Commit
git commit -m "Add my feature"

# Push
git push origin feature/my-feature
```

**Stash changes:**
```bash
# Stash uncommitted changes
git stash

# Pull latest
git pull

# Restore stashed changes
git stash pop
```

**Merge conflicts:**
```bash
# If pull creates conflicts
git pull
# Auto-merging file.php
# CONFLICT (content): Merge conflict in file.php

# Resolve in VS Code (shows conflict markers)
# Edit file, remove <<<<<<, ======, >>>>>>

# Stage resolved files
git add file.php

# Complete merge
git commit
```

### Pre-commit Hooks

```bash
# Install pre-commit hooks (if project uses them)
cd ~/projects/my-site

# If using PHP CodeSniffer
ddev composer require --dev phpcodesniffer

# If using ESLint
ddev npm install --save-dev eslint

# Hooks run automatically on git commit
git commit -m "Test commit"
# Runs linters, formatters, etc.
```

## Port Forwarding

### How Port Forwarding Works

In Coder, you **don't** access services via direct URLs. Instead:

1. Service listens on port inside workspace (e.g., DDEV on port 80)
2. Coder proxies port through its server
3. You access via Coder's secure URL

**Traditional DDEV:**
```
https://my-site.ddev.site  ← Doesn't work in Coder
```

**Coder DDEV:**
```
https://ddev-web--workspace-name--owner.coder.example.com/  ← Use DDEV Web app URL
```

### Accessing DDEV Projects

**Via Coder UI (Recommended):**
1. Go to workspace in Coder dashboard
2. Under **Apps**, click **DDEV Web**
3. Your DDEV project loads in a new tab

The URL follows the pattern: `https://ddev-web--workspace-name--owner.domain/`

**Common DDEV ports:**
- **80**: HTTP web server
- **443**: HTTPS web server
- **8025**: Mailpit web UI (email testing)
- **3306**: MySQL (for external DB tools)

### Port Forwarding via CLI

```bash
# Forward port to local machine
coder port-forward my-workspace --tcp 80:80

# Now access via:
# http://localhost:80

# Forward MySQL for database tools
coder port-forward my-workspace --tcp 3306:3306

# Connect MySQL Workbench or TablePlus to:
# Host: localhost, Port: 3306
```

### Custom Services

If you run custom services, add port forwarding in `template.tf` (ask admin) or use CLI:

```bash
# Forward custom port (e.g., Node.js on 3000)
coder port-forward my-workspace --tcp 3000:3000

# Access via:
# http://localhost:3000
```

## Common Tasks

### Importing Existing Projects

**From Git repository:**
```bash
cd ~/projects
git clone git@github.com:username/existing-project.git
cd existing-project
ddev config --auto  # Auto-detect project type
ddev start
ddev composer install  # Or npm install
ddev import-db --file=backup.sql.gz
```

**From local machine:**
```bash
# Option 1: Via VS Code drag-and-drop
# Open VS Code, drag project folder into file explorer

# Option 2: Via SCP
coder scp ./local-project my-workspace:~/projects/

# Then in workspace:
cd ~/projects/local-project
ddev config --auto
ddev start
```

### Database Snapshots

```bash
# Create snapshot (backup current state)
ddev snapshot

# Restore snapshot (revert to last snapshot)
ddev snapshot restore

# List snapshots
ddev snapshot --list

# Delete snapshots
ddev snapshot --cleanup
```

**Use case:** Before risky database changes:
```bash
ddev snapshot
# Try risky migration
ddev exec drush updatedb
# If fails, restore:
ddev snapshot restore
```

### File Sync and Backup

**Download files from workspace:**
```bash
# Via SCP
coder scp my-workspace:~/projects/my-site ./local-backup/

# Via VS Code
# Right-click file/folder → Download
```

**Upload files to workspace:**
```bash
# Via SCP
coder scp ./local-files my-workspace:~/projects/my-site/

# Via VS Code drag-and-drop
```

**Backup entire project:**
```bash
# Inside workspace
cd ~/projects
tar -czf my-site-backup.tar.gz my-site/

# Download
exit
coder scp my-workspace:~/projects/my-site-backup.tar.gz ./
```

### Package Management

**Composer (PHP):**
```bash
ddev composer install          # Install dependencies
ddev composer require pkg/name # Add package
ddev composer update           # Update packages
ddev composer dump-autoload    # Rebuild autoloader
```

**npm (Node.js):**
```bash
ddev npm install           # Install dependencies
ddev npm install package   # Add package
ddev npm update            # Update packages
ddev npm run <script>      # Run package.json script
```

**System packages** (not persistent):
```bash
# Install system tool (temporary)
sudo apt-get update
sudo apt-get install <package>

# For permanent install, ask admin to add to Docker image
```

### Logs and Debugging

**DDEV logs:**
```bash
# All containers
ddev logs

# Specific container
ddev logs web
ddev logs db

# Follow logs (like tail -f)
ddev logs -f
```

**Docker logs:**
```bash
# List containers
docker ps

# View logs
docker logs <container-id>

# Follow logs
docker logs -f <container-id>
```

**System logs:**
```bash
# Coder agent logs
journalctl -u coder-agent -f

# Docker daemon logs
journalctl -u docker -f

# Docker daemon logs (written by startup script)
cat /tmp/dockerd.log
```

**Debug DDEV:**
```bash
# Verbose output
ddev start --debug

# Show DDEV config
ddev describe

# Show Docker info
docker info

# Show DDEV version
ddev version
```

## Tips and Tricks

### Aliases and Shortcuts

Add to `~/.bashrc`:
```bash
# DDEV aliases
alias dl='ddev list'
alias ds='ddev start'
alias dx='ddev stop'
alias dr='ddev restart'
alias de='ddev exec'

# Git aliases
alias gs='git status'
alias gp='git pull'
alias gc='git commit'
alias gco='git checkout'

# Navigation
alias projects='cd ~/projects'
alias ll='ls -la'

# Reload bashrc
source ~/.bashrc
```

### VS Code Workspace Settings

**Per-project settings** (`.vscode/settings.json`):
```json
{
  "php.validate.executablePath": "/usr/bin/php",
  "phpcs.executablePath": "/usr/bin/phpcs",
  "eslint.workingDirectories": ["web/themes/custom"],
  "files.exclude": {
    "**/vendor": true,
    "**/node_modules": true
  }
}
```

Commit this file to Git for team consistency.

### Performance Shortcuts

**Skip DDEV router** (for simple projects):
```yaml
# .ddev/config.yaml
router_disabled: true

# Access via port forwarding instead of ddev URLs
```

**Disable unnecessary services:**
```yaml
# .ddev/config.yaml
omit_containers: ["ddev-ssh-agent"]
```

**Use shallow Git clones:**
```bash
git clone --depth 1 git@github.com:user/repo.git
```

### Multi-tab Workflows

**Typical setup:**
1. **Tab 1**: VS Code (editing)
2. **Tab 2**: Coder dashboard (port forwarding)
3. **Tab 3**: DDEV project (browser)
4. **Tab 4**: Mailpit (email testing)

Use browser bookmarks for quick access.

### Keyboard-driven Development

**Fast workflow:**
```bash
# Terminal-only workflow (no clicking)
coder ssh my-workspace
cd ~/projects/my-site
ddev start
ddev logs -f &  # Background logs
vim web/index.php
git add . && git commit -m "Update" && git push
ddev describe  # Get ports, open in browser
```

## Performance Optimization

### Workspace Resources

**Check current resources:**
```bash
# CPU cores
nproc

# RAM
free -h

# Disk
df -h
```

**If workspace is slow, increase resources:**
```bash
# Stop workspace
coder stop my-workspace

# Delete and recreate with more resources
coder delete my-workspace --yes
coder create --template ddev-user my-workspace \
  --parameter cpu=8 \
  --parameter memory=16 \
  --yes

# Restore from Git
cd ~/projects
git clone git@github.com:user/repo.git
```

### DDEV Performance

**Disable Xdebug** (when not debugging):
```bash
ddev xdebug off
```

**Use NFS** (if file operations are slow):
```yaml
# .ddev/config.yaml
nfs_mount_enabled: true
```

**Reduce container memory:**
```yaml
# .ddev/config.yaml
resources:
  limits:
    memory: 2g
```

### Docker Cleanup

```bash
# Remove unused images/containers
docker system prune -a -f

# Remove all volumes (careful!)
docker volume prune -f

# Check disk usage
docker system df
```

### Git Performance

**Shallow clones** (for large repos):
```bash
git clone --depth 1 --single-branch git@github.com:user/repo.git
```

**Sparse checkout** (for monorepos):
```bash
git clone --filter=blob:none --sparse git@github.com:user/repo.git
cd repo
git sparse-checkout set path/to/needed/directory
```

## Getting Help

### Documentation

- [Getting Started Guide](./getting-started.md) - First-time setup
- [Troubleshooting Guide](../admin/troubleshooting.md) - Debugging
- [DDEV Documentation](https://docs.ddev.com/) - DDEV reference
- [Coder Documentation](https://coder.com/docs) - Coder platform docs

### Community

- [GitHub Issues](https://github.com/ddev/coder-ddev/issues) - Report bugs
- [DDEV Discord](https://discord.gg/hCZFfAMc5k) - DDEV community
- [Coder Discord](https://discord.gg/coder) - Coder community

### Quick Troubleshooting

| Problem | Quick Fix |
|---------|-----------|
| Docker not working | `sudo systemctl restart docker` |
| DDEV won't start | `ddev poweroff && ddev start` |
| Out of disk space | `docker system prune -a -f` |
| Workspace slow | Stop unused DDEV projects: `ddev stop --all` |
| Git SSH failing | Re-add SSH key to Coder and Git host |
| Port not accessible | Use Coder UI port links, not direct URLs |

---

**Happy coding!** For more help, see [Getting Started](./getting-started.md) or [Troubleshooting Guide](../admin/troubleshooting.md).
