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

variable "github_token" {
  description = "GitHub token passed to Composer as COMPOSER_AUTH to avoid codeload.github.com rate limits (optional)"
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

# Per-workspace user parameters
data "coder_parameter" "project_name" {
  name         = "project_name"
  display_name = "Project Machine Name"
  description  = "The Drupal.org machine name of the contrib module or theme (e.g. 'views', 'token', 'pathauto'). Must match the git.drupalcode.org project slug."
  type         = "string"
  mutable      = false
  order        = 0
}

data "coder_parameter" "project_type" {
  name         = "project_type"
  display_name = "Project Type"
  description  = "Whether this is a module or a theme. Controls the symlink path inside the Drupal web root."
  type         = "string"
  default      = "module"
  mutable      = false
  order        = 1
  option {
    name  = "Module"
    value = "module"
  }
  option {
    name  = "Theme"
    value = "theme"
  }
}

data "coder_parameter" "issue_fork" {
  name         = "issue_fork"
  display_name = "Issue Fork"
  description  = "Drupal.org issue number (e.g. 3568144). Leave empty for plain HEAD development."
  type         = "string"
  default      = ""
  mutable      = true
  order        = 2
}

data "coder_parameter" "issue_branch" {
  name         = "issue_branch"
  display_name = "Issue Branch"
  description  = "Issue branch to check out (e.g. 3568144-fix-something-2.x). Leave empty for HEAD."
  type         = "string"
  default      = ""
  mutable      = true
  order        = 3
}

data "coder_parameter" "drupal_version" {
  name         = "drupal_version"
  display_name = "Drupal Version"
  description  = "Major Drupal version to install as the dev dependency. Match the version the issue targets."
  type         = "string"
  default      = "11"
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
  description  = "Drupal install profile. 'minimal' is recommended for contrib development."
  type         = "string"
  default      = "minimal"
  mutable      = true
  order        = 5
  option {
    name  = "minimal"
    value = "minimal"
  }
  option {
    name  = "standard"
    value = "standard"
  }
  option {
    name  = "demo_umami"
    value = "demo_umami"
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

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

locals {
  workspace_home      = "/home/coder"
  selected_extensions = jsondecode(data.coder_parameter.vscode_extensions.value)
  project_name        = data.coder_parameter.project_name.value
  project_dir         = "/home/coder/${data.coder_parameter.project_name.value}"
  issue_fork          = data.coder_parameter.issue_fork.value
  issue_url           = local.issue_fork != "" ? "https://www.drupal.org/project/${local.project_name}/issues/${local.issue_fork}" : ""
  # Coerce share value — mock_data in tftest returns "[]" for all parameters;
  # fall back to "owner" if the value is not a valid share level.
  drupal_site_share = contains(["owner", "authenticated", "public"], data.coder_parameter.share_drupal_site.value) ? data.coder_parameter.share_drupal_site.value : "owner"
}

locals {
  image_version                 = try(trimspace(file("${path.module}/VERSION")), var.image_version)
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
  default     = "index.docker.io/ddev/coder-ddev"
}

resource "docker_image" "workspace_image" {
  name = "${local.workspace_image_registry_base}:${local.image_version}"
  pull_triggers = [
    local.image_version,
    local.workspace_image_registry_base,
    "${local.workspace_image_registry_base}:${local.image_version}",
  ]
  keep_locally = true
  lifecycle {
    create_before_destroy = true
  }
}

variable "cpu" {
  description = "CPU cores"
  type        = number
  default     = 4
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

  dir = "/home/coder/${data.coder_parameter.project_name.value}"

  startup_script = <<-EOT
    #!/bin/bash
    set +e

    echo "Startup script started..."
    SCRIPT_START=$SECONDS

    if command -v sudo > /dev/null 2>&1; then
      SUDO="sudo"
    else
      SUDO=""
    fi

    sudo chown coder:coder /home/coder
    sudo chown -R coder:coder /home/linuxbrew

    if [ ! -f "/home/coder/.bashrc" ]; then
        echo "Initializing home directory..."
        cp -rT /etc/skel/. /home/coder/
    fi

    cd /home/coder

    echo "=========================================="
    echo "Starting workspace setup..."
    echo "=========================================="
    echo "Workspace Home: $HOME"

    if [ -z "$GIT_SSH_COMMAND" ]; then
      CODER_GITSSH=$(find /tmp -name "coder" -path "*/coder.*/*" -type f -executable 2>/dev/null | head -1)
      if [ -n "$CODER_GITSSH" ]; then
        export GIT_SSH_COMMAND="$CODER_GITSSH gitssh"
        echo "✓ Coder GitSSH wrapper found and configured for this session"
      else
        echo "Note: Coder GitSSH wrapper not found. Git operations may require manual SSH key setup."
      fi
    else
      echo "✓ GIT_SSH_COMMAND already set: $GIT_SSH_COMMAND"
    fi

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

    export LANG=en_US.UTF-8
    export LC_ALL=en_US.UTF-8
    if ! grep -q "LC_ALL=en_US.UTF-8" ~/.bashrc; then
      echo "export LANG=en_US.UTF-8" >> ~/.bashrc
      echo "export LC_ALL=en_US.UTF-8" >> ~/.bashrc
    fi

    sed -i '/export GIT_SSH_COMMAND=/d' ~/.bashrc || true

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

    if ! pgrep -x "dockerd" > /dev/null; then
      echo "Starting Docker Daemon..."
      sudo dockerd > /tmp/dockerd.log 2>&1 &

      echo "Waiting for Docker Socket..."
      for i in $(seq 1 30); do
        if [ -S /var/run/docker.sock ]; then
          echo "Docker Socket found!"
          break
        fi
        sleep 1
      done

      if [ -S /var/run/docker.sock ]; then
        sudo chmod 666 /var/run/docker.sock
      else
        echo "Error: Docker Socket not found after 30s!"
      fi
    else
      echo "Docker Daemon already running."
    fi

    mkdir -p ~/.ddev
    echo "Configuring DDEV to omit ddev-router..."
    ddev config global --omit-containers=ddev-router --instrumentation-opt-in=false > /dev/null 2>&1 || true
    mkcert -install 2>/dev/null || true

    _t_images=$SECONDS
    echo "Pre-pulling DDEV images..."
    ddev utility download-images || true
    IMAGES_TIME=$((SECONDS - _t_images))
    echo "  ddev utility download-images complete ($${IMAGES_TIME}s)"

    # ==========================================
    # DRUPAL CONTRIB AUTOMATIC SETUP
    # ==========================================
    echo ""
    echo "=========================================="
    echo "Drupal Contrib Automatic Setup"
    echo "=========================================="

    PROJECT_NAME="${data.coder_parameter.project_name.value}"
    PROJECT_TYPE="${data.coder_parameter.project_type.value}"
    PROJ_DIR="/home/coder/$PROJECT_NAME"
    SETUP_LOG="/tmp/drupal-setup.log"
    SETUP_STATUS="$HOME/SETUP_STATUS.txt"

    cat > "$SETUP_STATUS" << 'STATUS_HEADER'
Drupal Contrib Setup Status
============================
STATUS_HEADER
    echo "Started: $(date)" >> "$SETUP_STATUS"
    echo "Project: $PROJECT_NAME ($PROJECT_TYPE)" >> "$SETUP_STATUS"
    echo "" >> "$SETUP_STATUS"

    log_setup() {
      echo "$1" | tee -a "$SETUP_LOG"
    }

    update_status() {
      echo "$1" >> "$SETUP_STATUS"
    }

    SETUP_FAILED=false
    SETUP_START=$SECONDS

    # ==========================================
    # Phase 2: Clone project (idempotent)
    # ==========================================
    if [ ! -d "$PROJ_DIR/.git" ]; then
      log_setup "Cloning $PROJECT_NAME from git.drupalcode.org..."
      update_status "⏳ Clone: In progress..."
      if git clone "https://git.drupalcode.org/project/$PROJECT_NAME.git" "$PROJ_DIR" >> "$SETUP_LOG" 2>&1; then
        log_setup "✓ Cloned $PROJECT_NAME"
        update_status "✓ Clone: Success"
      else
        log_setup "✗ Failed to clone $PROJECT_NAME"
        update_status "✗ Clone: Failed"
        SETUP_FAILED=true
      fi
    else
      log_setup "✓ $PROJECT_NAME repo already present — skipping clone"
      update_status "✓ Clone: Already present"
      # Keep repo current on restart
      git -C "$PROJ_DIR" fetch --all --prune >> "$SETUP_LOG" 2>&1 || true
    fi

    cd "$PROJ_DIR" || { log_setup "✗ Cannot cd to $PROJ_DIR"; SETUP_FAILED=true; }

    # Hide Coder-specific DDEV files from git status.
    # .git/info/exclude is never committed and acts like a per-clone .gitignore.
    # We only exclude files we generate — not web/, vendor/, etc. which are the
    # module's own concern and may already be in its .gitignore.
    mkdir -p .git/info
    cat > .git/info/exclude << 'GIT_EXCLUDE_EOF'
# Generated by coder-ddev workspace startup — do not edit.
.ddev/.env.web
.ddev/config.coder.yaml
.ddev/docker-compose.coder-describe.yaml
.ddev/config.local.yaml
GIT_EXCLUDE_EOF

    # ==========================================
    # Phase 3: Issue fork checkout (if requested)
    # ==========================================
    ISSUE_FORK="${data.coder_parameter.issue_fork.value}"
    ISSUE_BRANCH="${data.coder_parameter.issue_branch.value}"

    if [ "$SETUP_FAILED" = "false" ] && [ -n "$ISSUE_FORK" ]; then
      log_setup "Issue fork mode: ISSUE_FORK=$ISSUE_FORK  ISSUE_BRANCH=$ISSUE_BRANCH"
      log_setup "🔗 Issue: https://www.drupal.org/project/$PROJECT_NAME/issues/$ISSUE_FORK"

      # Fetch issue title for display
      ISSUE_TITLE=$(curl -sf "https://www.drupal.org/api-d7/node/$${ISSUE_FORK}.json" 2>/dev/null | jq -r '.title // ""' 2>/dev/null || echo "")
      if [ -n "$ISSUE_TITLE" ]; then
        log_setup "   Title: $ISSUE_TITLE"
      fi

      REMOTE_NAME="issue-$ISSUE_FORK"
      FORK_URL="https://git.drupalcode.org/issue/$PROJECT_NAME-$ISSUE_FORK.git"

      update_status "⏳ Issue fork fetch: In progress..."
      if ! git remote | grep -qx "$REMOTE_NAME"; then
        git remote add "$REMOTE_NAME" "$FORK_URL" >> "$SETUP_LOG" 2>&1
      fi

      if git fetch "$REMOTE_NAME" >> "$SETUP_LOG" 2>&1; then
        log_setup "✓ Fetched issue fork remote"
        update_status "✓ Issue fork fetch: Success"
      else
        log_setup "⚠ Warning: Failed to fetch issue fork remote $FORK_URL (non-critical)"
        update_status "⚠ Issue fork fetch: Warning (remote may not exist yet)"
      fi

      if [ -n "$ISSUE_BRANCH" ]; then
        CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
        if [ "$CURRENT_BRANCH" != "$ISSUE_BRANCH" ]; then
          update_status "⏳ Branch checkout: In progress..."
          if git checkout "$ISSUE_BRANCH" >> "$SETUP_LOG" 2>&1 || \
             git checkout -b "$ISSUE_BRANCH" "$REMOTE_NAME/$ISSUE_BRANCH" >> "$SETUP_LOG" 2>&1; then
            log_setup "✓ Checked out branch $ISSUE_BRANCH"
            update_status "✓ Branch checkout: Success"
            # Ensure working tree exactly matches the checked-out branch.
            # origin/main may be ahead of the issue branch base; git can leave
            # files from those newer commits as modified/untracked after checkout.
            git reset --hard HEAD >> "$SETUP_LOG" 2>&1 || true
            git clean -fd >> "$SETUP_LOG" 2>&1 || true
            log_setup "✓ Working tree reset to match branch"
          else
            log_setup "⚠ Warning: Could not checkout $ISSUE_BRANCH — remaining on current branch"
            update_status "⚠ Branch checkout: Warning"
          fi
        else
          log_setup "✓ Already on branch $ISSUE_BRANCH"
          update_status "✓ Branch checkout: Already on correct branch"
        fi
      fi
    fi

    # ==========================================
    # Phase 4: DDEV configuration
    # ==========================================
    if [ "$SETUP_FAILED" = "false" ]; then
      DRUPAL_VERSION="${data.coder_parameter.drupal_version.value}"
      case "$DRUPAL_VERSION" in
        10) DDEV_PROJECT_TYPE="drupal10" ;;
        11) DDEV_PROJECT_TYPE="drupal11" ;;
        *)  DDEV_PROJECT_TYPE="drupal12" ;;
      esac

      # Compute Coder domain
      CODER_DOMAIN=""
      if [ -n "$CODER_WORKSPACE_OWNER_NAME" ] && ([ -n "$VSCODE_PROXY_URI" ] || [ -n "$CODER_AGENT_URL" ]); then
        if [ -n "$VSCODE_PROXY_URI" ]; then
          CODER_DOMAIN=$(echo "$VSCODE_PROXY_URI" | sed -E 's|https?://[^.]+\.(.+?)(/.*)?$|\1|')
        else
          CODER_DOMAIN=$(echo "$CODER_AGENT_URL" | sed -E 's|https?://(.+?)(/.*)?$|\1|')
        fi
        export CODER_DOMAIN
      fi

      # Always regenerate .ddev/config.yaml so DDEV picks correct PHP version
      rm -f .ddev/config.yaml
      log_setup "Configuring DDEV for Drupal $DRUPAL_VERSION ($DDEV_PROJECT_TYPE)..."
      update_status "⏳ DDEV config: In progress..."

      mkdir -p .ddev

      cat > .ddev/config.coder.yaml << CODER_YAML_EOF
# Auto-generated by workspace startup -- do not edit.
#ddev-silent-no-warn
project_tld: "$CODER_DOMAIN"
use_dns_when_possible: false
host_webserver_port: "8080"
host_mailpit_port: "8025"
hooks:
  post-start:
    - exec-host: 'echo "" && echo "  Site:    https://drupal-site--$${CODER_WORKSPACE_NAME}--$${CODER_WORKSPACE_OWNER_NAME}.$CODER_DOMAIN" && echo "  Mailpit: https://mailpit--$${CODER_WORKSPACE_NAME}--$${CODER_WORKSPACE_OWNER_NAME}.$CODER_DOMAIN" && echo ""'
CODER_YAML_EOF

      # For themes, set symlink target path via config.local.yaml
      if [ "$PROJECT_TYPE" = "theme" ]; then
        cat > .ddev/config.local.yaml << 'THEME_YAML_EOF'
#ddev-silent-no-warn
web_environment:
  - DRUPAL_PROJECTS_PATH=themes/custom
THEME_YAML_EOF
        log_setup "✓ Theme symlink path configured (themes/custom)"
      fi

      if ddev config --project-type="$DDEV_PROJECT_TYPE" --docroot=web \
           --project-name="$${CODER_WORKSPACE_NAME}--$${CODER_WORKSPACE_OWNER_NAME}" >> "$SETUP_LOG" 2>&1; then
        log_setup "✓ DDEV configured (project-type=$DDEV_PROJECT_TYPE docroot=web)"
        update_status "✓ DDEV config: Success"
      else
        log_setup "✗ Failed to configure DDEV"
        update_status "✗ DDEV config: Failed"
        SETUP_FAILED=true
      fi

      if [ -n "$CODER_DOMAIN" ]; then
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
        log_setup "✓ .ddev/docker-compose.coder-describe.yaml written"
      fi

      ddev config global --omit-containers=ddev-router >> "$SETUP_LOG" 2>&1 || true

      # Install ddev-drupal-contrib addon (idempotent)
      log_setup "Installing ddev-drupal-contrib addon..."
      update_status "⏳ ddev-drupal-contrib addon: In progress..."
      if ddev add-on get ddev/ddev-drupal-contrib >> "$SETUP_LOG" 2>&1; then
        log_setup "✓ ddev-drupal-contrib addon installed"
        update_status "✓ ddev-drupal-contrib addon: Success"
      else
        log_setup "⚠ Warning: ddev-drupal-contrib addon install had issues (non-critical)"
        update_status "⚠ ddev-drupal-contrib addon: Warning"
      fi

      # Set DRUPAL_CORE so ddev-drupal-contrib's expand-composer-json / ddev poser
      # installs the selected major version instead of defaulting to ^11.
      ddev dotenv set .ddev/.env.web --drupal-core "^$DRUPAL_VERSION"
      log_setup "✓ DRUPAL_CORE set to ^$DRUPAL_VERSION"

      # Start DDEV
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
        update_status "✗ DDEV start: Failed"
        SETUP_FAILED=true
      fi
    fi

    # ==========================================
    # Phase 5: Drupal installation (idempotent)
    # ==========================================
    if [ "$SETUP_FAILED" = "false" ]; then
      # Check if Drupal is already installed (web/ dir with settings.php is the indicator)
      DRUPAL_INSTALLED=false
      if [ -d "$PROJ_DIR/web/sites/default/files" ] && \
         ddev drush status --field=db-status 2>/dev/null | grep -qi "connected"; then
        DRUPAL_INSTALLED=true
        log_setup "✓ Drupal already installed — skipping site install"
        update_status "✓ Drupal install: Already installed"
      fi

      if [ "$DRUPAL_INSTALLED" = "false" ]; then
        if [ ! -f composer.json ]; then
           log_setup "Creating empty composer.json..."
           echo '{}' > composer.json
        fi
        # Add drush as require-dev so expand-composer-json includes it in composer.contrib.json.
        # Direct JSON edit (not `composer require`) per ddev-drupal-contrib README.
        log_setup "Adding drush to require-dev..."
        update_status "⏳ drush: Adding to composer.json..."
        jq '.["require-dev"]["drush/drush"] = "*"' composer.json > composer.json.tmp && mv composer.json.tmp composer.json

        # Allow all Composer plugins in this dev environment. Composer 2.2+ blocks
        # unknown plugins by default; modules can pull in arbitrary plugins (e.g.
        # symfony/runtime) that aren't pre-listed in allow-plugins.
        jq 'if .config == null then .config = {} else . end | .config["allow-plugins"] = true' composer.json > composer.json.tmp && mv composer.json.tmp composer.json

        # Obtain a GitHub token for Composer OAuth — routes downloads through the
        # authenticated GitHub API instead of anonymous codeload.github.com
        # (which is prone to transient HTTP/2 400s and rate limits).
        # Priority: GITHUB_TOKEN env var (CI/Terraform) → coder external-auth (user's linked account)
        _COMPOSER_GITHUB_TOKEN="$${GITHUB_TOKEN:-}"
        if [ -z "$${_COMPOSER_GITHUB_TOKEN}" ]; then
          _CODER_BIN=$(find /tmp -name "coder" -path "*/coder.*/*" -type f -executable 2>/dev/null | head -1)
          if [ -n "$${_CODER_BIN}" ]; then
            # `coder external-auth access-token` prints the token to stdout and exits 0,
            # but when the user has no linked GitHub account it prints the *authentication
            # URL* to stdout and exits 1. The exit code must be honored: handing that URL
            # to Composer as an OAuth token makes every github.com dist download fail with
            # "Could not authenticate against github.com" and suppresses the anonymous
            # fallback, which is strictly worse than configuring no token at all.
            if _token=$("$${_CODER_BIN}" external-auth access-token github 2>/dev/null); then
              _COMPOSER_GITHUB_TOKEN="$_token"
            else
              log_setup "No linked GitHub account — using anonymous Composer downloads"
            fi
          fi
        fi
        # An expired or revoked token fails the same opaque way, so verify before use.
        if [ -n "$${_COMPOSER_GITHUB_TOKEN}" ] && \
           ! curl -sSf --max-time 10 -o /dev/null -H "Authorization: Bearer $${_COMPOSER_GITHUB_TOKEN}" https://api.github.com/user 2>/dev/null; then
          log_setup "⚠ GitHub token rejected by api.github.com — using anonymous Composer downloads"
          _COMPOSER_GITHUB_TOKEN=""
        fi
        if [ -n "$${_COMPOSER_GITHUB_TOKEN}" ]; then
          log_setup "Configuring Composer GitHub OAuth..."
          ddev exec composer config --global github-oauth.github.com "$${_COMPOSER_GITHUB_TOKEN}" >> "$SETUP_LOG" 2>&1 || true
        else
          # Clear any token a previous run configured. Composer's global config lives in
          # a persistent DDEV volume, so a bad value keeps breaking every later start
          # even once this code stops writing one.
          ddev exec composer config --global --unset github-oauth.github.com >> "$SETUP_LOG" 2>&1 || true
        fi

        # Run ddev poser: expands composer.json → composer.contrib.json (includes require-dev),
        # then runs composer install (installs Drupal + drush together), then removes composer.contrib.json
        # Retry up to 3 times to handle transient codeload.github.com 400s.
        _poser_ok=false
        for _attempt in 1 2 3; do
          log_setup "Running ddev poser (attempt $_attempt/3)..."
          update_status "⏳ ddev poser: Attempt $_attempt/3..."
          _t=$SECONDS
          if ddev poser >> "$SETUP_LOG" 2>&1; then
            log_setup "✓ ddev poser complete ($((SECONDS - _t))s)"
            update_status "✓ ddev poser: Success"
            # Hide the drush require-dev line from git status without touching the
            # file — git checkout would remove drush from composer.json and break
            # ddev restart (which rebuilds vendor/ from the restored file).
            git update-index --skip-worktree composer.json >> "$SETUP_LOG" 2>&1 || true
            _poser_ok=true
            break
          fi
          log_setup "✗ ddev poser attempt $_attempt failed ($((SECONDS - _t))s)"
          if [ "$_attempt" -lt 3 ]; then
            log_setup "Retrying in 15s..."
            sleep 15
          fi
        done
        if [ "$_poser_ok" = "false" ]; then
          update_status "✗ ddev poser: Failed"
          SETUP_FAILED=true
        fi

        if [ "$SETUP_FAILED" = "false" ]; then
          # Restart triggers ddev symlink-project automatically.
          # symlink-project creates web/modules/custom/<project> -> project root.
          # Without this symlink drush cannot discover the module.
          log_setup "Restarting DDEV to trigger symlink-project..."
          update_status "⏳ DDEV restart: In progress..."
          if ddev restart >> "$SETUP_LOG" 2>&1; then
            log_setup "✓ DDEV restarted"
            update_status "✓ DDEV restart: Success"
          else
            log_setup "✗ DDEV restart failed — trying stop + start..."
            update_status "⚠ DDEV restart: Retrying..."
            ddev stop >> "$SETUP_LOG" 2>&1 || true
            if ddev start >> "$SETUP_LOG" 2>&1; then
              log_setup "✓ DDEV started (after restart failure)"
              update_status "✓ DDEV restart: Success (via stop+start)"
            else
              log_setup "✗ DDEV start failed after restart failure"
              update_status "✗ DDEV restart: Failed"
              SETUP_FAILED=true
            fi
          fi
        fi

        if [ "$SETUP_FAILED" = "false" ]; then
          # Install Drupal
          INSTALL_PROFILE="${data.coder_parameter.install_profile.value}"
          log_setup "Installing Drupal ($INSTALL_PROFILE profile)..."
          update_status "⏳ Drupal install: In progress..."
          _t=$SECONDS
          if ddev drush si "$INSTALL_PROFILE" -y --account-pass=admin >> "$SETUP_LOG" 2>&1; then
            log_setup "✓ Drupal installed ($((SECONDS - _t))s)"
            update_status "✓ Drupal install: Success"
          else
            log_setup "✗ Drupal install failed ($((SECONDS - _t))s)"
            update_status "✗ Drupal install: Failed"
            SETUP_FAILED=true
          fi

          if [ "$SETUP_FAILED" = "false" ]; then
            # Enable the module or theme.
            # ddev drush en can exit non-zero even when the module ends up enabled
            # (e.g. a post-install hook in another module throws a fatal), so verify
            # via pm:list rather than trusting the exit code.
            log_setup "Enabling $PROJECT_NAME ($PROJECT_TYPE)..."
            if [ "$PROJECT_TYPE" = "theme" ]; then
              ddev drush theme:enable "$PROJECT_NAME" -y >> "$SETUP_LOG" 2>&1 || true
            else
              ddev drush en "$PROJECT_NAME" -y >> "$SETUP_LOG" 2>&1 || true
            fi
            if ddev drush pm:list --status=enabled --format=list 2>/dev/null | grep -qw "$PROJECT_NAME"; then
              log_setup "✓ $PROJECT_NAME enabled"
              update_status "✓ $PROJECT_NAME: Enabled"
            else
              log_setup "✗ $PROJECT_NAME not found in enabled modules — enable failed"
              update_status "✗ $PROJECT_NAME: Not enabled (check /tmp/drupal-setup.log)"
              SETUP_FAILED=true
            fi
          fi
        fi
      fi

      # Cache rebuild (always, on every start)
      log_setup "Running cache rebuild..."
      ddev drush cr >> "$SETUP_LOG" 2>&1 || true
    fi

    # ==========================================
    # Phase 6: Custom DDEV launch command
    # ==========================================
    mkdir -p ~/.ddev/commands/host
    cat > ~/.ddev/commands/host/launch << 'LAUNCH_EOF'
#!/usr/bin/env bash

## Description: Show Coder URLs for this Drupal contrib workspace
## Usage: launch [path] [-m|--mailpit]
## Example: "ddev launch" or "ddev launch /admin" or "ddev launch -m"
## Flags: [{"Name":"mailpit","Shorthand":"m","Usage":"ddev launch -m shows the Mailpit URL"}]

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
LAUNCH_EOF

    chmod +x ~/.ddev/commands/host/launch
    log_setup "✓ Custom DDEV launch command installed"

    # ==========================================
    # Phase 6.5: Write welcome message
    # ==========================================
    {
      echo "Drupal Contrib Development Workspace"
      echo "======================================"
      echo "Project: $PROJECT_NAME ($PROJECT_TYPE)"
      echo "Admin: admin / admin"
      echo ""
      echo "Commands:"
      echo "  ddev launch               # Show site URL and one-time login link"
      echo "  ddev describe             # Show project details and URLs"
      echo "  ddev drush status         # Check Drupal status"
      echo "  ddev phpunit              # Run PHPUnit tests"
      echo "  ddev phpcs                # Check coding standards"
      echo "  ddev phpstan              # Run static analysis"
      echo "  ddev logs                 # View container logs"
      echo "  ddev ssh                  # SSH into web container"
      echo ""
      echo "Docs: https://docs.ddev.com/"
      if [ -n "$ISSUE_FORK" ]; then
        echo ""
        ISSUE_LINE="Issue #$${ISSUE_FORK}"
        [ -n "$ISSUE_TITLE" ] && ISSUE_LINE="$ISSUE_LINE: $ISSUE_TITLE"
        echo "$ISSUE_LINE"
        echo "  https://www.drupal.org/project/$PROJECT_NAME/issues/$${ISSUE_FORK}"
      fi
    } > ~/WELCOME.txt
    chown coder:coder ~/WELCOME.txt 2>/dev/null || true

    # ==========================================
    # Shell environment setup
    # ==========================================
    mkdir -p ~/.npm-global
    npm config set prefix "~/.npm-global"
    export PATH="$HOME/.npm-global/bin:$PATH"
    if ! echo "$PATH" | grep -q "$HOME/.npm-global/bin"; then
      echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.bashrc
    fi

    if ! echo "$PATH" | grep -q "/home/linuxbrew/.linuxbrew/bin"; then
      echo 'export PATH="$PATH:/home/linuxbrew/.linuxbrew/bin"' >> ~/.bashrc
    fi

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

    if [ ! -f ~/.bash_profile ]; then
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
      cat >> ~/.bash_profile << 'BASHPROFILE_WELCOME'
# Display welcome message on SSH login (login shells only)
if [ -f ~/WELCOME.txt ]; then
  cat ~/WELCOME.txt
  echo ""
fi
BASHPROFILE_WELCOME
    fi
    if ! grep -q 'etc/bash.bashrc' ~/.bash_profile 2>/dev/null; then
      printf '\n# Source system-wide settings (bash_completion etc.) for login shells\nif [ -f /etc/bash.bashrc ]; then\n  . /etc/bash.bashrc\nfi\n' >> ~/.bash_profile
    fi

    # ==========================================
    # Timing summary and final status
    # ==========================================
    TOTAL_TIME=$((SECONDS - SCRIPT_START))
    INSTALL_TIME=$((SECONDS - SETUP_START))
    FAILURE_SUMMARY=$(grep "✗" "$SETUP_LOG" 2>/dev/null | grep -v "^$" | head -20 || true)

    update_status ""
    update_status "Completed: $(date)"
    update_status ""
    update_status "--- Timing ---"
    update_status "  ddev utility download-images: $${IMAGES_TIME}s"
    update_status "  Install phase:                $${INSTALL_TIME}s"
    update_status "  Total workspace startup:      $${TOTAL_TIME}s"
    update_status ""
    update_status "View full logs: $SETUP_LOG"

    if [ "$SETUP_FAILED" = "true" ]; then
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
      echo "$FAILURE_SUMMARY" | sed 's/^/  /'
      echo ""
      echo "Full log: cat $SETUP_LOG"
    else
      echo "=== Setup Complete ==="
      echo ""
      echo "⏱  Timing: images=$${IMAGES_TIME}s  install=$${INSTALL_TIME}s  total=$${TOTAL_TIME}s"
      echo ""
      echo "📁 $PROJECT_NAME ready at ~/~/$PROJECT_NAME"
      echo "📄 Welcome message saved to ~/WELCOME.txt"
      echo ""
    fi

    cat ~/WELCOME.txt
    echo ""

    exit 0
  EOT

  env = {
    CODER_AGENT_FORCE_UPDATE    = "1"
    CODER_WORKSPACE_ID          = data.coder_workspace.me.id
    CODER_WORKSPACE_NAME        = data.coder_workspace.me.name
    CODER_WORKSPACE_OWNER_NAME  = data.coder_workspace_owner.me.name
    CODER_WORKSPACE_OWNER_EMAIL = data.coder_workspace_owner.me.email
    HOME                        = "/home/coder"
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

# Persists /home/linuxbrew (Homebrew Cellar) across workspace stop/start so
# `brew upgrade`/`brew install` survives restarts. Not gated by start_count,
# matching coder_dind_cache above. Docker auto-populates a newly-created
# named volume from the image's existing directory contents on first mount,
# so no manual copy-from-image seed step is needed here.
resource "docker_volume" "coder_linuxbrew" {
  name = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}-linuxbrew"
}

module "vscode-web" {
  count          = data.coder_workspace.me.start_count
  source         = "registry.coder.com/coder/vscode-web/coder"
  version        = "~> 1.0"
  agent_id       = coder_agent.main.id
  folder         = "/home/coder/${data.coder_parameter.project_name.value}"
  accept_license = true
  order          = 2
  extensions     = local.selected_extensions
}

resource "coder_app" "ddev-web" {
  agent_id     = coder_agent.main.id
  slug         = "ddev-web"
  display_name = "DDEV Web"
  order        = 1
  url          = "http://localhost:8080"
  icon         = "https://raw.githubusercontent.com/ddev/ddev/main/docs/content/developers/logos/SVG/Logo.svg"
  subdomain    = true
  share        = "owner"

  healthcheck {
    url       = "http://localhost:8080"
    interval  = 10
    threshold = 30
  }
}

resource "coder_app" "drupal-site" {
  agent_id     = coder_agent.main.id
  slug         = "drupal-site"
  display_name = "Drupal Site"
  order        = 2
  url          = "http://localhost:8080"
  icon         = "https://api.iconify.design/heroicons:check-circle.svg?color=white"
  subdomain    = true
  share        = local.drupal_site_share

  healthcheck {
    url       = "http://localhost:8080/user/login"
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

resource "coder_script" "ddev_shutdown" {
  agent_id     = coder_agent.main.id
  display_name = "Stop DDEV Projects"
  icon         = "/icon/docker.svg"
  run_on_stop  = true
  script       = <<-EOT
    #!/bin/bash
    export PATH="$PATH:/home/linuxbrew/.linuxbrew/bin:/usr/local/bin"
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
  count     = data.coder_workspace.me.start_count
  image     = docker_image.workspace_image.image_id
  name      = "coder-${data.coder_workspace.me.id}"
  hostname  = "${data.coder_workspace.me.name}-${data.coder_workspace_owner.me.name}"
  user      = "coder"
  group_add = [tostring(var.docker_gid)]

  stop_timeout          = 180
  stop_signal           = "SIGINT"
  destroy_grace_seconds = 180

  working_dir = local.workspace_home

  cpu_shares = var.cpu * 1024
  memory     = var.memory * 1024 * 1024 * 1024

  runtime = "sysbox-runc"

  volumes {
    container_path = local.workspace_home
    host_path      = "/coder-workspaces/${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}"
    read_only      = false
  }

  mounts {
    type   = "volume"
    source = docker_volume.coder_dind_cache.name
    target = "/var/lib/docker"
  }

  mounts {
    type   = "volume"
    source = docker_volume.coder_linuxbrew.name
    target = "/home/linuxbrew"
  }

  env = [
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
    "CODER_WORKSPACE_NAME=${data.coder_workspace.me.name}",
    "ELECTRON_DISABLE_SANDBOX=1",
    "ELECTRON_NO_SANDBOX=1",
    "GITHUB_TOKEN=${var.github_token}",
  ]

  command = ["sh", "-c", coder_agent.main.init_script]

  depends_on = [null_resource.workspace_cleanup]

  restart = "unless-stopped"

  security_opts = [
    "apparmor:unconfined",
    "seccomp:unconfined"
  ]

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
    value = "Drupal Contrib Development"
  }
  item {
    key   = "project"
    value = "${data.coder_parameter.project_name.value} (${data.coder_parameter.project_type.value})"
  }
  item {
    key   = "project_location"
    value = "/home/coder/${data.coder_parameter.project_name.value}"
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
    value = local.issue_fork != "" ? "#${local.issue_fork}" : "(standard workspace)"
  }
  item {
    key   = "issue_url"
    value = local.issue_url
  }
}
