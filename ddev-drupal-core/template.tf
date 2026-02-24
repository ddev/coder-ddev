terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = ">= 2.13"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
}
}

provider "docker" {
  host = var.docker_host

  # Registry authentication for GitLab Container Registry
  # Only configure if credentials are provided
  dynamic "registry_auth" {
    for_each = var.registry_username != "" && var.registry_password != "" ? [1] : []
    content {
      address  = "https://index.docker.io/v1/"
      username = var.registry_username
      password = var.registry_password
    }
  }
}




variable "docker_host" {
  description = "Docker host socket path"
  type        = string
  default     = "unix:///var/run/docker.sock"
}

variable "registry_username" {
  description = "Username for GitLab Container Registry authentication"
  type        = string
  default     = ""
  sensitive   = true
}

variable "registry_password" {
  description = "Password/Token for GitLab Container Registry authentication"
  type        = string
  default     = ""
  sensitive   = true
}

variable "image_version" {
  description = "The version of the Docker image to use"
  type        = string
  default     = "v0.1"
}

variable "docker_gid" {
  description = "Docker group GID (must match host Docker group for socket access)"
  type        = number
  default     = 988
}



# Workspace data source
data "coder_workspace" "me" {}

# Workspace owner data source (Coder v2+)
# Note: For Coder v0.12, this may not be available - will need fallback
data "coder_workspace_owner" "me" {}



# Extract repository name from Git URL for folder path

# Example: https://gitlab.example.com/group/my-project.git -> my-project
# Example: git@gitlab.example.com:group/my-project.git -> my-project
locals {
  # Determine workspace home path
  # Sysbox Strategy: Use standard /home/coder
  workspace_home = "/home/coder"
}

locals {
  # Read image version from VERSION file if it exists, otherwise use variable default
  image_version = try(trimspace(file("${path.module}/VERSION")), var.image_version)

  # Remove any tag (including :latest) if present, but preserve port numbers (e.g., :5050)
  # Remove common tags from the end of the registry URL
  # First remove the current version tag, then remove :latest
  # This handles cases where old configs might still have :latest or version tags
  # Note: We can't use regex, so we handle the most common cases
  registry_without_version      = replace(var.workspace_image_registry, ":${local.image_version}", "")
  workspace_image_registry_base = replace(local.registry_without_version, ":latest", "")
}

variable "workspace_image_registry" {
  description = "Docker registry URL for the workspace base image (without tag, version is added automatically)"
  type        = string
  # The version tag is appended automatically using the image_version variable or VERSION file
  # DO NOT include :latest or any version tag here - version comes from image_version variable
  # To use a specific version, override the image_version variable when deploying
  default = "index.docker.io/ddev/coder-ddev"
}



# Use pre-built image from Docker Hub
# The image is built and pushed using the Makefile (see root Makefile and VERSION file)
# This avoids prevent_destroy issues since the image is not managed by Terraform
resource "docker_image" "workspace_image" {
  # Always use version tag (never :latest) from the image_version variable or VERSION file
  # This ensures consistent image versions and prevents using stale images
  name = "${local.workspace_image_registry_base}:${local.image_version}"

  # Pull trigger based on version - image is pulled when version changes
  # Also include registry URL to force pull if registry changes
  # This ensures old workspaces get the new image when template is updated
  pull_triggers = [
    local.image_version,
    local.workspace_image_registry_base,
    "${local.workspace_image_registry_base}:${local.image_version}",
  ]

  # Keep image locally after pull
  keep_locally = true

  lifecycle {
    create_before_destroy = true
  }
}

# Note: Old image cleanup removed - we now use version tags exclusively
# Old images with :latest tag are no longer used and will be cleaned up automatically by Docker

variable "cpu" {
  description = "CPU cores"
  type        = number
  default     = 6
  validation {
    condition     = var.cpu >= 1 && var.cpu <= 32
    error_message = "CPU must be between 1 and 32"
  }
}

variable "memory" {
  description = "Memory in GB"
  type        = number
  default     = 12
  validation {
    condition     = var.memory >= 2 && var.memory <= 128
    error_message = "Memory must be between 2 and 128 GB"
  }
}










resource "coder_agent" "main" {
  arch = "amd64"
  os   = "linux"

  # Start terminal in the Drupal core directory
  # If the directory doesn't exist yet (first startup), agent will fall back gracefully
  dir = "/home/coder/drupal-core"

  startup_script = <<-EOT
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

      
      # Create Drupal-specific welcome message
      if [ ! -f ~/WELCOME.txt ]; then
        cat > ~/WELCOME.txt << 'WELCOME_EOF'
╔═══════════════════════════════════════════════════════════════╗
║          Welcome to Drupal Core Development                 ║
╚═══════════════════════════════════════════════════════════════╝

This workspace uses joachim-n/drupal-core-development-project
for a professional Drupal core development setup.

🌐 ACCESS YOUR SITE
   Click "DDEV Web" in the Coder dashboard
   Or run: ddev launch

🔐 ADMIN CREDENTIALS
   Username: admin
   Password: admin
   One-time link: ddev drush uli

📁 PROJECT STRUCTURE
   /home/coder/drupal-core       # Project root
   /home/coder/drupal-core/repos/drupal  # Drupal core git clone
   /home/coder/drupal-core/web   # Web docroot

🛠️  USEFUL COMMANDS
   ddev drush status         # Check Drupal status
   ddev drush uli            # Get admin login link
   ddev logs                 # View container logs
   ddev ssh                  # SSH into web container
   ddev describe             # Show project details
   ddev composer require ... # Add dependencies

📚 DOCUMENTATION
   DDEV: https://docs.ddev.com/
   Drupal: https://www.drupal.org/docs
   Drupal API: https://api.drupal.org/
   Project Template: https://github.com/joachim-n/drupal-core-development-project

📋 SETUP STATUS
   ~/SETUP_STATUS.txt        # Setup completion status
   /tmp/drupal-setup.log     # Detailed setup logs

💡 TROUBLESHOOTING
   If setup failed, check the status and log files above.
   You can manually run setup steps from the log.

Good luck with your Drupal core development!
WELCOME_EOF
        chown coder:coder ~/WELCOME.txt 2>/dev/null || true
        echo "✓ Created Drupal-specific welcome message"
      fi
    else
      echo "Warning: /home/coder-files not found in image"
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

    # ==========================================
    # DRUPAL CORE AUTOMATIC SETUP
    # ==========================================
    echo ""
    echo "=========================================="
    echo "Drupal Core Automatic Setup"
    echo "=========================================="

    DRUPAL_DIR="/home/coder/drupal-core"
    SETUP_LOG="/tmp/drupal-setup.log"
    SETUP_STATUS="$HOME/SETUP_STATUS.txt"

    # Initialize setup status file
    cat > "$SETUP_STATUS" << 'STATUS_HEADER'
Drupal Core Setup Status
=========================
STATUS_HEADER
    echo "Started: $(date)" >> "$SETUP_STATUS"
    echo "" >> "$SETUP_STATUS"

    # Function to log both to file and stdout
    log_setup() {
      echo "$1" | tee -a "$SETUP_LOG"
    }

    # Function to update status file
    update_status() {
      echo "$1" >> "$SETUP_STATUS"
    }

    # Ensure we're starting from home directory
    cd /home/coder || exit 1

    # Step 1: Create project directory and configure DDEV
    if [ ! -d "$DRUPAL_DIR" ]; then
      log_setup "Creating project directory: $DRUPAL_DIR"
      mkdir -p "$DRUPAL_DIR"
    fi
    
    cd "$DRUPAL_DIR" || exit 1

    # Step 2: Configure DDEV (must be done before composer create)
    if [ ! -f ".ddev/config.yaml" ]; then
      log_setup "Configuring DDEV for Drupal 12 with PHP 8.5 and docroot=web..."
      update_status "⏳ DDEV config: In progress..."

      if ddev config --project-type=drupal12 --php-version=8.5 --docroot=web --host-webserver-port=80 >> "$SETUP_LOG" 2>&1; then
        log_setup "✓ DDEV configured successfully with web/ as docroot"
        update_status "✓ DDEV config: Success"
      else
        log_setup "✗ Failed to configure DDEV"
        log_setup "Check $SETUP_LOG for details"
        update_status "✗ DDEV config: Failed"
        update_status ""
        update_status "Manual recovery:"
        update_status "  cd $DRUPAL_DIR"
        update_status "  ddev config --project-type=drupal12 --php-version=8.5 --docroot=web --host-webserver-port=80"
      fi

      # Configure DDEV global settings (omit router)
      log_setup "Configuring DDEV global settings..."
      update_status "⏳ DDEV global config: In progress..."

      if ddev config global --omit-containers=ddev-router >> "$SETUP_LOG" 2>&1; then
        log_setup "✓ DDEV global config applied (router omitted)"
        update_status "✓ DDEV global config: Success"
      else
        log_setup "⚠ Warning: Failed to set DDEV global config (non-critical)"
        update_status "⚠ DDEV global config: Warning (non-critical)"
      fi
    else
      log_setup "✓ DDEV already configured"
      update_status "✓ DDEV config: Already present"
    fi

    # Step 3: Start DDEV
    if ddev describe 2>/dev/null | grep -q "OK"; then
      log_setup "✓ DDEV already running"
      update_status "✓ DDEV start: Already running"
    else
      log_setup "Starting DDEV environment (this will take 2-3 minutes)..."
      update_status "⏳ DDEV start: In progress..."

      if ddev start >> "$SETUP_LOG" 2>&1; then
        log_setup "✓ DDEV started successfully"
        update_status "✓ DDEV start: Success"
      else
        log_setup "✗ Failed to start DDEV"
        log_setup "Check $SETUP_LOG and Docker logs for details"
        update_status "✗ DDEV start: Failed"
        update_status ""
        update_status "Manual recovery:"
        update_status "  cd $DRUPAL_DIR && ddev start"
        update_status "  Check: docker ps, docker logs"
      fi
    fi

    # Step 4: Set up Drupal core development project with ddev composer create
    if [ -f "composer.json" ] && [ -d "repos/drupal/.git" ]; then
      log_setup "✓ Drupal core development project already set up"
      update_status "✓ DDEV composer create: Already present"
    else
      log_setup "Setting up Drupal core development project with DDEV Composer..."
      log_setup "This creates a proper dev environment with:"
      log_setup "  - Drupal core git clone at repos/drupal/"
      log_setup "  - Web root at web/"
      log_setup "  - Composer dependency management"
      update_status "⏳ DDEV composer create: In progress (this takes 3-5 minutes)..."

      if ddev composer create joachim-n/drupal-core-development-project --no-interaction >> "$SETUP_LOG" 2>&1; then
        log_setup "✓ Drupal core development project created successfully"
        update_status "✓ DDEV composer create: Success"
      else
        log_setup "✗ Failed to create Drupal core development project"
        log_setup "Check $SETUP_LOG for details"
        update_status "✗ DDEV composer create: Failed"
        update_status ""
        update_status "Manual recovery:"
        update_status "  cd $DRUPAL_DIR && ddev composer create joachim-n/drupal-core-development-project"
      fi
    fi

    # Only proceed if project was created successfully
    if [ -f "composer.json" ] && [ -d "repos/drupal" ]; then
      # Step 5: Ensure Drush in composer require (not just require-dev)
      # Step 5: Ensure Drush in composer require (not just require-dev)
      log_setup "Ensuring Drush is in composer require section..."
      update_status "⏳ Drush install: In progress..."

      if ddev composer require drush/drush >> "$SETUP_LOG" 2>&1; then
        log_setup "✓ Drush configured successfully"
        update_status "✓ Drush install: Success"
      else
        log_setup "⚠ Warning: Failed to configure Drush"
        update_status "⚠ Drush install: Warning"
      fi

      # Step 6: Install Drupal (if not already installed)
      if ddev drush status 2>/dev/null | grep -q "Drupal bootstrap.*Successful"; then
        log_setup "✓ Drupal already installed"
        update_status "✓ Drupal install: Already present"
      else
        log_setup "Installing Drupal with demo_umami profile (this will take 2-3 minutes)..."
        update_status "⏳ Drupal install: In progress..."

        if ddev drush si -y demo_umami --account-pass=admin >> "$SETUP_LOG" 2>&1; then
          log_setup "✓ Drupal installed successfully!"
          log_setup ""
          log_setup "   🔐 Admin Credentials:"
          log_setup "      Username: admin"
          log_setup "      Password: admin"
          log_setup ""
          update_status "✓ Drupal install: Success"
        else
          log_setup "✗ Failed to install Drupal"
          log_setup "Check $SETUP_LOG for details"
          update_status "✗ Drupal install: Failed"
          update_status ""
          update_status "Manual recovery:"
          update_status "  cd $DRUPAL_DIR"
          update_status "  ddev drush si -y demo_umami --account-pass=admin"
        fi
      fi

      # Step 7: Install custom DDEV launch command
      mkdir -p ~/.ddev/commands/host
      cat > ~/.ddev/commands/host/launch << 'LAUNCH_EOF'
#!/usr/bin/env bash

## Description: Launch a browser with the current site
## Usage: launch
## Example: "ddev launch"

# Get the primary port (should be 80)
PRIMARY_PORT=$(ddev describe -j 2>/dev/null | grep -o '"router_http_port":"[^"]*"' | cut -d'"' -f4)
if [ -z "$PRIMARY_PORT" ]; then
  PRIMARY_PORT="80"
fi

# In Coder environment, show access information
if [ -n "$CODER_WORKSPACE_NAME" ]; then
  echo ""
  echo "╔═══════════════════════════════════════════════════╗"
  echo "║     Your Drupal Site is Running!                ║"
  echo "╚═══════════════════════════════════════════════════╝"
  echo ""

  # Construct the Coder app proxy URL
  # Coder apps with subdomain=true create URLs like: https://<port>--<workspace>--<owner>.<coder-domain>
  # Extract Coder base domain from VSCODE_PROXY_URI if available
  CODER_DOMAIN=""
  if [ -n "$VSCODE_PROXY_URI" ]; then
    # Extract domain from VS Code proxy URI (format: https://something--something--something.domain.com)
    CODER_DOMAIN=$(echo "$VSCODE_PROXY_URI" | sed -E 's|https?://[^.]+\.(.+?)(/.*)?$|\1|')
  fi

  if [ -n "$CODER_DOMAIN" ] && [ -n "$CODER_WORKSPACE_OWNER_NAME" ]; then
    # Construct the URL using Coder's subdomain pattern
    APP_URL="https://$${PRIMARY_PORT}--$${CODER_WORKSPACE_NAME}--$${CODER_WORKSPACE_OWNER_NAME}.$${CODER_DOMAIN}"
    echo "🌐 Your Drupal Site:"
    echo "   $${APP_URL}"
    echo ""
  else
    echo "🌐 Access Your Site:"
    echo "   Click the 'DDEV Web' app button in your workspace"
    echo ""
  fi

  echo "🔐 Admin Login:"
  echo "   Username: admin"
  echo "   Password: admin"
  echo ""
  echo "✨ Quick Commands:"
  echo "   ddev drush uli          # Get one-time login link"
  echo "   ddev drush status       # Check Drupal status"
  echo "   ddev logs               # View container logs"
  echo ""
else
  # Outside Coder, use standard browser launch
  xdg-open "http://localhost:$${PRIMARY_PORT}" 2>/dev/null || \
  open "http://localhost:$${PRIMARY_PORT}" 2>/dev/null || \
  echo "Open http://localhost:$${PRIMARY_PORT} in your browser"
fi
LAUNCH_EOF

      chmod +x ~/.ddev/commands/host/launch
      log_setup "✓ Custom DDEV launch command installed"
      update_status "✓ DDEV launch command: Installed"

    fi # End of "if project creation succeeded"

    # Final status and summary
    update_status ""
    update_status "Completed: $(date)"
    update_status ""
    update_status "View full logs: $SETUP_LOG"

    log_setup ""
    log_setup "=========================================="
    log_setup "✨ Setup Complete!"
    log_setup "=========================================="
    log_setup ""
    log_setup "📁 Project Location:"
    log_setup "   $DRUPAL_DIR"
    log_setup ""
    log_setup "🌐 Access Your Site:"
    log_setup "   - Click 'DDEV Web' in Coder dashboard"
    log_setup "   - Or run: ddev launch"
    log_setup ""
    log_setup "🔐 Admin Credentials:"
    log_setup "   Username: admin"
    log_setup "   Password: admin"
    log_setup ""
    log_setup "🛠️  Useful Commands:"
    log_setup "   ddev drush uli          # One-time login link"
    log_setup "   ddev drush status       # Check Drupal status"
    log_setup "   ddev logs               # View logs"
    log_setup "   ddev ssh                # SSH into container"
    log_setup ""
    log_setup "📋 Setup Details:"
    log_setup "   Status: $SETUP_STATUS"
    log_setup "   Logs:   $SETUP_LOG"
    log_setup ""

    # Create projects directory for additional projects if needed
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
        sudo ln -sf ~/.npm-global/bin/task-master-ai /usr/local/bin/task-master-ai 2>/dev/null || true
      fi
    fi
    


  
    
    
    echo "=== Setup Complete ==="
    echo ""
    echo "📁 Drupal core ready at ~/drupal-core"
    echo "📄 Welcome message saved to ~/WELCOME.txt"
    echo ""
    echo "Next steps:"
    echo "  1. Click 'DDEV Web' app to access your site"
    echo "  2. Log in with admin/admin"
    echo "  3. Run 'ddev drush uli' for one-time login link"
    echo ""
    
    
    
    # Explicitly exit with success to prevent "Unhealthy" status
    exit 0
  EOT

  env = {
    CODER_AGENT_FORCE_UPDATE = "35"
    # DOCKER_HOST not needed as we use local socket
    # DOCKER_HOST                = var.docker_host
    CODER_WORKSPACE_ID         = data.coder_workspace.me.id
    CODER_WORKSPACE_NAME       = data.coder_workspace.me.name
    CODER_WORKSPACE_OWNER_NAME = data.coder_workspace_owner.me.name
    # Force HOME to /home/coder (Standard Home Strategy)
    HOME = "/home/coder"
  }

  metadata {
    display_name = "Coder DDEV Base"
    key          = "0"
    script       = "coder stat"
    interval     = 1
    timeout      = 1
  }
}

resource "docker_volume" "coder_dind_cache" {
  name = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}-dind-cache"
}

# VS Code for Web
module "vscode-web" {
  count          = data.coder_workspace.me.start_count
  source         = "registry.coder.com/coder/vscode-web/coder"
  version        = "~> 1.0"
  agent_id       = coder_agent.main.id
  folder         = "/home/coder/drupal-core"
  accept_license = true
}

# DDEV Web Server (HTTP) - appears when DDEV project is running
# Uses subdomain routing for unique URLs per workspace
resource "coder_app" "ddev-web" {
  agent_id     = coder_agent.main.id
  slug         = "ddev-web"
  display_name = "DDEV Web"
  url          = "http://localhost:80"
  icon         = "/icon/globe.svg"
  subdomain    = true
  share        = "owner"

  healthcheck {
    url       = "http://localhost:80"
    interval  = 10
    threshold = 30
  }
}

# Note: JetBrains IDEs (PhpStorm, GoLand, WebStorm, etc.) are supported via JetBrains Gateway
# Users should install JetBrains Gateway locally and use the Coder plugin to connect
# No explicit app definitions needed - coder-login module enables Gateway support

# Graceful DDEV shutdown when workspace stops
resource "coder_script" "ddev_shutdown" {
  agent_id     = coder_agent.main.id
  display_name = "Stop DDEV Projects"
  icon         = "/icon/docker.svg"
  run_on_stop  = true
  script       = <<-EOT
    #!/bin/bash
    # Ensure ddev is in PATH (installed via Homebrew)
    export PATH="$PATH:/home/linuxbrew/.linuxbrew/bin:/usr/local/bin"
    echo "Stopping all DDEV projects gracefully..."
    if command -v ddev > /dev/null 2>&1; then
      ddev poweroff || true
      echo "DDEV projects stopped"
    else
      echo "ddev not found in PATH, trying direct path..."
      /home/linuxbrew/.linuxbrew/bin/ddev poweroff 2>/dev/null || true
    fi
  EOT
}

module "coder-login" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/coder-login/coder"
  version  = "~> 1.0"
  agent_id = coder_agent.main.id
}






resource "docker_container" "workspace" {
  count = data.coder_workspace.me.start_count
  image = docker_image.workspace_image.image_id
  name  = "coder-${data.coder_workspace.me.id}"
  user  = "coder"
  # Add docker group so coder user can access Docker socket
  # GID must match host Docker group (default 988, configurable via docker_gid variable)
  group_add = [tostring(var.docker_gid)]

  # Increase stop_timeout to allow shutdown_script and ddev stop to run
  # Default is usually 10s, which is not enough for ddev shutdown
  stop_timeout = 180
  stop_signal  = "SIGTERM"

  # Direct Mount Strategy: Set Working Directory to path matching Host
  working_dir = local.workspace_home

  # CPU and memory limits
  cpu_shares = var.cpu * 1024
  memory     = var.memory * 1024 * 1024 * 1024

  # Use Sysbox runtime for nested Docker support
  runtime = "sysbox-runc"

  # Mount workspace volume
  # Host Path: /home/coder/workspaces/<owner>-<workspace>
  # This ensures isolation between workspaces while allows persistent storage
  volumes {
    container_path = local.workspace_home
    host_path      = "/home/coder/workspaces/${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}"
    read_only      = false
  }

  # Docker socket is NOT mounted - we use internal Docker Daemon (Sysbox)
  # volumes {
  #   host_path      = "/var/run/docker.sock"
  #   container_path = "/var/run/docker.sock"
  # }

  mounts {
    type   = "volume"
    source = docker_volume.coder_dind_cache.name
    target = "/var/lib/docker"
  }

  # Environment variables
  env = [
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
    # DOCKER_HOST not needed as we use local socket
    # "DOCKER_HOST=${var.docker_host}", 
    "CODER_WORKSPACE_NAME=${data.coder_workspace.me.name}",

    "ELECTRON_DISABLE_SANDBOX=1",
    "ELECTRON_NO_SANDBOX=1",
  ]

  # Command to keep container running
  command = ["sh", "-c", coder_agent.main.init_script]

  # Ensure container is destroyed (stopped) BEFORE workspace_cleanup runs (rm -rf) through reverse dependency



  # Restart policy
  restart = "unless-stopped"

  # Security options for Docker-in-Docker
  security_opts = [
    "apparmor:unconfined",
    "seccomp:unconfined"
  ]

  # Privileged mode not needed for Sysbox
  privileged = false
}

# Cleanup ddev resources when workspace is destroyed
# NOTE: Destroy provisioner temporarily disabled due to Terraform limitations
# TODO: Implement cleanup via alternative method (e.g., Coder lifecycle hooks or external script)

resource "coder_metadata" "workspace_info" {
  resource_id = docker_container.workspace[0].id
  count       = data.coder_workspace.me.start_count

  item {
    key   = "template"
    value = "Drupal Core Development"
  }
  item {
    key   = "drupal_location"
    value = "/home/coder/drupal-core"
  }
  item {
    key   = "drupal_profile"
    value = "demo_umami"
  }
  item {
    key   = "admin_credentials"
    value = "admin / admin"
  }
  item {
    key   = "image"
    value = "${docker_image.workspace_image.name} (version: ${local.image_version})"
  }
  item {
    key   = "php_version"
    value = "8.5"
  }
  item {
    key   = "cpu"
    value = "${var.cpu} vCPU (soft limit)"
  }
  item {
    key   = "memory"
    value = "${var.memory} GB"
  }
  item {
    key   = "setup_logs"
    value = "/tmp/drupal-setup.log"
  }
  item {
    key   = "setup_status"
    value = "~/SETUP_STATUS.txt"
  }

}

# Output for Vault integration status (visible in Terraform logs)



