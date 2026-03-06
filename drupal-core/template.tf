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

variable "cache_path" {
  description = "Host path to the drupal-core seed cache directory (mounted read-only into workspaces)"
  type        = string
  default     = "/home/rfay/cache/drupal-core-seed"
}

# Per-workspace user parameters (shown in workspace creation UI, pre-fillable via ?param.name=value URL)
data "coder_parameter" "issue_fork" {
  name         = "issue_fork"
  display_name = "Issue Fork"
  description  = "Drupal.org issue fork name (e.g., drupal-3568144). Leave empty for standard Drupal core development."
  type         = "string"
  default      = ""
  mutable      = true
  order        = 1
}

data "coder_parameter" "issue_branch" {
  name         = "issue_branch"
  display_name = "Issue Branch"
  description  = "Issue branch to check out (e.g., 3568144-editorfilterxss-11.x). Leave empty for HEAD."
  type         = "string"
  default      = ""
  mutable      = true
  order        = 2
}

data "coder_parameter" "drupal_version" {
  name         = "drupal_version"
  display_name = "Drupal Version"
  description  = "Major Drupal version — sets DDEV project type. Match the version of the issue you are working on."
  type         = "string"
  default      = "12"
  mutable      = true
  order        = 4
  option {
    name  = "12.x (HEAD / upcoming)"
    value = "12"
  }
  option {
    name  = "11.x (stable)"
    value = "11"
  }
  option {
    name  = "10.x (stable)"
    value = "10"
  }
}

data "coder_parameter" "install_profile" {
  name         = "install_profile"
  display_name = "Install Profile"
  description  = "Drupal install profile. demo_umami uses a pre-built database snapshot; other profiles run a full site install. Issue fork workspaces always run a full install."
  type         = "string"
  default      = "demo_umami"
  mutable      = true
  order        = 3
  option {
    name  = "demo_umami"
    value = "demo_umami"
  }
  option {
    name  = "minimal"
    value = "minimal"
  }
  option {
    name  = "standard"
    value = "standard"
  }
}



# Workspace data source
data "coder_workspace" "me" {}

# Workspace owner data source (Coder v2+)
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
  default     = 8
  validation {
    condition     = var.memory >= 2 && var.memory <= 128
    error_message = "Memory must be between 2 and 128 GB"
  }
}










resource "coder_agent" "main" {
  arch = "amd64"
  os   = "linux"

  shutdown_script = <<EOT
    echo "Stopping DDEV"
    ddev poweroff || true
  EOT

  # Start terminal in the Drupal core directory
  # If the directory doesn't exist yet (first startup), agent will fall back gracefully
  dir = "/home/coder/drupal-core"

  startup_script = <<-EOT
    #!/bin/bash
    # Don't exit on error - let installation continue even if some steps fail
    set +e

    echo "Startup script started..."
    SCRIPT_START=$SECONDS

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
   Quickstart: https://github.com/ddev/coder-ddev/blob/main/docs/user/quickstart.md
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

    # Create .ddev directory for ddev config (DDEV creates global_config.yaml on first use)
    mkdir -p ~/.ddev

    # Always omit ddev-router — this template uses direct port binding, not the router.
    # Must run every startup because the shared global_config.yaml defaults to omit_containers: []
    echo "Configuring DDEV to omit ddev-router..."
    ddev config global --omit-containers=ddev-router --instrumentation-opt-in=false > /dev/null 2>&1 || true

    # Install mkcert CA to suppress DDEV's "mkcert may not be properly installed" warning
    # DDEV ships its own mkcert binary; this sets up the local CA trust
    mkcert -install 2>/dev/null || true

    # Pre-pull DDEV images (uses registry mirror if configured)
    _t_images=$SECONDS
    echo "Pre-pulling DDEV images..."
    ddev utility download-images || true
    IMAGES_TIME=$((SECONDS - _t_images))
    echo "  ddev utility download-images complete ($${IMAGES_TIME}s)"

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
    # Derive project type from the Drupal major version parameter (let DDEV pick default PHP version)
    DRUPAL_VERSION="${data.coder_parameter.drupal_version.value}"
    case "$DRUPAL_VERSION" in
      10) DDEV_PROJECT_TYPE="drupal10" ;;
      11) DDEV_PROJECT_TYPE="drupal11" ;;
      *)  DDEV_PROJECT_TYPE="drupal12" ;;
    esac

    # Always regenerate .ddev/config.yaml from scratch so DDEV picks its own defaults
    # for the project type (e.g. correct PHP version). Preserving an old config.yaml
    # would leave stale fields like php_version untouched even when project-type changes.
    rm -f .ddev/config.yaml
    log_setup "Configuring DDEV for Drupal $DRUPAL_VERSION ($DDEV_PROJECT_TYPE)..."
    update_status "⏳ DDEV config: In progress..."

    if ddev config --project-type="$DDEV_PROJECT_TYPE" --docroot=web --host-webserver-port=80 >> "$SETUP_LOG" 2>&1; then
      log_setup "✓ DDEV configured (project-type=$DDEV_PROJECT_TYPE docroot=web)"
      update_status "✓ DDEV config: Success"
    else
      log_setup "✗ Failed to configure DDEV"
      log_setup "Check $SETUP_LOG for details"
      update_status "✗ DDEV config: Failed"
      update_status ""
      update_status "Manual recovery:"
      update_status "  cd $DRUPAL_DIR"
      update_status "  ddev config --project-type=$DDEV_PROJECT_TYPE --docroot=web --host-webserver-port=80"
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

    # Step 3: Start DDEV
    # poweroff first — ddev-router can persist in Docker's state across workspace
    # stop/start; `ddev stop` only stops project containers, not ddev-router.
    ddev poweroff 2>&1 | tee -a "$SETUP_LOG" || true

    log_setup "Starting DDEV environment..."
    update_status "⏳ DDEV start: In progress..."

    ddev start 2>&1 | tee -a "$SETUP_LOG"
    DDEV_START_RC=$${PIPESTATUS[0]}
    if [ $DDEV_START_RC -eq 0 ]; then
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

    CACHE_SEED="/home/coder-cache-seed"
    DRUPAL_SETUP_NEEDED=false
    ISSUE_FORK_CHECKOUT_DONE=false
    SETUP_START=$SECONDS

    # Diagnostic: report what the cache mount contains
    log_setup "Cache mount check: $CACHE_SEED"
    if [ -f "$CACHE_SEED/composer.json" ]; then
      log_setup "  composer.json: present"
    else
      log_setup "  composer.json: MISSING (cache not seeded or bind mount empty)"
    fi
    if [ -d "$CACHE_SEED/repos/drupal/.git" ]; then
      log_setup "  repos/drupal/.git: present"
    else
      log_setup "  repos/drupal/.git: MISSING"
    fi
    if [ -f "$CACHE_SEED/.tarballs/db.sql.gz" ]; then
      log_setup "  .tarballs/db.sql.gz: present ($(du -sh $CACHE_SEED/.tarballs/db.sql.gz 2>/dev/null | cut -f1))"
    else
      log_setup "  .tarballs/db.sql.gz: MISSING"
    fi

    # Issue fork / install profile parameters (baked in at template evaluation)
    ISSUE_FORK="${data.coder_parameter.issue_fork.value}"
    ISSUE_BRANCH="${data.coder_parameter.issue_branch.value}"
    INSTALL_PROFILE="${data.coder_parameter.install_profile.value}"
    USING_ISSUE_FORK=false
    if [ -n "$ISSUE_FORK" ] || [ -n "$ISSUE_BRANCH" ]; then
      USING_ISSUE_FORK=true
      log_setup "Issue fork mode: ISSUE_FORK=$ISSUE_FORK  ISSUE_BRANCH=$ISSUE_BRANCH  INSTALL_PROFILE=$INSTALL_PROFILE"
    fi

    # Step 4: Set up Drupal core project — use seed cache when available (fast path)
    # Issue forks skip the cache: the seed composer.json requires "drupal/core: dev-main" and
    # vendor is resolved for PHP 8.5/drupal12, both incompatible with non-main issue branches.
    if [ -f "composer.json" ] && [ -d "repos/drupal/.git" ]; then
      log_setup "✓ Drupal core project already present — skipping setup"
      update_status "✓ Setup: Already present"
    elif [ "$USING_ISSUE_FORK" = "false" ] && [ -f "$CACHE_SEED/composer.json" ] && [ -d "$CACHE_SEED/repos/drupal/.git" ]; then
      _t=$SECONDS
      log_setup "Cache hit: seeding project from host cache (fast path)..."
      update_status "⏳ DDEV setup: Seeding from cache..."
      # Copy everything except .ddev/ — workspace generates its own DDEV config
      if rsync -a --exclude='.ddev/' --exclude='.tarballs/' "$CACHE_SEED/" "$DRUPAL_DIR/" >> "$SETUP_LOG" 2>&1; then
        log_setup "  rsync complete ($((SECONDS - _t))s)"
        # Bring git checkout up to date (fast — objects already present locally)
        _t=$SECONDS
        git -C "$DRUPAL_DIR/repos/drupal" fetch --all --prune >> "$SETUP_LOG" 2>&1 || true
        log_setup "  git fetch complete ($((SECONDS - _t))s)"
        # Sync vendor with the (unchanged main-branch) lock file
        _t=$SECONDS
        ddev composer install >> "$SETUP_LOG" 2>&1
        log_setup "  composer install complete ($((SECONDS - _t))s)"
        log_setup "✓ Cache seed complete ($((SECONDS - SETUP_START))s total so far)"
        update_status "✓ DDEV composer create: Seeded from cache"
        DRUPAL_SETUP_NEEDED=true
      else
        log_setup "✗ Failed to seed from cache ($((SECONDS - _t))s), falling back to full setup..."
        update_status "⚠ Cache seed failed, running full setup..."
        ddev composer create joachim-n/drupal-core-development-project --no-interaction >> "$SETUP_LOG" 2>&1
        DRUPAL_SETUP_NEEDED=true
      fi
    else
      _t=$SECONDS
      if [ "$USING_ISSUE_FORK" = "true" ]; then
        # Issue fork: create project structure WITHOUT installing dependencies.
        # We must checkout the issue branch before composer install so that vendor
        # is resolved for the correct branch, not for main/drupal12.
        log_setup "Issue fork: creating project structure (dependencies installed after branch checkout)..."
        update_status "⏳ DDEV composer create-project: In progress..."
        if ddev composer create-project --no-install --no-interaction joachim-n/drupal-core-development-project . >> "$SETUP_LOG" 2>&1; then
          log_setup "✓ Project structure created ($((SECONDS - _t))s)"
          update_status "✓ DDEV composer create-project: Success"
          DRUPAL_SETUP_NEEDED=true
          # Supplement git objects from seed cache so issue-branch fetch only downloads the delta
          if [ -d "$CACHE_SEED/repos/drupal/.git/objects" ]; then
            log_setup "Supplementing git objects from seed cache..."
            rsync -a "$CACHE_SEED/repos/drupal/.git/objects/" "$DRUPAL_DIR/repos/drupal/.git/objects/" >> "$SETUP_LOG" 2>&1 || true
            log_setup "  git objects supplement complete"
          fi
        else
          log_setup "✗ Failed to create project structure ($((SECONDS - _t))s)"
          log_setup "Check $SETUP_LOG for details"
          update_status "✗ DDEV composer create-project: Failed"
          update_status ""
          update_status "Manual recovery:"
          update_status "  cd $DRUPAL_DIR && ddev composer create-project --no-install joachim-n/drupal-core-development-project ."
        fi
      else
        log_setup "No cache available, running full composer create (this takes 5-10 minutes)..."
        update_status "⏳ DDEV composer create: In progress (this takes 5-10 minutes)..."
        if ddev composer create joachim-n/drupal-core-development-project --no-interaction >> "$SETUP_LOG" 2>&1; then
          log_setup "✓ Drupal core development project created ($((SECONDS - _t))s)"
          update_status "✓ DDEV composer create: Success"
          DRUPAL_SETUP_NEEDED=true
        else
          log_setup "✗ Failed to create Drupal core development project ($((SECONDS - _t))s)"
          log_setup "Check $SETUP_LOG for details"
          update_status "✗ DDEV composer create: Failed"
          update_status ""
          update_status "Manual recovery:"
          update_status "  cd $DRUPAL_DIR && ddev composer create joachim-n/drupal-core-development-project"
        fi
      fi
    fi

    # Steps 5-7: run whenever project files are present — inner checks handle idempotency
    if [ -f "composer.json" ] && [ -d "repos/drupal" ]; then
      # Step 4.5: Issue fork — checkout branch, fix composer.json, run composer install.
      # For issue forks the project was created with --no-install so no vendor exists yet.
      # We must checkout the issue branch BEFORE composer install so that vendor is
      # resolved for the correct Drupal version, not for main/drupal12.
      if [ "$USING_ISSUE_FORK" = "true" ] && [ "$ISSUE_FORK_CHECKOUT_DONE" = "false" ]; then
        REPOS_DIR="$DRUPAL_DIR/repos/drupal"
        if [ -d "$REPOS_DIR/.git" ]; then
          CURRENT_BRANCH=$(git -C "$REPOS_DIR" branch --show-current 2>/dev/null || echo "")
          if [ -n "$ISSUE_BRANCH" ] && [ "$CURRENT_BRANCH" = "$ISSUE_BRANCH" ]; then
            log_setup "✓ Already on issue branch: $ISSUE_BRANCH"
          else
            if [ -n "$ISSUE_FORK" ]; then
              log_setup "Adding issue fork remote: $ISSUE_FORK"
              git -C "$REPOS_DIR" remote remove issue 2>/dev/null || true
              git -C "$REPOS_DIR" remote add issue "https://git.drupalcode.org/issue/$ISSUE_FORK.git"
              git -C "$REPOS_DIR" fetch issue 2>&1 | tee -a "$SETUP_LOG" || true
            fi
            if [ -n "$ISSUE_BRANCH" ]; then
              log_setup "Checking out issue branch: $ISSUE_BRANCH"
              git -C "$REPOS_DIR" checkout -b "$ISSUE_BRANCH" "issue/$ISSUE_BRANCH" 2>&1 | tee -a "$SETUP_LOG" || \
              git -C "$REPOS_DIR" checkout "$ISSUE_BRANCH" 2>&1 | tee -a "$SETUP_LOG" || \
              log_setup "✗ Failed to check out branch $ISSUE_BRANCH (continuing anyway)"
            fi
          fi

          # Apply composer.json fixes so ddev composer install resolves correctly.
          # Root composer.json hardcodes "drupal/core: dev-main" which conflicts with
          # non-main issue branches in the canonical path repos.
          log_setup "Applying composer.json fixes for Drupal $DRUPAL_VERSION issue branch..."
          # Fix 1 (ALL versions): relax drupal/core constraint so path repo version is accepted.
          jq '.require["drupal/core"] = "*"' composer.json > composer.json.tmp && mv composer.json.tmp composer.json

          if [ "$DRUPAL_VERSION" = "10" ]; then
            # Fix 2 (drupal 10): drupal/core-dev 10.x requires composer/composer ^2.8.1 AND
            # justinrainbow/json-schema ^5.2, but 2.9.x requires ^6.5.1 — conflict.
            # Pin to 2.8.x and disable the security advisory block (it's a dev tool, not a
            # web vulnerability — see https://www.drupal.org/project/drupal/issues/3557585).
            jq '.require["composer/composer"] = "~2.8.1" | .config.audit["block-insecure"] = false' \
              composer.json > composer.json.tmp && mv composer.json.tmp composer.json
            log_setup "  Applied drupal10 fix: pinned composer/composer to ~2.8.1"
          else
            # Fix 3 (drupal 11/12): drupal/core-recommended requires a specific drupal/core
            # version (e.g. 11.x-dev) but the path repo offers dev-<issue> without that alias.
            # Read the required version from core-recommended and add it as a branch-alias.
            CHECKED_OUT_BRANCH=$(git -C "$REPOS_DIR" branch --show-current 2>/dev/null || echo "")
            TARGET_ALIAS=$(jq -r '.require["drupal/core"]' \
              "$REPOS_DIR/composer/Metapackage/CoreRecommended/composer.json" 2>/dev/null || echo "")
            if [ -n "$TARGET_ALIAS" ] && [ -n "$CHECKED_OUT_BRANCH" ]; then
              jq --arg branch "dev-$CHECKED_OUT_BRANCH" --arg alias "$TARGET_ALIAS" \
                '.extra["branch-alias"] = {($branch): $alias}' \
                "$REPOS_DIR/core/composer.json" > /tmp/core-composer.tmp \
                && mv /tmp/core-composer.tmp "$REPOS_DIR/core/composer.json"
              log_setup "  Added branch-alias: dev-$CHECKED_OUT_BRANCH → $TARGET_ALIAS"
            fi
            # drupal/drupal on 11.x+ requires drupal/core-recipe-unpack self.version but
            # it is not in the joachim-n path repos list. Add it if the directory exists.
            if [ -d "$REPOS_DIR/composer/Plugin/RecipeUnpack" ]; then
              jq '.repositories += [{"type":"path","url":"repos/drupal/composer/Plugin/RecipeUnpack"}]' \
                composer.json > composer.json.tmp && mv composer.json.tmp composer.json
              log_setup "  Added RecipeUnpack path repo"
            fi
          fi

          # Now install dependencies for the checked-out issue branch.
          log_setup "Running composer install for issue branch..."
          update_status "⏳ Composer install for issue branch: In progress..."
          _t=$SECONDS
          if ddev composer install 2>&1 | tee -a "$SETUP_LOG"; then
            log_setup "✓ Composer install complete ($((SECONDS - _t))s)"
            update_status "✓ Composer install for issue branch: Success"
          else
            log_setup "✗ Composer install failed ($((SECONDS - _t))s)"
            update_status "✗ Composer install for issue branch: Failed"
            update_status ""
            update_status "Manual recovery:"
            update_status "  cd $DRUPAL_DIR && ddev composer install"
          fi
        fi
      fi

      # Step 4.9: Restore repos/drupal/vendor symlink if missing.
      # This symlink (repos/drupal/vendor -> ../../vendor) is created by joachim-n's
      # post-install scripts. It can be absent when a previous workspace attempt failed
      # before composer install completed.
      if [ -d "repos/drupal/.git" ] && [ ! -e "repos/drupal/vendor" ]; then
        log_setup "Restoring missing repos/drupal/vendor symlink..."
        ln -s ../../vendor repos/drupal/vendor && log_setup "  symlink restored" || log_setup "  symlink restore failed (non-critical)"
      fi

      # Step 5: Ensure Drush is available (skip if already present from cache or pre-checkout install)
      if [ -f "vendor/bin/drush" ]; then
        log_setup "✓ Drush already present"
        update_status "✓ Drush install: Already present"
      else
        _t=$SECONDS
        log_setup "Adding Drush..."
        update_status "⏳ Drush install: In progress..."

        if ddev composer require drush/drush >> "$SETUP_LOG" 2>&1; then
          log_setup "✓ Drush configured ($((SECONDS - _t))s)"
          update_status "✓ Drush install: Success"
        else
          log_setup "⚠ Warning: Failed to configure Drush ($((SECONDS - _t))s)"
          update_status "⚠ Drush install: Warning"
        fi
      fi

      # Step 6: Install or import Drupal database
      # Fast path (DB cache import) is only used when:
      #   - No issue fork (issue code may differ from cached DB)
      #   - Install profile is demo_umami (cache was built with that profile)
      #   - Cache tarball exists
      if ddev drush status 2>/dev/null | grep -q "Drupal bootstrap.*Successful"; then
        log_setup "✓ Drupal already installed"
        update_status "✓ Drupal install: Already present"
      elif [ "$USING_ISSUE_FORK" = "false" ] && [ "$INSTALL_PROFILE" = "demo_umami" ] && [ -f "$CACHE_SEED/.tarballs/db.sql.gz" ]; then
        _t=$SECONDS
        log_setup "Importing database from cache (fast path)..."
        update_status "⏳ Drupal install: Importing cached database..."

        if ddev import-db --file="$CACHE_SEED/.tarballs/db.sql.gz" >> "$SETUP_LOG" 2>&1; then
          log_setup "✓ Database imported from cache ($((SECONDS - _t))s)"
          log_setup ""
          log_setup "   Admin Credentials:"
          log_setup "      Username: admin"
          log_setup "      Password: admin"
          log_setup ""
          update_status "✓ Drupal install: Imported from cache"
        else
          log_setup "⚠ DB import failed ($((SECONDS - _t))s), falling back to full site install..."
          update_status "⚠ DB import failed, running full install..."
          _t=$SECONDS
          if ddev drush si -y "$INSTALL_PROFILE" --account-pass=admin >> "$SETUP_LOG" 2>&1; then
            log_setup "✓ Drupal installed successfully (fallback, $((SECONDS - _t))s)"
            update_status "✓ Drupal install: Success (fallback)"
          else
            log_setup "✗ Failed to install Drupal ($((SECONDS - _t))s)"
            update_status "✗ Drupal install: Failed"
          fi
        fi
      else
        _t=$SECONDS
        if [ "$USING_ISSUE_FORK" = "true" ]; then
          log_setup "Installing Drupal with $INSTALL_PROFILE profile (issue fork: full install required)..."
        else
          log_setup "Installing Drupal with $INSTALL_PROFILE profile (this will take 2-3 minutes)..."
        fi
        update_status "⏳ Drupal install: In progress..."

        if ddev drush si -y "$INSTALL_PROFILE" --account-pass=admin >> "$SETUP_LOG" 2>&1; then
          log_setup "✓ Drupal installed ($((SECONDS - _t))s)"
          log_setup ""
          log_setup "   Admin Credentials:"
          log_setup "      Username: admin"
          log_setup "      Password: admin"
          log_setup ""
          update_status "✓ Drupal install: Success"
        else
          log_setup "✗ Failed to install Drupal ($((SECONDS - _t))s)"
          log_setup "Check $SETUP_LOG for details"
          update_status "✗ Drupal install: Failed"
          update_status ""
          update_status "Manual recovery:"
          update_status "  cd $DRUPAL_DIR"
          update_status "  ddev drush si -y $INSTALL_PROFILE --account-pass=admin"
        fi
      fi

      # Step 6.5: Cache rebuild — ensures a clean state after any setup path
      log_setup "Running cache rebuild..."
      ddev drush cr >> "$SETUP_LOG" 2>&1 || true

      # Step 6.6: Set up phpunit.xml for running core tests
      if [ ! -f "phpunit.xml" ] && [ -f "phpunit-ddev.xml" ]; then
        cp phpunit-ddev.xml phpunit.xml
        # Replace PROJECT_NAME.ddev.site placeholder with actual workspace URL
        if [ -n "$VSCODE_PROXY_URI" ] && [ -n "$CODER_WORKSPACE_OWNER_NAME" ]; then
          CODER_DOMAIN=$(echo "$VSCODE_PROXY_URI" | sed -E 's|https?://[^.]+\.(.+?)(/.*)?$|\1|')
          SITE_URL="https://80--$${CODER_WORKSPACE_NAME}--$${CODER_WORKSPACE_OWNER_NAME}.$${CODER_DOMAIN}"
          sed -i "s|PROJECT_NAME\.ddev\.site|$${SITE_URL#https://}|" phpunit.xml
        fi
        log_setup "✓ phpunit.xml configured (run tests with: ddev exec vendor/bin/phpunit web/core/tests/...)"
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

    # Timing summary
    TOTAL_TIME=$((SECONDS - SCRIPT_START))
    INSTALL_TIME=$((SECONDS - SETUP_START))

    # Final status and summary
    update_status ""
    update_status "Completed: $(date)"
    update_status ""
    update_status "--- Timing ---"
    update_status "  ddev utility download-images: $${IMAGES_TIME}s"
    update_status "  Install/seed phase:           $${INSTALL_TIME}s"
    update_status "  Total workspace startup:      $${TOTAL_TIME}s"
    update_status ""
    update_status "View full logs: $SETUP_LOG"

    log_setup ""
    log_setup "=========================================="
    log_setup "✨ Setup Complete!"
    log_setup "=========================================="
    log_setup ""
    log_setup "⏱  Timing Summary:"
    log_setup "   ddev utility download-images: $${IMAGES_TIME}s"
    log_setup "   Install/seed phase:           $${INSTALL_TIME}s"
    log_setup "   Total workspace startup:      $${TOTAL_TIME}s"
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
    echo "⏱  Timing: images=$${IMAGES_TIME}s  install=$${INSTALL_TIME}s  total=$${TOTAL_TIME}s"
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
  icon         = "https://avatars.githubusercontent.com/u/47573844?s=128"
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
    export PATH="$PATH:/home/linuxbrew/.linuxbrew/bin:/usr/local/bin"
    # Wait for Docker socket — it should already be up, but guard against
    # race conditions during workspace stop/update.
    for i in $(seq 1 10); do
      [ -S /var/run/docker.sock ] && break
      sleep 1
    done
    if [ ! -S /var/run/docker.sock ]; then
      echo "Docker socket not available; skipping ddev poweroff"
      exit 0
    fi
    echo "Running ddev poweroff..."
    ddev poweroff || true
    echo "ddev poweroff complete"
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
  stop_signal  = "SIGINT"
  destroy_grace_seconds = 180

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

  # Read-only seed cache: pre-built drupal-core project for fast workspace creation.
  # If the path doesn't exist on the host, Docker creates an empty dir and the
  # startup script gracefully falls back to a full composer create.
  volumes {
    host_path      = var.cache_path
    container_path = "/home/coder-cache-seed"
    read_only      = true
  }

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
    key   = "admin_credentials"
    value = "admin / admin"
  }
  item {
    key   = "image"
    value = "${docker_image.workspace_image.name} (version: ${local.image_version})"
  }
}

# Output for Vault integration status (visible in Terraform logs)



