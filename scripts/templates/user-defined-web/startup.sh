#!/usr/bin/env bash
# scripts/templates/user-defined-web/startup.sh
# Workspace startup script for the user-defined-web template.
#
# Required env vars (set on coder_agent.env in user-defined-web/template.tf):
#   REGISTRY_MIRROR  - Docker registry mirror URL (from var.docker_registry_mirror).
#                      May be empty; startup auto-detects http://<coder-host>:5000 if reachable.
#
# Exit codes:
#   0   - workspace ready
#   1   - generic failure (note: body uses `set +e`, so most failures continue)
#
# Idempotency: yes — safe to re-run on workspace restart.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED_DIR="${SCRIPT_DIR}/../../shared"
# shellcheck source=../../shared/lib.sh
. "${SHARED_DIR}/lib.sh"

# Conditionally source shared helpers when WP06 ships them.
# Pre-WP06 they don't exist; the [ -f ] guard makes this a no-op.
for _helper in start-dockerd hydrate-coder-files install-ddev-config configure-git-ssh; do
  if [ -f "${SHARED_DIR}/${_helper}.sh" ]; then
    # shellcheck source=/dev/null
    . "${SHARED_DIR}/${_helper}.sh"
  fi
done
unset _helper

#!/bin/bash
# Don't exit on error - let installation continue even if some steps fail
set +e

echo "Startup script started..."

# Define Sudo Command
if command -v sudo > /dev/null 2>&1; then
  SUDO="sudo"
else
  SUDO=""
fi

# Fix permissions for Host Bind Mount
# Since we are mounting /home/coder from the host (which might be owned by a different UID),
# we need to ensure the container user owns it.

# Standard Home Directory Strategy for Sysbox
# We mount the persistent volume directly to /home/coder.
# No need to rewrite /etc/passwd or change HOME environment variable manually.

# Ensure ownership of /home/coder
# Since the volume comes from the host, it might have host permissions.
# We fix this on every startup.
sudo chown coder:coder /home/coder

# Copy defaults if empty (first run)
if [ ! -f "/home/coder/.bashrc" ]; then
    echo "Initializing home directory..."
    cp -rT /etc/skel/. /home/coder/
fi

cd /home/coder

echo "=========================================="
echo "Starting workspace setup..."
echo "=========================================="
echo "Workspace Home: $HOME"


# Ensure GIT_SSH_COMMAND is set (Coder sets this automatically, but we ensure it's available)
# The Coder GitSSH wrapper is located in /tmp/coder.*/coder and handles authentication
if [ -z "$GIT_SSH_COMMAND" ]; then
  # Try to find the Coder GitSSH wrapper
  CODER_GITSSH=$(find /tmp -name "coder" -path "*/coder.*/*" -type f -executable 2>/dev/null | head -1)
  if [ -n "$CODER_GITSSH" ]; then
    export GIT_SSH_COMMAND="$CODER_GITSSH gitssh"
    # DO NOT persist this to .bashrc as the path changes per session!
    echo "✓ Coder GitSSH wrapper found and configured for this session"
  else
    echo "Note: Coder GitSSH wrapper not found. Git operations may require manual SSH key setup."
    echo "Get your public key with: coder publickey"
  fi
else
  echo "✓ GIT_SSH_COMMAND already set: $GIT_SSH_COMMAND"
fi

echo "✓ SSH setup completed"


echo ""

echo ""

# Copy files from /home/coder-files to /home/coder
# The volume mount at /home/coder overrides image contents, but /home/coder-files is outside the mount
echo "Copying files from /home/coder-files to ~/..."
if [ -d /home/coder-files ]; then

  
  # Copy WELCOME.txt if it doesn't exist
  if [ ! -f ~/WELCOME.txt ] && [ -f /home/coder-files/WELCOME.txt ]; then
    cp /home/coder-files/WELCOME.txt ~/WELCOME.txt
    chown coder:coder ~/WELCOME.txt 2>/dev/null || true
    echo "✓ Copied WELCOME.txt from /home/coder-files"
  fi
  
  # Copy VS Code settings to enable login shell
  if [ -d /home/coder-files/.vscode ]; then
    mkdir -p ~/.vscode
    if [ -f /home/coder-files/.vscode/settings.json ]; then
      cp /home/coder-files/.vscode/settings.json ~/.vscode/settings.json
      chown coder:coder ~/.vscode/settings.json 2>/dev/null || true
      echo "✓ Copied VS Code settings for login shell"
    fi
  fi
else
  echo "Warning: /home/coder-files not found in image"
fi

# Git configuration: copy defaults on first run, set identity from Coder owner
if [ ! -f "$HOME/.gitconfig" ] && [ -f /home/coder-files/.gitconfig ]; then
  cp /home/coder-files/.gitconfig "$HOME/.gitconfig"
  echo "✓ Copied default .gitconfig"
fi
if [ ! -f "$HOME/.gitignore_global" ] && [ -f /home/coder-files/.gitignore_global ]; then
  cp /home/coder-files/.gitignore_global "$HOME/.gitignore_global"
  echo "✓ Copied default .gitignore_global"
elif [ -f "$HOME/.gitignore_global" ]; then
  grep -qxF 'config.coder.yaml' "$HOME/.gitignore_global" || \
    echo 'config.coder.yaml' >> "$HOME/.gitignore_global"
fi
mkdir -p ~/.ddev
ddev config global --instrumentation-opt-in=true > /dev/null 2>&1 || true
if [ -n "$CODER_WORKSPACE_OWNER_NAME" ]; then
  git config --global user.name "$CODER_WORKSPACE_OWNER_NAME"
fi
if [ -n "$CODER_WORKSPACE_OWNER_EMAIL" ]; then
  git config --global user.email "$CODER_WORKSPACE_OWNER_EMAIL"
fi

# Install Docker CLI (Required for DDEV DooD)
# Docker CLI is now pre-installed in the Docker image (v3.0.29+)
if ! command -v docker > /dev/null; then
  echo "Error: Docker CLI not found in image. Please update the workspace image."
fi
    
# Generate locale to fix "cannot change locale" warnings
# Locale generation is now handled in the Docker image
# $SUDO locale-gen en_US.UTF-8

# Set locale env vars
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
if ! grep -q "LC_ALL=en_US.UTF-8" ~/.bashrc; then
  echo "export LANG=en_US.UTF-8" >> ~/.bashrc
  echo "export LC_ALL=en_US.UTF-8" >> ~/.bashrc
fi

# FIX: Remove stale GIT_SSH_COMMAND from .bashrc if present (from older versions)
sed -i '/export GIT_SSH_COMMAND=/d' ~/.bashrc || true

# Add git branch to bash prompt
if ! grep -q "git_prompt()" ~/.bashrc; then
  echo '' >> ~/.bashrc
  echo '# Git branch in prompt' >> ~/.bashrc
  echo 'git_prompt() {' >> ~/.bashrc
  echo '    local branch' >> ~/.bashrc
  echo '    branch="$(git symbolic-ref HEAD 2>/dev/null | cut -d/ -f3-)"' >> ~/.bashrc
  echo '    [ -n "$branch" ] && echo " ($branch)"' >> ~/.bashrc
  echo '}' >> ~/.bashrc
  echo 'PS1='\''\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]$(git_prompt)\$ '\''' >> ~/.bashrc
fi

# Node.js, TypeScript, and DDEV are now pre-installed in the Docker image (v3.0.30+)


# Configure Docker daemon registry mirror.
# Priority: explicit Terraform variable, then auto-detect on Coder host:5000 if reachable.
# REGISTRY_MIRROR is injected via coder_agent.env
if [ -z "$REGISTRY_MIRROR" ] && [ -n "$CODER_AGENT_URL" ]; then
  CODER_HOST=$(echo "$CODER_AGENT_URL" | sed -E 's#^https?://([^/:]+).*$#\1#')
  CANDIDATE_MIRROR="http://$CODER_HOST:5000"
  if [ -n "$CODER_HOST" ] && curl -fsS --max-time 2 "$CANDIDATE_MIRROR/v2/" > /dev/null 2>&1; then
    REGISTRY_MIRROR="$CANDIDATE_MIRROR"
    echo "Detected registry mirror on Coder host: $REGISTRY_MIRROR"
  else
    echo "No reachable registry mirror detected on Coder host; continuing without mirror"
  fi
fi
if [ -n "$REGISTRY_MIRROR" ]; then
  echo "Configuring Docker registry mirror: $REGISTRY_MIRROR"
  MIRROR_HOST=$(echo "$REGISTRY_MIRROR" | sed 's|https\?://||')
  sudo mkdir -p /etc/docker
  sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "registry-mirrors": ["$REGISTRY_MIRROR"],
  "insecure-registries": ["$MIRROR_HOST"]
}
EOF
fi

# Start Docker Daemon (Sysbox)
# Since we are not booting with systemd as PID 1, we must start dockerd manually.
if ! pgrep -x "dockerd" > /dev/null; then
  echo "Starting Docker Daemon..."
  # Use sudo because we are running as coder user
  sudo dockerd > /tmp/dockerd.log 2>&1 &
  
  # Wait for Docker Socket
  echo "Waiting for Docker Socket..."
  for i in $(seq 1 30); do
    if [ -S /var/run/docker.sock ]; then
      echo "Docker Socket found!"
      break
    fi
    sleep 1
  done
  
  # Fix permissions so 'coder' user can access it
  if [ -S /var/run/docker.sock ]; then
    sudo chmod 666 /var/run/docker.sock
  else
    echo "Error: Docker Socket not found after 30s!"
  fi
else
  echo "Docker Daemon already running."
fi

# Create .ddev directory
mkdir -p ~/.ddev

# Pre-pull DDEV images in background (uses registry mirror if configured)
ddev utility download-images || true

# Create projects directory for Drupal projects
mkdir -p ~/projects


# Display welcome message
cat ~/WELCOME.txt
echo ""
echo "Welcome message saved to ~/WELCOME.txt"

# Set workspace ID as environment variable (extracted from container name or Coder env)
# Container name format: coder-{workspace-id}
if [ -z "$CODER_WORKSPACE_ID" ]; then
  # Try to extract from container hostname or environment
  CODER_WORKSPACE_ID=$(hostname | sed 's/coder-//' || echo "")
fi
if [ -z "$CODER_WORKSPACE_ID" ]; then
  # Fallback: use first 8 characters of hostname or generate from hostname
  CODER_WORKSPACE_ID=$(hostname | cut -c1-8 || echo "workspace")
fi
export CODER_WORKSPACE_ID

# Set workspace name as environment variable (for unique ddev project names)
# Extract from hostname (format: coder-{workspace-id}) or use workspace ID
# Workspace name is typically the last part before the workspace ID
if [ -z "$CODER_WORKSPACE_NAME" ]; then
  # Try to get from hostname pattern: coder-{workspace-name}-{id}
  # Or use a sanitized version of workspace ID
  HOSTNAME_PART=$(hostname | sed 's/coder-//' | cut -d'-' -f1)
  if [ -n "$HOSTNAME_PART" ] && [ "$HOSTNAME_PART" != "$CODER_WORKSPACE_ID" ]; then
    CODER_WORKSPACE_NAME="$HOSTNAME_PART"
  else
    # Fallback: use first part of workspace ID or "main"
    CODER_WORKSPACE_NAME=$(echo "$CODER_WORKSPACE_ID" | cut -d'-' -f1 | head -c 10 || echo "main")
  fi
fi
export CODER_WORKSPACE_NAME

# Ensure linuxbrew/homebrew is in PATH
if ! echo "$PATH" | grep -q "/home/linuxbrew/.linuxbrew/bin"; then
  echo 'export PATH="$PATH:/home/linuxbrew/.linuxbrew/bin"' >> ~/.bashrc
fi

# Remove any old welcome message entries from .bashrc (if they exist)
# We use .bash_profile instead to avoid duplicates
if [ -f ~/.bashrc ]; then
  sed -i '/WELCOME.txt/,/^fi$/d' ~/.bashrc 2>/dev/null || true
fi

# Add welcome message to .bash_profile for SSH login
# .bash_profile is executed only for login shells (SSH sessions)
if [ ! -f ~/.bash_profile ]; then
  # Create .bash_profile and source .bashrc for non-login shells
  cat > ~/.bash_profile << 'BASHPROFILE'
# Source system-wide settings (bash_completion etc.) for login shells
if [ -f /etc/bash.bashrc ]; then
  . /etc/bash.bashrc
fi

# Source user .bashrc
if [ -f ~/.bashrc ]; then
  . ~/.bashrc
fi

# Display welcome message on SSH login (login shells only)
if [ -f ~/WELCOME.txt ]; then
  cat ~/WELCOME.txt
  echo ""
fi
BASHPROFILE
  chmod 644 ~/.bash_profile
elif ! grep -q "WELCOME.txt" ~/.bash_profile 2>/dev/null; then
  # Add welcome message to existing .bash_profile
  cat >> ~/.bash_profile << 'BASHPROFILE_WELCOME'
# Display welcome message on SSH login (login shells only)
if [ -f ~/WELCOME.txt ]; then
  cat ~/WELCOME.txt
  echo ""
fi
BASHPROFILE_WELCOME
fi
# Ensure /etc/bash.bashrc is sourced for bash_completion in login shells
if ! grep -q 'etc/bash.bashrc' ~/.bash_profile 2>/dev/null; then
  printf '\n# Source system-wide settings (bash_completion etc.) for login shells\nif [ -f /etc/bash.bashrc ]; then\n  . /etc/bash.bashrc\nfi\n' >> ~/.bash_profile
fi

# Ensure bash_completion is loaded for non-login interactive shells (e.g. VS Code terminal)
# Login shells get it via /etc/profile.d/bash_completion.sh; non-login shells need it in ~/.bashrc
if ! grep -q 'bash_completion' ~/.bashrc 2>/dev/null; then
  cat >> ~/.bashrc << 'BASHCOMP'
# Bash completion (for non-login interactive shells)
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
. /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
. /etc/bash_completion
  fi
fi
BASHCOMP
fi

# Set up npm global directory in home to persist packages
mkdir -p ~/.npm-global
npm config set prefix "~/.npm-global"
# Always export PATH for current session (required for non-interactive shells)
export PATH="$HOME/.npm-global/bin:$PATH"
if ! echo "$PATH" | grep -q "$HOME/.npm-global/bin"; then
  echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.bashrc
  echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.profile
  echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.bash_profile
fi

# Create symlink for task-master-ai in /usr/local/bin for system-wide access (if not already present)
if command -v sudo > /dev/null 2>&1 && sudo -n true 2>/dev/null; then
  if [ -f ~/.npm-global/bin/task-master-ai ] && [ ! -f /usr/local/bin/task-master-ai ]; then
    sudo ln -sf ~/.npm-global/bin/task-master-ai /usr/local/bin/task-master-ai 2>/dev/null || true
  fi
fi



  


echo "=== Setup Complete ==="
echo ""
echo "📁 Projects directory created at ~/projects"
echo "📄 Welcome message saved to ~/WELCOME.txt"
echo ""
echo "Next steps:"
echo "  1. Check out your project: cd ~/projects && git clone <repo-url> <project-name>"
echo "  2. Start ddev: cd <project-name> && ddev start"
echo "  3. Access your project via the exposed port (Auto-detected)"
echo ""
exit 0
