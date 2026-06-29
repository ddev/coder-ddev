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

variable "docker_registry_mirror" {
  description = "Optional Docker registry mirror URL override (e.g. http://your-host:5000). When empty, startup auto-detects a mirror at http://<coder-host>:5000 if reachable."
  type        = string
  default     = ""
}

variable "cache_path" {
  description = "Host path to the drupal-core seed cache directory (mounted read-only into workspaces)"
  type        = string
  default     = ""
}

variable "github_token" {
  description = "GitHub token passed to Composer as GitHub OAuth to avoid codeload.github.com rate limits (optional; ordinary users get a token via coder external-auth)"
  type        = string
  default     = ""
  sensitive   = true
}

# Per-workspace user parameters (shown in workspace creation UI, pre-fillable via ?param.name=value URL)
data "coder_parameter" "issue_fork" {
  name         = "issue_fork"
  display_name = "Issue Fork"
  description  = "Drupal.org issue number or fork name (e.g., 3568144 or drupal-3568144). Leave empty for standard Drupal core development."
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
    name  = "12.x (main branch)"
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
  description  = "Drupal install profile. demo_umami uses a pre-built database snapshot (12.x only); other profiles and non-12.x versions always run a full site install."
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

data "coder_parameter" "share_drupal_site" {
  name         = "share_drupal_site"
  display_name = "Drupal Site Sharing"
  description  = "Who can access the Drupal site URL. Change to 'public' when you want to share a work-in-progress with someone outside Coder."
  type         = "string"
  default      = "owner"
  mutable      = true
  order        = 90

  option {
    name  = "Private (owner only)"
    value = "owner"
  }
  option {
    name  = "Authenticated (any Coder user)"
    value = "authenticated"
  }
  option {
    name  = "Public (anyone with the link)"
    value = "public"
  }
}

data "coder_parameter" "vscode_extensions" {
  name         = "vscode_extensions"
  display_name = "VS Code Extensions"
  description  = "Select extensions to enable in VS Code for Web"
  type         = "list(string)"
  form_type    = "multi-select"
  default      = jsonencode([for e in var.vscode_extensions : e.id if e.default])
  mutable      = true
  order        = 100

  dynamic "option" {
    for_each = var.vscode_extensions
    content {
      name  = option.value.name
      value = option.value.id
    }
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
  workspace_home      = "/home/coder"
  selected_extensions = jsondecode(data.coder_parameter.vscode_extensions.value)
  issue_fork_clean    = trimprefix(data.coder_parameter.issue_fork.value, "drupal-")
  issue_url           = local.issue_fork_clean != "" ? "https://www.drupal.org/project/drupal/issues/${local.issue_fork_clean}" : ""
  # Coerce share value — mock_data in tftest returns "[]" for all parameters;
  # fall back to "owner" if the value is not a valid share level.
  drupal_site_share = contains(["owner", "authenticated", "public"], data.coder_parameter.share_drupal_site.value) ? data.coder_parameter.share_drupal_site.value : "owner"
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

variable "vscode_extensions" {
  description = "List of VS Code extensions to offer in the workspace creation UI"
  type = list(object({
    id      = string
    name    = string
    default = bool
  }))
  default = [
    { id = "xdebug.php-debug", name = "PHP Debug", default = true },
    { id = "bmewburn.vscode-intelephense-client", name = "Intelephense", default = true },
    { id = "dbaeumer.vscode-eslint", name = "ESLint", default = true },
    { id = "esbenp.prettier-vscode", name = "Prettier", default = true },
    { id = "sanderronde.phpstan-vscode", name = "PHPStan", default = true },
    { id = "streetsidesoftware.code-spell-checker", name = "Code Spell Checker", default = true },
    { id = "stylelint.vscode-stylelint", name = "Stylelint", default = true },
    { id = "valeryanm.vscode-phpsab", name = "PHPSAB", default = true },
    { id = "biati.ddev-manager", name = "DDEV Manager", default = true },
    { id = "deque-systems.vscode-axe-linter", name = "Axe Linter", default = false },
    { id = "andrewdavidblum.drupal-smart-snippets", name = "Drupal Smart Snippets", default = false },
    { id = "redhat.vscode-yaml", name = "YAML", default = false },
    { id = "sleistner.vscode-fileutils", name = "File Utils", default = false },
    { id = "GitHub.vscode-pull-request-github", name = "GitHub Pull Requests", default = false },
  ]
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
      if [ -d /home/coder-files/.vscode ]; then
        mkdir -p ~/.vscode
        if [ -f /home/coder-files/.vscode/settings.json ]; then
          cp /home/coder-files/.vscode/settings.json ~/.vscode/settings.json
          chown coder:coder ~/.vscode/settings.json 2>/dev/null || true
        fi
      fi
    else
      echo "Warning: /home/coder-files not found in image"
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
    REGISTRY_MIRROR="${var.docker_registry_mirror}"
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

    # Issue fork / install profile parameters (evaluated at template build time)
    ISSUE_FORK="${data.coder_parameter.issue_fork.value}"
    ISSUE_FORK="$${ISSUE_FORK#drupal-}"
    ISSUE_BRANCH="${data.coder_parameter.issue_branch.value}"
    INSTALL_PROFILE="${data.coder_parameter.install_profile.value}"

    # Fetch issue title from drupal.org API (best-effort)
    ISSUE_TITLE=""
    if [ -n "$ISSUE_FORK" ]; then
      ISSUE_TITLE=$(curl -sf "https://www.drupal.org/api-d7/node/$${ISSUE_FORK}.json" 2>/dev/null | jq -r '.title // ""' 2>/dev/null || echo "")
    fi

    USING_ISSUE_FORK=false
    SETUP_FAILED=false
    if [ -n "$ISSUE_FORK" ] || [ -n "$ISSUE_BRANCH" ]; then
      USING_ISSUE_FORK=true
      log_setup "Issue fork mode: ISSUE_FORK=$ISSUE_FORK  ISSUE_BRANCH=$ISSUE_BRANCH  INSTALL_PROFILE=$INSTALL_PROFILE"
    fi

    if [ -n "$ISSUE_FORK" ]; then
      log_setup "🔗 Issue: https://www.drupal.org/project/drupal/issues/$ISSUE_FORK"
      if [ -n "$ISSUE_TITLE" ]; then log_setup "   Title: $ISSUE_TITLE"; fi
    fi

    # Drupal version, branch, and DDEV project type — computed early so the git clone
    # section can check out the correct branch before DDEV config runs.
    DRUPAL_VERSION="${data.coder_parameter.drupal_version.value}"
    case "$DRUPAL_VERSION" in
      10) DDEV_PROJECT_TYPE="drupal10"; DRUPAL_BRANCH="10.x" ;;
      11) DDEV_PROJECT_TYPE="drupal11"; DRUPAL_BRANCH="11.x" ;;
      *)  DDEV_PROJECT_TYPE="drupal12"; DRUPAL_BRANCH="main" ;;
    esac

    # Step 1: Clone Drupal core (first run) or verify existing checkout
    CACHE_SEED="/home/coder-cache-seed"
    SETUP_START=$SECONDS
    DRUPAL_SETUP_NEEDED=false

    if [ -d "$DRUPAL_DIR/repos/drupal/.git" ]; then
      # Old joachim-n scaffolding detected — existing workspace, skip clone.
      # Drupal continues to work with the existing setup; recreate the workspace to
      # switch to the new amateescu/ddev-drupal-dev scaffolding.
      log_setup "⚠ Old scaffolding (repos/drupal/) detected — keeping existing setup"
      log_setup "  Recreate this workspace to migrate to the new scaffolding."
      update_status "✓ Setup: Existing old-scaffolding workspace"
    elif [ ! -d "$DRUPAL_DIR/.git" ]; then
      DRUPAL_SETUP_NEEDED=true
      update_status "⏳ Git clone: In progress..."
      _t=$SECONDS
      DRUPAL_REMOTE="https://git.drupalcode.org/project/drupal.git"
      if git -C "$CACHE_SEED" rev-parse --is-bare-repository 2>/dev/null | grep -q true; then
        # Bare cache: init repo, add all remotes (cache, origin, issue fork if
        # applicable), fetch cache first (fast local copy of all objects), then
        # fetch origin and issue fork for only the delta.
        log_setup "Initialising Drupal core repo (bare cache + origin delta)..."
        mkdir -p "$DRUPAL_DIR"
        git -C "$DRUPAL_DIR" init >> "$SETUP_LOG" 2>&1
        git -C "$DRUPAL_DIR" remote add drupalcache "$CACHE_SEED"
        git -C "$DRUPAL_DIR" remote add origin "$DRUPAL_REMOTE"
        if [ "$USING_ISSUE_FORK" = "true" ] && [ -n "$ISSUE_FORK" ]; then
          git -C "$DRUPAL_DIR" remote add issue "https://git.drupalcode.org/issue/drupal-$${ISSUE_FORK}.git"
        fi
        git -C "$DRUPAL_DIR" fetch drupalcache >> "$SETUP_LOG" 2>&1
        # Remove the local cache remote now — objects are in the local repo and
        # keeping it causes ambiguous-ref errors when checking out branches that
        # exist in both drupalcache and origin.
        git -C "$DRUPAL_DIR" remote remove drupalcache
        git -C "$DRUPAL_DIR" fetch origin >> "$SETUP_LOG" 2>&1 || true
        if [ "$USING_ISSUE_FORK" = "true" ] && [ -n "$ISSUE_FORK" ]; then
          git -C "$DRUPAL_DIR" fetch issue >> "$SETUP_LOG" 2>&1 || true
        fi
        git -C "$DRUPAL_DIR" checkout -b main --track origin/main >> "$SETUP_LOG" 2>&1
      elif [ -d "$CACHE_SEED/.git" ]; then
        # Non-bare (legacy) cache: use as --reference hint to avoid re-downloading
        # objects that already exist locally.
        log_setup "Cloning Drupal core (with reference from cache seed)..."
        git clone --reference "$CACHE_SEED" "$DRUPAL_REMOTE" "$DRUPAL_DIR" >> "$SETUP_LOG" 2>&1 || \
          git clone "$DRUPAL_REMOTE" "$DRUPAL_DIR" >> "$SETUP_LOG" 2>&1
      else
        log_setup "Cloning Drupal core..."
        git clone "$DRUPAL_REMOTE" "$DRUPAL_DIR" >> "$SETUP_LOG" 2>&1
      fi
      if [ -d "$DRUPAL_DIR/.git" ]; then
        log_setup "✓ Drupal core cloned ($((SECONDS - _t))s)"
        update_status "✓ Git clone: Success"
      else
        log_setup "✗ Failed to clone Drupal core"
        update_status "✗ Git clone: Failed"
        SETUP_FAILED=true
      fi

      # Branch or fork checkout
      if [ "$SETUP_FAILED" != "true" ] && [ "$USING_ISSUE_FORK" = "true" ] && [ -n "$ISSUE_FORK" ]; then
        # Add issue remote and fetch unless already done in the bare-cache setup above.
        if ! git -C "$DRUPAL_DIR" remote get-url issue >> "$SETUP_LOG" 2>&1; then
          log_setup "Adding issue fork remote and fetching: $ISSUE_FORK"
          git -C "$DRUPAL_DIR" remote add issue "https://git.drupalcode.org/issue/drupal-$${ISSUE_FORK}.git"
          git -C "$DRUPAL_DIR" fetch issue >> "$SETUP_LOG" 2>&1
        fi
        if git -C "$DRUPAL_DIR" branch -r | grep -q "^  issue/"; then
          log_setup "  ✓ Fetched from issue remote"
          if [ -n "$ISSUE_BRANCH" ]; then
            if git -C "$DRUPAL_DIR" checkout -b "$ISSUE_BRANCH" "issue/$ISSUE_BRANCH" >> "$SETUP_LOG" 2>&1 || \
               git -C "$DRUPAL_DIR" checkout "$ISSUE_BRANCH" >> "$SETUP_LOG" 2>&1; then
              log_setup "  ✓ Checked out branch: $ISSUE_BRANCH"
              # Ensure the working tree exactly matches the checked-out branch.
              # origin/main may be ahead of the issue branch base; git updates
              # the index but can leave working tree files from those newer main
              # commits behind as modified/untracked.
              git -C "$DRUPAL_DIR" reset --hard HEAD >> "$SETUP_LOG" 2>&1 || true
              git -C "$DRUPAL_DIR" clean -fd >> "$SETUP_LOG" 2>&1 || true
              log_setup "  ✓ Working tree reset to match branch"
            else
              log_setup "✗ Failed to check out branch $ISSUE_BRANCH"
              SETUP_FAILED=true
            fi
          fi
        else
          log_setup "✗ Failed to fetch from issue remote $ISSUE_FORK"
          SETUP_FAILED=true
        fi
      elif [ "$SETUP_FAILED" != "true" ] && [ "$DRUPAL_BRANCH" != "main" ]; then
        if [ "$DRUPAL_BRANCH" = "10.x" ]; then
          _r=$(git -C "$DRUPAL_DIR" branch -r 2>/dev/null | grep -oE "10\.[0-9]+\.x" | sort -V | tail -1 || echo "")
          [ -n "$_r" ] && { DRUPAL_BRANCH="$_r"; log_setup "  Resolved Drupal 10 branch → $DRUPAL_BRANCH"; }
        fi
        if git -C "$DRUPAL_DIR" checkout "$DRUPAL_BRANCH" >> "$SETUP_LOG" 2>&1; then
          log_setup "✓ Checked out branch: $DRUPAL_BRANCH"
        else
          log_setup "✗ Failed to check out $DRUPAL_BRANCH"
          SETUP_FAILED=true
        fi
      fi
    else
      log_setup "✓ Drupal core already cloned — skipping git clone"
      update_status "✓ Setup: Already present"
      if [ "$USING_ISSUE_FORK" = "false" ]; then
        _t=$SECONDS
        if [ "$DRUPAL_BRANCH" = "10.x" ]; then
          _r=$(git -C "$DRUPAL_DIR" branch -r 2>/dev/null | grep -oE "10\.[0-9]+\.x" | sort -V | tail -1 || echo "")
          [ -n "$_r" ] && DRUPAL_BRANCH="$_r"
        fi
        git -C "$DRUPAL_DIR" fetch --all --prune >> "$SETUP_LOG" 2>&1 || true
        git -C "$DRUPAL_DIR" merge --ff-only "origin/$DRUPAL_BRANCH" >> "$SETUP_LOG" 2>&1 || true
        log_setup "  git fetch+merge $DRUPAL_BRANCH complete ($((SECONDS - _t))s)"
      fi
    fi

    cd "$DRUPAL_DIR" || exit 1

    # Step 2: Configure DDEV (must be done before composer create)
    # Always regenerate .ddev/config.yaml from scratch so DDEV picks its own defaults
    # for the project type (e.g. correct PHP version). Preserving an old config.yaml
    # would leave stale fields like php_version untouched even when project-type changes.
    rm -f .ddev/config.yaml
    log_setup "Configuring DDEV for Drupal $DRUPAL_VERSION ($DDEV_PROJECT_TYPE)..."
    update_status "⏳ DDEV config: In progress..."

    # Detect docroot: old joachim-n scaffolding uses web/ symlink; direct git clone has index.php at root.
    DDEV_DOCROOT_ARG=""
    if [ -d "repos/drupal/.git" ] || [ -L "web" ]; then
      DDEV_DOCROOT_ARG="--docroot=web"
      log_setup "  Detected old scaffolding — using --docroot=web"
    fi

    # Compute Coder domain for use in DDEV configuration
    CODER_DOMAIN=""
    if [ -n "$CODER_WORKSPACE_OWNER_NAME" ] && ([ -n "$VSCODE_PROXY_URI" ] || [ -n "$CODER_AGENT_URL" ]); then
      if [ -n "$VSCODE_PROXY_URI" ]; then
        CODER_DOMAIN=$(echo "$VSCODE_PROXY_URI" | sed -E 's|https?://[^.]+\.(.+?)(/.*)?$|\1|')
      else
        CODER_DOMAIN=$(echo "$CODER_AGENT_URL" | sed -E 's|https?://(.+?)(/.*)?$|\1|')
      fi
      export CODER_DOMAIN
    fi

    mkdir -p .ddev
    cat > .ddev/config.coder.yaml << CODER_YAML_EOF
# Auto-generated by workspace startup -- do not edit.
# Sets project_tld so 'ddev describe' shows the Coder domain rather than ddev.site.
#ddev-silent-no-warn
#name: "$${CODER_WORKSPACE_NAME}--$${CODER_WORKSPACE_OWNER_NAME}"
project_tld: "$CODER_DOMAIN"
use_dns_when_possible: false
host_webserver_port: "80"
# Bind mailpit directly to workspace localhost (ddev-router is omitted in this template).
# Without this, mailpit is only reachable inside the DDEV web container.
host_mailpit_port: "8025"
# Show Coder URLs after every ddev start/restart (appended after DDEV's own message).
hooks:
  post-start:
    - exec-host: 'echo "" && echo "  Site:    https://drupal-site--$${CODER_WORKSPACE_NAME}--$${CODER_WORKSPACE_OWNER_NAME}.$CODER_DOMAIN" && echo "  Mailpit: https://mailpit--$${CODER_WORKSPACE_NAME}--$${CODER_WORKSPACE_OWNER_NAME}.$CODER_DOMAIN" && echo ""'
CODER_YAML_EOF
    log_setup "✓ .ddev/config.coder.yaml written"

    if ddev config --project-type="$DDEV_PROJECT_TYPE" $DDEV_DOCROOT_ARG --project-name="$${CODER_WORKSPACE_NAME}--$${CODER_WORKSPACE_OWNER_NAME}" >> "$SETUP_LOG" 2>&1; then
      log_setup "✓ DDEV configured (project-type=$DDEV_PROJECT_TYPE)"
      update_status "✓ DDEV config: Success"
    else
      log_setup "✗ Failed to configure DDEV"
      log_setup "Check $SETUP_LOG for details"
      update_status "✗ DDEV config: Failed"
      update_status ""
      update_status "Manual recovery:"
      update_status "  cd $DRUPAL_DIR"
      update_status "  ddev config --project-type=$DDEV_PROJECT_TYPE $DDEV_DOCROOT_ARG"
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

    # Write Coder-specific DDEV config so 'ddev describe' shows usable URLs.
    # Runs every workspace start so the config stays current.
    # project_tld is set to the Coder subdomain suffix so DDEV's primary URL
    # resolves to <project-name>.<workspace>--<owner>.<coder-domain> rather
    # than the default <project-name>.ddev.site.
    # CODER_DOMAIN was already computed earlier in the script
    if [ -n "$CODER_DOMAIN" ]; then
      # Generate docker-compose override that adds Coder URLs and credentials to
      # 'ddev describe' output via x-ddev labels on the web service.
      cat > .ddev/docker-compose.coder-describe.yaml << COMPOSE_EOF
#ddev-silent-no-warn
# Auto-generated by workspace startup -- do not edit.
services:
  web:
    x-ddev:
      describe-url-port: |
        https://drupal-site--$${CODER_WORKSPACE_NAME}--$${CODER_WORKSPACE_OWNER_NAME}.$CODER_DOMAIN
        Mailpit: https://mailpit--$${CODER_WORKSPACE_NAME}--$${CODER_WORKSPACE_OWNER_NAME}.$CODER_DOMAIN
      describe-info: "Admin: admin / admin"
COMPOSE_EOF
      log_setup "✓ .ddev/docker-compose.coder-describe.yaml written (x-ddev describe labels)"
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

    # Create Drupal-specific welcome message (ISSUE_FORK and ISSUE_TITLE already set above)
    {
      cat << 'WELCOME_STATIC'
Drupal Core Development Workspace
==================================
Admin: admin / admin

Commands:
  ddev launch               # Show site URL and one-time login link
  ddev describe             # Show project details and URLs
  ddev drush status         # Check Drupal status
  ddev logs                 # View container logs
  ddev ssh                  # SSH into web container

  ddev add-module <name>    # Clone a contrib module for development
  ddev phpunit [--db=sqlite|mysql|pgsql] <path>  # Run PHPUnit tests

Add-on docs: https://github.com/amateescu/ddev-drupal-dev
DDEV docs:   https://docs.ddev.com/
WELCOME_STATIC

      if [ -n "$ISSUE_FORK" ]; then
        echo ""
        echo "Issue #$${ISSUE_FORK}: $${ISSUE_TITLE}"
        echo "  https://www.drupal.org/project/drupal/issues/$${ISSUE_FORK}"
      fi
    } > ~/WELCOME.txt
    chown coder:coder ~/WELCOME.txt 2>/dev/null || true

    # Step 4: Install ddev-drupal-dev add-on, composer install, and drush (first run only)
    if [ "$DRUPAL_SETUP_NEEDED" = "true" ] && [ "$SETUP_FAILED" != "true" ]; then
      log_setup "Installing amateescu/ddev-drupal-dev add-on..."
      update_status "⏳ DDEV add-on install: In progress..."
      _t=$SECONDS
      if ddev add-on get amateescu/ddev-drupal-dev >> "$SETUP_LOG" 2>&1; then
        log_setup "✓ Add-on installed ($((SECONDS - _t))s)"
        update_status "✓ DDEV add-on install: Success"
      else
        log_setup "✗ Failed to install add-on ($((SECONDS - _t))s)"
        update_status "✗ DDEV add-on install: Failed"
        SETUP_FAILED=true
      fi

      if [ "$SETUP_FAILED" != "true" ]; then
        log_setup "Restarting DDEV to activate add-on..."
        ddev restart >> "$SETUP_LOG" 2>&1 || true

        # Obtain a GitHub token for Composer OAuth — routes downloads through the
        # authenticated GitHub API instead of anonymous codeload.github.com
        # (which is prone to transient HTTP/2 400s and rate limits).
        # Priority: GITHUB_TOKEN env var (CI/Terraform) → coder external-auth (user's linked account)
        _COMPOSER_GITHUB_TOKEN="$${GITHUB_TOKEN:-}"
        if [ -z "$${_COMPOSER_GITHUB_TOKEN}" ]; then
          _CODER_BIN=$(find /tmp -name "coder" -path "*/coder.*/*" -type f -executable 2>/dev/null | head -1)
          if [ -n "$${_CODER_BIN}" ]; then
            _COMPOSER_GITHUB_TOKEN=$("$${_CODER_BIN}" external-auth access-token github 2>/dev/null || true)
          fi
        fi
        if [ -n "$${_COMPOSER_GITHUB_TOKEN}" ]; then
          log_setup "Configuring Composer GitHub OAuth..."
          ddev exec composer config --global github-oauth.github.com "$${_COMPOSER_GITHUB_TOKEN}" >> "$SETUP_LOG" 2>&1 || true
        fi

        # Retry up to 3 times to handle transient codeload.github.com 400s.
        _composer_ok=false
        for _attempt in 1 2 3; do
          log_setup "Running composer install (attempt $_attempt/3)..."
          update_status "⏳ Composer install: Attempt $_attempt/3..."
          _t=$SECONDS
          if ddev composer install >> "$SETUP_LOG" 2>&1; then
            log_setup "✓ Composer install complete ($((SECONDS - _t))s)"
            update_status "✓ Composer install: Success"
            _composer_ok=true
            break
          fi
          log_setup "✗ Composer install attempt $_attempt failed ($((SECONDS - _t))s)"
          if [ "$_attempt" -lt 3 ]; then
            log_setup "Retrying in 15s..."
            sleep 15
          fi
        done
        if [ "$_composer_ok" = "false" ]; then
          update_status "✗ Composer install: Failed"
          SETUP_FAILED=true
        fi
      fi

      if [ "$SETUP_FAILED" != "true" ]; then
        log_setup "Adding Drush to composer.local.json..."
        update_status "⏳ Drush install: In progress..."
        if ddev composer require drush/drush >> "$SETUP_LOG" 2>&1; then
          log_setup "✓ Drush installed"
          update_status "✓ Drush install: Success"
        else
          log_setup "⚠ Warning: Failed to install Drush (non-critical)"
          update_status "⚠ Drush install: Warning"
        fi
      fi
    fi

    # Steps 5-6: Drupal install — skipped if an earlier step failed
    if [ "$SETUP_FAILED" = "true" ]; then
      log_setup "⚠ Skipping Drupal install due to earlier failure"
      update_status "⚠ Setup incomplete — see drupal-setup.log for details"
    else

    # Compute site name for drush si
    if [ -n "$ISSUE_FORK" ] && [ -n "$ISSUE_TITLE" ]; then
      SITE_NAME="#$${ISSUE_FORK}: $${ISSUE_TITLE}"
    elif [ -n "$ISSUE_FORK" ]; then
      SITE_NAME="Issue #$${ISSUE_FORK}"
    else
      SITE_NAME="Drupal Core Development"
    fi

    if ddev drush status 2>/dev/null | grep -q "Drupal bootstrap.*Successful"; then
      log_setup "✓ Drupal already installed"
      update_status "✓ Drupal install: Already present"
    else
      _t=$SECONDS
      if [ "$USING_ISSUE_FORK" = "true" ]; then
        log_setup "Installing Drupal with $INSTALL_PROFILE profile (issue fork)..."
      else
        log_setup "Installing Drupal with $INSTALL_PROFILE profile..."
      fi
      update_status "⏳ Drupal install: In progress..."

      if ddev drush si -y "$INSTALL_PROFILE" --account-pass=admin --site-name="$SITE_NAME" >> "$SETUP_LOG" 2>&1; then
        log_setup "✓ Drupal installed"
        log_setup ""
        log_setup "   Admin Credentials:"
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
        update_status "  ddev drush si -y $INSTALL_PROFILE --account-pass=admin"
      fi
    fi
    fi # end SETUP_FAILED guard

    # Step 6.5: Cache rebuild — ensures a clean state after any setup path
    log_setup "Running cache rebuild..."
    ddev drush cr >> "$SETUP_LOG" 2>&1 || true

    # Step 6.6: Set up phpunit.xml for running core tests
    if [ ! -f "phpunit.xml" ] && [ -f "phpunit-ddev.xml" ]; then
      cp phpunit-ddev.xml phpunit.xml
      # Replace PROJECT_NAME.ddev.site placeholder with actual workspace URL
      if [ -n "$CODER_WORKSPACE_OWNER_NAME" ] && ([ -n "$VSCODE_PROXY_URI" ] || [ -n "$CODER_AGENT_URL" ]); then
        if [ -n "$VSCODE_PROXY_URI" ]; then
          CODER_DOMAIN=$(echo "$VSCODE_PROXY_URI" | sed -E 's|https?://[^.]+\.(.+?)(/.*)?$|\1|')
        else
          CODER_DOMAIN=$(echo "$CODER_AGENT_URL" | sed -E 's|https?://(.+?)(/.*)?$|\1|')
        fi
        SITE_URL="https://80--$${CODER_WORKSPACE_NAME}--$${CODER_WORKSPACE_OWNER_NAME}.$${CODER_DOMAIN}"
        sed -i "s|PROJECT_NAME\.ddev\.site|$${SITE_URL#https://}|" phpunit.xml
      fi
      log_setup "✓ phpunit.xml configured (run tests with: ddev exec vendor/bin/phpunit core/tests/...)"
    fi

    # Step 7: Install custom DDEV launch command
    mkdir -p ~/.ddev/commands/host
    cat > ~/.ddev/commands/host/launch << 'LAUNCH_EOF'
#!/usr/bin/env bash

## Description: Show Coder URLs for this Drupal workspace
## Usage: launch [path] [-m|--mailpit]
## Example: "ddev launch" or "ddev launch /admin" or "ddev launch -m"
## Flags: [{"Name":"mailpit","Shorthand":"m","Usage":"ddev launch -m shows the Mailpit URL"}]

# Outside a Coder workspace fall back to a basic URL print (no browser available in DinD)
if [ -z "$${CODER_WORKSPACE_NAME:-}" ] || ([ -z "$${VSCODE_PROXY_URI:-}" ] && [ -z "$${CODER_AGENT_URL:-}" ]); then
  echo "Primary URL: $${DDEV_PRIMARY_URL:-unknown}"
  echo "(Not running in a Coder workspace; cannot open a browser.)"
  exit 0
fi

WORKSPACE="$${CODER_WORKSPACE_NAME}"
OWNER="$${CODER_WORKSPACE_OWNER_NAME}"
if [ -n "$${VSCODE_PROXY_URI:-}" ]; then
  DOMAIN=$(echo "$${VSCODE_PROXY_URI}" | sed -E 's|https?://[^.]+\.(.+?)(/.*)?$|\1|')
else
  DOMAIN=$(echo "$${CODER_AGENT_URL}" | sed -E 's|https?://(.+?)(/.*)?$|\1|')
fi
MAILPIT=false
PATH_SUFFIX=""

while :; do
  case $${1:-} in
  -m | --mailpit | --mailhog) MAILPIT=true ;;
  --) shift; break ;;
  -?*) printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2 ;;
  *) break ;;
  esac
  shift
done

if [ -n "$${1:-}" ]; then
  PATH_SUFFIX="/$${1#/}"
fi

if [ "$${MAILPIT}" = "true" ]; then
  echo "https://mailpit--$${WORKSPACE}--$${OWNER}.$${DOMAIN}"
  exit 0
fi

SITE_URL="https://drupal-site--$${WORKSPACE}--$${OWNER}.$${DOMAIN}"

echo ""
echo "Coder URLs for this Drupal workspace:"
echo "  Site:    $${SITE_URL}$${PATH_SUFFIX}"
echo "  Mailpit: https://mailpit--$${WORKSPACE}--$${OWNER}.$${DOMAIN}"
echo ""
echo "Admin login: admin / admin"
ULI=$(ddev drush uli --uri="$${SITE_URL}" 2>/dev/null || true)
if [ -n "$${ULI}" ]; then
  echo "One-time login: $${ULI}"
else
  echo "One-time login: ddev drush uli  (run when Drupal is installed)"
fi
echo ""
echo "Useful commands (from ddev-drupal-dev add-on):"
echo "  ddev add-module <name>    # Clone a contrib module for development"
echo "  ddev phpunit [--db=sqlite|mysql|pgsql] <path>  # Run PHPUnit tests"
echo "  ddev remove-module <name> # Remove a contrib module"
echo "  See: https://github.com/amateescu/ddev-drupal-dev"
echo ""
LAUNCH_EOF

    chmod +x ~/.ddev/commands/host/launch
    log_setup "✓ Custom DDEV launch command installed"
    update_status "✓ DDEV launch command: Installed"

    # Timing summary
    TOTAL_TIME=$((SECONDS - SCRIPT_START))
    INSTALL_TIME=$((SECONDS - SETUP_START))

    # Collect failure lines for summary (✗-prefixed lines from the setup log)
    FAILURE_SUMMARY=$(grep "✗" "$SETUP_LOG" 2>/dev/null | grep -v "^$" | head -20 || true)

    # Final status and summary
    update_status ""
    update_status "Completed: $(date)"
    update_status ""
    update_status "--- Timing ---"
    update_status "  ddev utility download-images: $${IMAGES_TIME}s"
    update_status "  Install/seed phase:           $${INSTALL_TIME}s"
    update_status "  Total workspace startup:      $${TOTAL_TIME}s"
    update_status ""
    if [ "$SETUP_FAILED" = "true" ]; then
      update_status "=========================================="
      update_status "✗ SETUP FAILED — workspace needs attention"
      update_status "=========================================="
      update_status ""
      update_status "Errors:"
      echo "$FAILURE_SUMMARY" | while IFS= read -r _line; do update_status "  $_line"; done
      update_status ""
      update_status "SSH in and run: cat $SETUP_LOG"
    fi
    update_status ""
    update_status "View full logs: $SETUP_LOG"

    log_setup ""
    log_setup "=========================================="
    if [ "$SETUP_FAILED" = "true" ]; then
      log_setup "✗ SETUP FAILED — see errors below"
    else
      log_setup "✨ Setup Complete!"
    fi
    log_setup "=========================================="
    log_setup ""
    if [ "$SETUP_FAILED" = "true" ]; then
      log_setup "Errors encountered:"
      echo "$FAILURE_SUMMARY" | while IFS= read -r _line; do log_setup "  $_line"; done
      log_setup ""
      log_setup "Full log: cat $SETUP_LOG"
      log_setup "Status:   cat $SETUP_STATUS"
    else
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
    fi
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
    


  
    
    
    if [ "$SETUP_FAILED" = "true" ]; then
      # Overwrite WELCOME.txt so SSH login immediately shows the failure
      {
        echo "⚠  WORKSPACE SETUP INCOMPLETE"
        echo "================================"
        echo ""
        echo "Setup encountered errors. Run this for details:"
        echo "  cat $SETUP_LOG"
        echo ""
        echo "Errors:"
        echo "$FAILURE_SUMMARY" | sed 's/^/  /'
        echo ""
        echo "Status file: cat $SETUP_STATUS"
      } > ~/WELCOME.txt

      echo ""
      echo "=========================================="
      echo "✗ SETUP FAILED"
      echo "=========================================="
      echo ""
      echo "Errors:"
      echo "$FAILURE_SUMMARY" | sed 's/^/  /'
      echo ""
      echo "Full log: cat $SETUP_LOG"
      echo ""
    else
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
    fi

    # Explicitly exit with success to prevent "Unhealthy" status
    exit 0
  EOT

  env = {
    CODER_AGENT_FORCE_UPDATE = "35"
    # DOCKER_HOST not needed as we use local socket
    # DOCKER_HOST                = var.docker_host
    CODER_WORKSPACE_ID          = data.coder_workspace.me.id
    CODER_WORKSPACE_NAME        = data.coder_workspace.me.name
    CODER_WORKSPACE_OWNER_NAME  = data.coder_workspace_owner.me.name
    CODER_WORKSPACE_OWNER_EMAIL = data.coder_workspace_owner.me.email
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
  order          = 2
  extensions     = local.selected_extensions
}

# DDEV Web Server (HTTP) - appears when DDEV project is running
# Uses subdomain routing for unique URLs per workspace
resource "coder_app" "ddev-web" {
  agent_id     = coder_agent.main.id
  slug         = "ddev-web"
  display_name = "DDEV Web"
  order        = 1
  url          = "http://localhost:80"
  icon         = "https://raw.githubusercontent.com/ddev/ddev/main/docs/content/developers/logos/SVG/Logo.svg"
  subdomain    = true
  share        = "owner"

  # Healthy when ddev is running and the web server responds (any 2xx/3xx).
  # Lights up as soon as `ddev start` completes, before Drupal is installed.
  healthcheck {
    url       = "http://localhost:80"
    interval  = 10
    threshold = 30
  }
}

resource "coder_app" "drupal-site" {
  agent_id     = coder_agent.main.id
  slug         = "drupal-site"
  display_name = "Drupal Site"
  order        = 2
  url          = "http://localhost:80"
  icon         = "https://api.iconify.design/heroicons:check-circle.svg?color=white"
  subdomain    = true
  share        = local.drupal_site_share

  # Healthy only when Drupal returns 200. /user/login returns 500 when the
  # database isn't set up (before drush si) and 200 when Drupal is fully
  # installed — giving a "site is actually working" indicator distinct from
  # "web server is up".
  healthcheck {
    url       = "http://localhost:80/user/login"
    interval  = 10
    threshold = 3
  }
}

resource "coder_app" "mailpit" {
  agent_id     = coder_agent.main.id
  slug         = "mailpit"
  display_name = "Mailpit"
  order        = 3
  url          = "http://localhost:8025"
  icon         = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/mailpit.svg"
  subdomain    = true
  share        = "owner"

  healthcheck {
    url       = "http://localhost:8025"
    interval  = 10
    threshold = 10
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






resource "docker_container" "workspace" {
  count    = data.coder_workspace.me.start_count
  image    = docker_image.workspace_image.image_id
  name     = "coder-${data.coder_workspace.me.id}"
  hostname = "${data.coder_workspace.me.name}-${data.coder_workspace_owner.me.name}"
  user     = "coder"
  # Add docker group so coder user can access Docker socket
  # GID must match host Docker group (default 988, configurable via docker_gid variable)
  group_add = [tostring(var.docker_gid)]

  # Increase stop_timeout to allow shutdown_script and ddev stop to run
  # Default is usually 10s, which is not enough for ddev shutdown
  stop_timeout          = 180
  stop_signal           = "SIGINT"
  destroy_grace_seconds = 180

  # Direct Mount Strategy: Set Working Directory to path matching Host
  working_dir = local.workspace_home

  # CPU and memory limits
  cpu_shares = var.cpu * 1024
  memory     = var.memory * 1024 * 1024 * 1024

  # Use Sysbox runtime for nested Docker support
  runtime = "sysbox-runc"

  # Mount workspace volume
  # Host Path: /coder-workspaces/<owner>-<workspace>
  # This ensures isolation between workspaces while allows persistent storage
  volumes {
    container_path = local.workspace_home
    host_path      = "/coder-workspaces/${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}"
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
    "GITHUB_TOKEN=${var.github_token}",
  ]

  # Command to keep container running
  command = ["sh", "-c", coder_agent.main.init_script]

  depends_on = [null_resource.workspace_cleanup]

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

resource "null_resource" "workspace_cleanup" {
  triggers = {
    host_path = "/coder-workspaces/${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "sudo /usr/local/bin/coder-delete-workspace-dir '${self.triggers.host_path}'"
  }
}

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
  item {
    key   = "issue"
    value = local.issue_fork_clean != "" ? "#${local.issue_fork_clean}" : "(standard workspace)"
  }
  item {
    key   = "issue_url"
    value = local.issue_url
  }
}

# Output for Vault integration status (visible in Terraform logs)



