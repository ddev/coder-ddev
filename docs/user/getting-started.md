# Getting Started with DDEV Coder Workspaces

This guide helps you create your first DDEV workspace and start developing in the cloud.

## What is Coder?

**Coder** is an open-source platform for creating remote development environments. Instead of developing on your local machine, you work in a cloud-based workspace with all tools pre-installed.

**Key concepts:**
- **Workspace** - Your personal development environment (like a remote VM)
- **Template** - A blueprint for creating workspaces (pre-configured tools, settings)
- **Agent** - Software running in your workspace that connects to Coder server

**What is DDEV?**

**DDEV** is a local development tool for PHP, Node.js, and Python projects. It uses Docker containers to provide consistent development environments with databases, web servers, and development tools.

With this template, DDEV runs inside your cloud workspace, giving you all DDEV features without local setup.

## Prerequisites

### Coder Account

You need access to a Coder server. Ask your administrator for:
- Coder server URL (e.g., `https://coder.example.com`)
- Username and password (or SSO login)
- Confirmation that the `ddev-user` template is available

### Local Tools

Install on your local machine:

**Coder CLI** (required for SSH access):
```bash
# macOS (Homebrew)
brew install coder/coder/coder

# Linux (curl)
curl -L https://coder.com/install.sh | sh

# Windows (PowerShell)
winget install Coder.Coder

# Or download from: https://github.com/coder/coder/releases
```

**SSH client** (usually pre-installed):
```bash
# Verify SSH is available
ssh -V
```

**Git** (optional, for cloning repositories):
```bash
# macOS
brew install git

# Linux
apt-get install git  # or yum install git

# Windows
winget install Git.Git

# Verify
git --version
```

### Optional: Desktop VS Code

If you prefer desktop VS Code over the web version:
```bash
# Download from https://code.visualstudio.com/
# Install Remote-SSH extension
code --install-extension ms-vscode-remote.remote-ssh
```

## Step 1: Login to Coder

### Via Web UI

1. Open your Coder server URL in a browser
2. Enter your username and password
3. Click **Login**

You'll see the Coder dashboard.

### Via CLI

```bash
# Login to Coder server
coder login https://coder.example.com

# Enter your credentials when prompted
# Or use an API token if provided
```

**Verify login:**
```bash
coder list
# Should show your workspaces (empty if this is your first time)
```

## Step 2: Create Your First Workspace

### Via Web UI

1. Click **Create Workspace** button
2. Select **ddev-user** template
3. Enter a workspace name (e.g., `my-first-workspace`)
   - Use lowercase, numbers, hyphens
   - No spaces or special characters
4. (Optional) Configure parameters:
   - **CPU**: Number of cores (default: 4)
   - **Memory**: RAM in GB (default: 8)
   - **Node.js version**: Node version (default: 24)
5. Click **Create Workspace**

**Wait for workspace to start** (1-3 minutes):
- Status will change from "Starting" to "Running"
- You'll see the workspace dashboard

### Via CLI

```bash
# Create workspace with defaults
coder create --template ddev-user my-first-workspace --yes

# Or with custom parameters
coder create --template ddev-user my-first-workspace \
  --parameter cpu=8 \
  --parameter memory=16 \
  --yes
```

**Check workspace status:**
```bash
coder list
# Should show your workspace as "Running"
```

## Step 3: Access Your Workspace

### Option 1: VS Code for Web (Recommended for Beginners)

1. In Coder dashboard, find your workspace
2. Under **Apps**, click **VS Code**
3. VS Code opens in your browser

**You now have a full IDE in the cloud!**

### Option 2: SSH (Command Line)

```bash
# SSH into workspace
coder ssh my-first-workspace

# You're now inside your workspace
# The prompt changes to: coder@my-first-workspace:~$
```

**Run your first command:**
```bash
# Check DDEV is installed
ddev version

# Check Docker is running
docker ps

# Check Node.js version
node --version

# Exit SSH session
exit
```

### Option 3: Desktop VS Code with Remote-SSH

```bash
# Configure SSH for Coder workspaces
coder config-ssh

# Open desktop VS Code
# Use Remote-SSH extension to connect to: coder.my-first-workspace
```

## Step 4: Verify Your Environment

### Check Docker

```bash
# Inside workspace (via SSH or VS Code terminal)
docker ps
# Should show: CONTAINER ID   IMAGE   COMMAND   ...
# (Empty list is normal - no containers running yet)

docker info
# Should show Docker system information
```

If Docker doesn't work, see [Troubleshooting](#troubleshooting) below.

### Check DDEV

```bash
ddev version
# Should show DDEV version (latest version from image)

ddev list
# Should show: No running DDEV projects were found.
```

### Check Disk Space

```bash
df -h
# Should show plenty of free space on / and /home/coder
```

### Check Available Resources

```bash
# CPU cores
nproc

# RAM
free -h

# Should match what you configured (default: 4 cores, 8GB RAM)
```

## Step 5: Create Your First DDEV Project

### Option A: New Project from Scratch

```bash
# Create project directory
mkdir -p ~/projects/my-site
cd ~/projects/my-site

# Initialize DDEV project
# Choose a project type: php, wordpress, drupal, laravel, etc.
ddev config --project-type=php --docroot=web

# Start DDEV
ddev start
```

**Wait for DDEV to start** (1-2 minutes first time):
```
Starting my-site...
...
Successfully started my-site
Project can be reached at https://my-site.ddev.site
```

### Option B: Clone Existing Project

```bash
# Set up Git SSH first (see Step 8 below)

# Clone your repository
cd ~/projects
git clone git@github.com:username/repo.git my-site
cd my-site

# Configure DDEV (if not already configured)
ddev config --auto

# Start DDEV
ddev start
```

### Option C: Quick Demo with Composer Project

```bash
# Create a Laravel project
mkdir -p ~/projects/demo-laravel
cd ~/projects/demo-laravel

# Configure DDEV
ddev config --project-type=laravel --docroot=public

# Use DDEV's Composer to create Laravel project
ddev composer create laravel/laravel

# Start DDEV
ddev start
```

## Step 6: Access Your DDEV Project

### Understanding Coder Port Forwarding

DDEV normally uses URLs like `https://my-site.ddev.site`, but in Coder, you access projects via **port forwarding**.

**How it works:**
1. DDEV listens on ports 80/443 inside workspace
2. Coder forwards these ports through its proxy
3. You access via Coder's forwarded URLs

### Access Your Project

**Via Coder Web UI (Recommended):**
1. Go to Coder dashboard
2. Find your workspace
3. Under **Apps**, click **DDEV Web**
4. Your DDEV project loads in a new tab

The URL follows the pattern: `https://ddev-web--workspace-name--owner.coder.example.com/`

**Via CLI Port Forward:**
```bash
# Forward port to your local machine
coder port-forward my-first-workspace --tcp 8080:80

# Then access in your browser:
# http://localhost:8080
```

**Check DDEV status:**
```bash
ddev describe
# Shows project details and status
# Note: URLs shown by ddev describe won't work - use Coder's forwarded URLs instead
```

## Step 7: Make Changes and Test

### Edit Files

**Via VS Code for Web:**
1. Open VS Code (Apps → VS Code in Coder UI)
2. Navigate to `~/projects/my-site`
3. Edit files normally
4. Changes are saved automatically

**Via SSH and vim:**
```bash
coder ssh my-first-workspace
cd ~/projects/my-site
vim web/index.php
```

### Reload and Test

```bash
# Refresh your browser to see changes
# Or use DDEV commands:

ddev describe    # Show project info
ddev logs        # View container logs
ddev exec <cmd>  # Run command in web container
```

### Common DDEV Commands

```bash
# Start project
ddev start

# Stop project
ddev stop

# Restart project
ddev restart

# View status
ddev describe

# View logs
ddev logs

# SSH into web container
ddev ssh

# Run Composer
ddev composer install

# Run npm
ddev npm install
ddev npm run dev

# Import database
ddev import-db --file=dump.sql.gz

# Export database
ddev export-db --file=dump.sql.gz

# View all commands
ddev help
```

## Step 8: Working with Git

### Configure Git

```bash
# Inside workspace
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

### Set Up Git SSH for Private Repositories

To clone private repositories or push to GitHub/GitLab/etc, you need to add your Coder public key to your Git host.

**Step 1: Get your Coder public key**
```bash
# Inside workspace (via SSH or VS Code terminal)
coder publickey

# This shows your Coder-managed public key
# Copy the entire output (starts with ssh-ed25519 or ssh-rsa)
```

**Step 2: Add key to your Git host**

**For GitHub:**
1. Go to https://github.com/settings/keys
2. Click **New SSH key**
3. Paste your Coder public key
4. Click **Add SSH key**

**For GitLab:**
1. Go to https://gitlab.com/-/profile/keys
2. Paste your Coder public key
3. Click **Add key**

**For Bitbucket:**
1. Go to https://bitbucket.org/account/settings/ssh-keys/
2. Click **Add key**
3. Paste your Coder public key

**Step 3: Test SSH connection**
```bash
# Test GitHub
ssh -T git@github.com
# Should say: "Hi username! You've successfully authenticated..."

# Test GitLab
ssh -T git@gitlab.com
# Should say: "Welcome to GitLab, @username!"
```

### Clone and Push

```bash
# Clone private repository
cd ~/projects
git clone git@github.com:username/private-repo.git

# Make changes
cd private-repo
# ... edit files ...

# Commit and push
git add .
git commit -m "Update from Coder workspace"
git push
```

**How it works:** Coder's GitSSH wrapper automatically uses your Coder-managed SSH key for all Git operations. You don't need to manage SSH keys inside the workspace.

## Managing Your Workspace

### Stop Workspace (Save Costs)

When not actively developing:

```bash
# Via CLI
coder stop my-first-workspace

# Via UI: Click "Stop" button on workspace
```

**What happens when stopped:**
- Workspace container stops
- All files in `/home/coder` are preserved
- DDEV projects are preserved
- Billing/resource usage stops

### Start Workspace

```bash
# Via CLI
coder start my-first-workspace

# Via UI: Click "Start" button on workspace
```

**Startup time:** 30-60 seconds (faster than initial create)

**After starting:**
```bash
# SSH in
coder ssh my-first-workspace

# Restart DDEV projects
cd ~/projects/my-site
ddev start
```

### Delete Workspace (Permanent)

⚠️ **Warning:** This deletes all data permanently!

```bash
# Via CLI
coder delete my-first-workspace

# Via UI: Click "Delete" button, confirm
```

**What gets deleted:**
- Workspace container
- All files in `/home/coder`
- All DDEV projects and databases
- Docker images and volumes inside workspace

**Before deleting:**
```bash
# Backup important data
cd ~/projects
tar -czf backup.tar.gz my-site/
# Download via VS Code or scp
```

## Troubleshooting

### Workspace Won't Start

**Check status:**
```bash
coder list
# If stuck in "Starting", check logs:
coder logs my-first-workspace
```

**Common causes:**
- Template not deployed correctly (contact admin)
- Resource limits exceeded (contact admin)
- Sysbox runtime not installed on host (contact admin)

### Docker Not Working

**Symptom:** `Cannot connect to Docker daemon`

**Solution:**
```bash
# Check Docker service
systemctl status docker

# Restart Docker
sudo systemctl restart docker

# Wait a few seconds, then test
docker ps
```

If still broken, restart workspace: `coder restart my-first-workspace`

### DDEV Won't Start

**Symptom:** `ddev start` fails

**Check Docker first:**
```bash
docker ps
# If this fails, fix Docker before DDEV
```

**Common DDEV issues:**
```bash
# Reset DDEV project
ddev poweroff
ddev start

# Or delete and recreate
ddev delete --omit-snapshot
ddev config --auto
ddev start
```

### Can't Access DDEV Project

**Symptom:** Port forwarding shows ports but URLs don't load

**Check:**
```bash
# Inside workspace
ddev describe
curl localhost:80
# Should return HTML
```

**Solution:**
- Use Coder's port forwarding links (not DDEV URLs)
- Find port URLs in the **Ports** section of Coder web UI
- DDEV's URLs (*.ddev.site) won't work in Coder

### Git SSH Not Working

**Symptom:** `Permission denied (publickey)` when cloning

**Solution:**
1. Get your Coder public key: `coder publickey`
2. Add that key to GitHub/GitLab (Settings → SSH Keys)
3. Test: `ssh -T git@github.com`
4. If still failing, regenerate: `coder publickey --reset` and add new key to Git host

### Out of Disk Space

**Symptom:** `No space left on device`

**Solution:**
```bash
# Clean Docker images and volumes
docker system prune -a --volumes -f

# Check disk usage
df -h
du -sh ~/projects/*

# Delete unused projects
rm -rf ~/projects/old-project
```

### Workspace is Slow

**Check resources:**
```bash
# Inside workspace
top        # Check CPU usage
free -h    # Check RAM usage
docker stats  # Check Docker container resources
```

**Solution:**
- Stop unused DDEV projects: `ddev stop --all`
- Increase workspace resources (delete and recreate with higher CPU/RAM)
- Contact admin to increase default resources

## Next Steps

### Learn More About DDEV

- **[DDEV Documentation](https://docs.ddev.com/)** - Full DDEV docs
- **[DDEV Quickstart](https://docs.ddev.com/en/stable/users/quickstart/)** - DDEV basics
- **[DDEV Commands](https://docs.ddev.com/en/stable/users/usage/commands/)** - Command reference

### Learn More About Coder

- **[Using Workspaces](./using-workspaces.md)** - Daily workflows and tips
- **[Coder CLI](https://coder.com/docs/cli)** - CLI reference
- **[VS Code for Web](https://coder.com/docs/ides/web-ides)** - IDE features

### Try More Project Types

```bash
# WordPress
ddev config --project-type=wordpress --docroot=web
ddev composer create roots/bedrock

# Drupal
ddev config --project-type=drupal --docroot=web
ddev composer create drupal/recommended-project

# Laravel
ddev config --project-type=laravel --docroot=public
ddev composer create laravel/laravel

# Node.js (generic)
ddev config --project-type=php --docroot=.
echo "console.log('Hello');" > server.js
node server.js

# Static site
ddev config --project-type=php --docroot=.
echo "<h1>Hello World</h1>" > index.html
ddev start
```

### Customize Your Workspace

```bash
# Install additional tools
sudo apt-get update
sudo apt-get install <package>

# Install global npm packages
npm install -g <package>

# Add shell aliases
echo 'alias ll="ls -la"' >> ~/.bashrc
source ~/.bashrc
```

**Note:** Changes to system packages are lost when workspace is deleted. For permanent changes, ask admin to modify Docker image.

## Tips and Best Practices

### File Organization

```bash
~/projects/              # All DDEV projects here
  ├── project1/
  ├── project2/
  └── project3/
~/.ddev/                 # DDEV global config (auto-created)
~/.ssh/                  # SSH keys (managed by Coder)
```

### Resource Management

- **Stop workspaces** when not in use (saves costs)
- **Stop unused DDEV projects**: `ddev stop --all`
- **Clean Docker regularly**: `docker system prune -a`

### Backup Important Data

- **Commit to Git** regularly (safest backup)
- **Export databases**: `ddev export-db --file=backup.sql.gz`
- **Download files** via VS Code or `coder scp`

### Performance

- **Use smaller workspaces** for simple projects (2 CPU, 4GB RAM)
- **Increase resources** for large projects (8 CPU, 16GB RAM)
- **Stop background services** when not needed

## Getting Help

### Documentation

- [Using Workspaces](./using-workspaces.md) - Advanced workflows
- [Troubleshooting Guide](../admin/troubleshooting.md) - Detailed debugging
- [DDEV Docs](https://docs.ddev.com/) - DDEV reference

### Support

- **Ask your administrator** for Coder-specific issues
- **GitHub Issues**: [Report bugs](https://github.com/ddev/coder-ddev/issues)
- **DDEV Community**: [DDEV Discord](https://discord.gg/hCZFfAMc5k)
- **Coder Community**: [Coder Discord](https://discord.gg/coder)

### Before Asking for Help

1. Check this guide's [Troubleshooting](#troubleshooting) section
2. Review [Troubleshooting Guide](../admin/troubleshooting.md)
3. Collect error messages and logs
4. Try restarting workspace: `coder restart my-first-workspace`

---

**Congratulations!** You've created your first DDEV workspace. Happy coding! 🎉
