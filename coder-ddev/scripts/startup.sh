#!/bin/bash
# Coder workspace startup script for DDEV development environment
# Exit on error by default, with exception handling for non-critical operations
set -e

# Function for non-critical operations that should not halt execution
try() {
  "$@" || {
    echo "Warning: Command failed but continuing: $*"
    return 0
  }
}

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
    try chown coder:coder ~/WELCOME.txt
    echo "✓ Copied WELCOME.txt from /home/coder-files"
  fi
else
  echo "Warning: /home/coder-files not found in image"
fi


# Install Docker CLI (Required for DDEV DooD)
# Docker CLI is now pre-installed in the Docker image (v3.0.29+)
if ! command -v docker > /dev/null; then
  echo "Error: Docker CLI not found in image. Please update the workspace image."
  exit 1
fi

# Set locale env vars
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
if ! grep -q "LC_ALL=en_US.UTF-8" ~/.bashrc; then
  echo "export LANG=en_US.UTF-8" >> ~/.bashrc
  echo "export LC_ALL=en_US.UTF-8" >> ~/.bashrc
fi

# FIX: Remove stale GIT_SSH_COMMAND from .bashrc if present (from older versions)
try sed -i '/export GIT_SSH_COMMAND=/d' ~/.bashrc

# Enable bash completion (including git completion)
if [ -f /usr/share/bash-completion/bash_completion ]; then
  if ! grep -q "bash_completion" ~/.bashrc; then
    echo "" >> ~/.bashrc
    echo "# Enable bash completion" >> ~/.bashrc
    echo "if [ -f /usr/share/bash-completion/bash_completion ]; then" >> ~/.bashrc
    echo "  . /usr/share/bash-completion/bash_completion" >> ~/.bashrc
    echo "fi" >> ~/.bashrc
    echo "✓ Bash completion enabled (will be active in new shells)"
  fi
  # Source for current session
  . /usr/share/bash-completion/bash_completion 2>/dev/null || true
else
  echo "Note: bash-completion not installed in image"
fi

# Node.js, TypeScript, and DDEV are now pre-installed in the Docker image (v3.0.30+)


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
    exit 1
  fi

  # Verify Docker is functional
  echo "Verifying Docker daemon..."
  for i in $(seq 1 10); do
    if docker info > /dev/null 2>&1; then
      echo "✓ Docker daemon is healthy"
      break
    fi
    echo "Waiting for Docker to become ready..."
    sleep 2
  done

  if ! docker info > /dev/null 2>&1; then
    echo "ERROR: Docker daemon failed to start properly"
    echo "=== Docker daemon logs ==="
    cat /tmp/dockerd.log
    exit 1
  fi
else
  echo "Docker Daemon already running."
fi

# Create .ddev directory for ddev config
mkdir -p ~/.ddev

# Copy ddev configuration and commands from init-scripts after ddev installation
# This ensures ddev doesn't overwrite our custom configuration
if [ -d /home/coder-files/.ddev ]; then
  echo "Copying ddev configuration and commands from init-scripts..."

  # Copy global_config.yaml if it doesn't exist or overwrite to ensure latest version
  if [ -f /home/coder-files/.ddev/global_config.yaml ]; then
    cp -f /home/coder-files/.ddev/global_config.yaml ~/.ddev/global_config.yaml
    chmod 644 ~/.ddev/global_config.yaml
    echo "✓ ddev global_config.yaml copied"
  else
    echo "Warning: /home/coder-files/.ddev/global_config.yaml not found"
  fi
else
  echo "Warning: /home/coder-files/.ddev not found, skipping ddev config copy"
fi

# Verify DDEV installation
echo "Verifying DDEV installation..."
if ! ddev version > /dev/null 2>&1; then
  echo "ERROR: DDEV is not properly installed"
  exit 1
fi
echo "✓ DDEV version: $(ddev version | head -1)"

# Verify DDEV can communicate with Docker daemon
echo "Testing DDEV Docker connectivity..."
if ddev debug test > /dev/null 2>&1; then
  echo "✓ DDEV can communicate with Docker daemon"
else
  echo "Warning: DDEV debug test failed - some DDEV features may not work"
  echo "This is often normal on first startup. Try running: ddev debug test"
fi

# Create projects directory for Drupal projects
mkdir -p ~/projects


# Display welcome message
if [ -f ~/WELCOME.txt ]; then
  cat ~/WELCOME.txt
  echo ""
  echo "Welcome message saved to ~/WELCOME.txt"
fi

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

# Ensure ddev is in PATH
export PATH="$HOME/.ddev/bin:$PATH"
if ! echo "$PATH" | grep -q "$HOME/.ddev/bin"; then
  echo 'export PATH="$HOME/.ddev/bin:$PATH"' >> ~/.bashrc
fi

# Remove any old welcome message entries from .bashrc (if they exist)
# We use .bash_profile instead to avoid duplicates
if [ -f ~/.bashrc ]; then
  try sed -i '/WELCOME.txt/,/^fi$/d' ~/.bashrc
fi

# Add welcome message to .bash_profile for SSH login
# .bash_profile is executed only for login shells (SSH sessions)
if [ ! -f ~/.bash_profile ]; then
  # Create .bash_profile and source .bashrc for non-login shells
  cat > ~/.bash_profile << 'BASHPROFILE'
# Source .bashrc for non-login shells
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
    try sudo ln -sf ~/.npm-global/bin/task-master-ai /usr/local/bin/task-master-ai
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



# Explicitly exit with success to prevent "Unhealthy" status
echo "Startup script completed successfully"
exit 0
