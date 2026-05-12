#!/usr/bin/env bash
# scripts/templates/freeform/startup.sh
# Workspace startup script for the freeform template.
#
# Required env vars (set on coder_agent.env in freeform/template.tf):
#   REGISTRY_MIRROR  - Docker registry mirror URL (from var.docker_registry_mirror).
#                      May be empty; startup auto-detects http://<coder-host>:5000 if reachable.
#
# Exit codes:
#   0   - workspace ready
#   1   - generic failure
#
# Idempotency: yes — safe to re-run on workspace restart.

set -euo pipefail

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

echo "Startup script started..."

if command -v sudo > /dev/null 2>&1; then
  SUDO="sudo"
else
  SUDO=""
fi

sudo chown coder:coder /home/coder

if [ ! -f "/home/coder/.bashrc" ]; then
    echo "Initializing home directory..."
    cp -rT /etc/skel/. /home/coder/
fi

cd /home/coder

echo "=========================================="
echo "Starting workspace setup..."
echo "=========================================="
echo "Workspace: $CODER_WORKSPACE_NAME  Owner: $CODER_WORKSPACE_OWNER_NAME"

# Coder GitSSH wrapper
if [ -z "${GIT_SSH_COMMAND:-}" ]; then
  CODER_GITSSH=$(find /tmp -name "coder" -path "*/coder.*/*" -type f -executable 2>/dev/null | head -1)
  if [ -n "$CODER_GITSSH" ]; then
    export GIT_SSH_COMMAND="$CODER_GITSSH gitssh"
    echo "✓ Coder GitSSH wrapper configured"
  fi
fi

# Copy files from /home/coder-files
if [ -d /home/coder-files ]; then
  if [ ! -f ~/WELCOME.txt ] && [ -f /home/coder-files/WELCOME.txt ]; then
    cp /home/coder-files/WELCOME.txt ~/WELCOME.txt
    chown coder:coder ~/WELCOME.txt 2>/dev/null || true
  fi
  if [ -d /home/coder-files/.vscode ]; then
    mkdir -p ~/.vscode
    if [ -f /home/coder-files/.vscode/settings.json ]; then
      cp /home/coder-files/.vscode/settings.json ~/.vscode/settings.json
      chown coder:coder ~/.vscode/settings.json 2>/dev/null || true
    fi
  fi
fi

# Git configuration: copy defaults on first run, set identity from Coder owner
if [ ! -f "$HOME/.gitconfig" ] && [ -f /home/coder-files/.gitconfig ]; then
  cp /home/coder-files/.gitconfig "$HOME/.gitconfig"
fi
if [ ! -f "$HOME/.gitignore_global" ] && [ -f /home/coder-files/.gitignore_global ]; then
  cp /home/coder-files/.gitignore_global "$HOME/.gitignore_global"
elif [ -f "$HOME/.gitignore_global" ]; then
  grep -qxF 'config.coder.yaml' "$HOME/.gitignore_global" || \
    echo 'config.coder.yaml' >> "$HOME/.gitignore_global"
fi
mkdir -p ~/.ddev
if [ -n "${CODER_WORKSPACE_OWNER_NAME:-}" ]; then
  git config --global user.name "$CODER_WORKSPACE_OWNER_NAME"
fi
if [ -n "${CODER_WORKSPACE_OWNER_EMAIL:-}" ]; then
  git config --global user.email "$CODER_WORKSPACE_OWNER_EMAIL"
fi

# Locale
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
if ! grep -q "LC_ALL=en_US.UTF-8" ~/.bashrc; then
  echo "export LANG=en_US.UTF-8" >> ~/.bashrc
  echo "export LC_ALL=en_US.UTF-8" >> ~/.bashrc
fi
sed -i '/export GIT_SSH_COMMAND=/d' ~/.bashrc || true

# Persist Coder-provided variables to ~/.bashrc so they are available in
# DDEV post-start hooks and interactive shells (DDEV exec-host inherits the
# shell environment, which sources ~/.bashrc for login shells).
# Use printenv to avoid ${!var} indirect expansion which Terraform parses.
for _var in CODER_AGENT_URL VSCODE_PROXY_URI CODER_WORKSPACE_NAME CODER_WORKSPACE_OWNER_NAME CODER_WORKSPACE_OWNER_EMAIL CODER_PROJECT_NAMES; do
  _val=$(printenv "$_var" 2>/dev/null || true)
  if [ -n "$_val" ]; then
    sed -i "/^export $_var=/d" ~/.bashrc || true
    echo "export $_var=$_val" >> ~/.bashrc
  fi
done

# Configure Docker daemon registry mirror.
# Priority: explicit Terraform variable, then auto-detect on Coder host:5000 if reachable.
# REGISTRY_MIRROR is injected by Terraform via coder_agent.env
REGISTRY_MIRROR="${REGISTRY_MIRROR:-}"
if [ -z "$REGISTRY_MIRROR" ] && [ -n "${CODER_AGENT_URL:-}" ]; then
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
if ! pgrep -x "dockerd" > /dev/null; then
  echo "Starting Docker Daemon..."
  sudo dockerd > /tmp/dockerd.log 2>&1 &
  echo "Waiting for Docker socket..."
  for i in $(seq 1 30); do
    if [ -S /var/run/docker.sock ]; then
      echo "Docker socket ready"
      break
    fi
    sleep 1
  done
  if [ -S /var/run/docker.sock ]; then
    sudo chmod 666 /var/run/docker.sock
  else
    echo "Error: Docker socket not found after 30s"
  fi
else
  echo "Docker Daemon already running."
fi

# Configure DDEV global settings now that Docker is up (ddev config global needs Docker)
ddev config global --instrumentation-opt-in=true > /dev/null 2>&1 || true
ddev config global --router-http-port=8080 > /dev/null 2>&1 || true

# Create .ddev commands directory
mkdir -p ~/.ddev/commands/host
if [ -d /home/coder-files/.ddev/commands/host ]; then
  cp -f /home/coder-files/.ddev/commands/host/* ~/.ddev/commands/host/ || true
  chmod 755 ~/.ddev/commands/host/* || true
  echo "✓ DDEV host commands installed"
fi

# Pre-pull DDEV images (uses registry mirror if configured)
ddev utility download-images || true

# Ensure yq and linuxbrew are in PATH for this session
export PATH="$PATH:/home/linuxbrew/.linuxbrew/bin"

# Display welcome message
if [ -f ~/WELCOME.txt ]; then
  cat ~/WELCOME.txt
fi

# Homebrew in PATH for interactive shells
if ! grep -q "/home/linuxbrew/.linuxbrew/bin" ~/.bashrc; then
  echo 'export PATH="$PATH:/home/linuxbrew/.linuxbrew/bin"' >> ~/.bashrc
fi

# bash_profile for SSH logins
if [ ! -f ~/.bash_profile ]; then
  cat > ~/.bash_profile << 'BASHPROFILE'
# Source system-wide settings (bash_completion etc.) for login shells
if [ -f /etc/bash.bashrc ]; then
  . /etc/bash.bashrc
fi
if [ -f ~/.bashrc ]; then
  . ~/.bashrc
fi
if [ -f ~/WELCOME.txt ]; then
  cat ~/WELCOME.txt
  echo ""
fi
BASHPROFILE
  chmod 644 ~/.bash_profile
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

# npm global directory
mkdir -p ~/.npm-global
npm config set prefix "~/.npm-global" || true
export PATH="$HOME/.npm-global/bin:$PATH"
if ! grep -q "\.npm-global/bin" ~/.bashrc; then
  echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.bashrc
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Registered DDEV project name(s): $CODER_PROJECT_NAMES"
echo ""
echo "Next steps (repeat for each project name above):"
echo "  1. Clone or create your project directory:"
echo "       git clone <repo-url> <project-name>"
echo "       cd <project-name>"
echo "  2. Configure DDEV — project name MUST match a registered name:"
echo "       ddev config --project-name=<project-name> --project-type=<type>"
echo "  3. Install Coder routing hook (once per project):"
echo "       ddev coder-setup"
echo "  4. Start DDEV:"
echo "       ddev start"
echo ""
exit 0
