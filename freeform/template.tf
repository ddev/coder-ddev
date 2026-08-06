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
  description = "Username for Docker registry authentication"
  type        = string
  default     = ""
  sensitive   = true
}

variable "registry_password" {
  description = "Password/Token for Docker registry authentication"
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

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

# Per-workspace user parameters (shown in workspace creation UI)
data "coder_parameter" "project_names" {
  name         = "project_names"
  display_name = "DDEV project names"
  description  = "Comma-separated DDEV project names. Each gets its own app button and URL. The DDEV project name must match exactly (case-sensitive). Single project: leave as default (workspace name)."
  type         = "string"
  default      = ""
  mutable      = true
  order        = 1
}

data "coder_parameter" "vscode_extensions" {
  name         = "vscode_extensions"
  display_name = "VS Code Extensions"
  description  = "Select extensions to enable in VS Code for Web"
  type         = "list(string)"
  form_type    = "multi-select"
  default      = jsonencode([for e in local.vscode_extensions : e.id if e.default])
  mutable      = true
  order        = 100

  dynamic "option" {
    for_each = local.vscode_extensions
    content {
      name  = option.value.name
      value = option.value.id
    }
  }
}

locals {
  workspace_home      = "/home/coder"
  selected_extensions = jsondecode(data.coder_parameter.vscode_extensions.value)
  image_version       = var.image_version

  registry_without_version      = replace(var.workspace_image_registry, ":${local.image_version}", "")
  workspace_image_registry_base = replace(local.registry_without_version, ":latest", "")

  # Parse project names from the coder_parameter. Fall back to workspace name when
  # the value is empty or "[]" (the latter comes from the mock in Terraform tests).
  _project_names_raw = trimspace(data.coder_parameter.project_names.value)
  project_names = (
    local._project_names_raw != "" && local._project_names_raw != "[]"
    ? [for s in split(",", local._project_names_raw) : trimspace(s) if trimspace(s) != ""]
    : [data.coder_workspace.me.name]
  )
}

variable "workspace_image_registry" {
  description = "Docker registry URL for the workspace base image (without tag)"
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

variable "enable_adminer" {
  description = "Show Adminer database UI app button (requires: ddev get ddev/ddev-adminer)"
  type        = bool
  default     = false
}

resource "coder_agent" "main" {
  arch = "amd64"
  os   = "linux"
  dir  = "${local.workspace_home}/${data.coder_workspace.me.name}"

  shutdown_script = <<EOT
    echo "Stopping DDEV"
    ddev poweroff || true
  EOT

  startup_script = <<-EOT
    #!/bin/bash
    set -euo pipefail

    echo "Startup script started..."

    if command -v sudo > /dev/null 2>&1; then
      SUDO="sudo"
    else
      SUDO=""
    fi

    sudo chown coder:coder /home/coder
    sudo chown -R coder:coder /home/linuxbrew

    # If ~/.bashrc is already a symlink resolving outside $HOME (e.g. a
    # dotfiles repo checked out under $HOME), replace it with a real file
    # that sources the original target before the exports below get
    # appended. Every append/sed step further down writes straight through
    # symlinks, so a live symlink here would silently edit tracked files in
    # a developer's dotfiles repo instead of this workspace's local shell
    # config -- that happened once already.
    if [ -L "/home/coder/.bashrc" ]; then
      _bashrc_target=$(readlink -f "/home/coder/.bashrc" 2>/dev/null || true)
      case "$_bashrc_target" in
        /home/coder/*) ;; # resolves inside $HOME, safe to write through
        *)
          echo "~/.bashrc is a symlink to $_bashrc_target (outside \$HOME); replacing with a local file that sources it"
          rm -f "/home/coder/.bashrc"
          if [ -n "$_bashrc_target" ]; then
            echo "[ -r \"$_bashrc_target\" ] && source \"$_bashrc_target\"" > "/home/coder/.bashrc"
          fi
          ;;
      esac
    fi

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
    if [ -z "$GIT_SSH_COMMAND" ]; then
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
    if [ -n "$CODER_WORKSPACE_OWNER_NAME" ]; then
      git config --global user.name "$CODER_WORKSPACE_OWNER_NAME"
    fi
    if [ -n "$CODER_WORKSPACE_OWNER_EMAIL" ]; then
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
    # Use printenv to avoid $${!var} indirect expansion which Terraform parses.
    for _var in CODER_AGENT_URL VSCODE_PROXY_URI CODER_WORKSPACE_NAME CODER_WORKSPACE_OWNER_NAME CODER_WORKSPACE_OWNER_EMAIL CODER_PROJECT_NAMES; do
      _val=$(printenv "$_var" 2>/dev/null || true)
      if [ -n "$_val" ]; then
        sed -i "/^export $_var=/d" ~/.bashrc || true
        echo "export $_var=$_val" >> ~/.bashrc
      fi
    done

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

    # Pre-pull DDEV images (uses registry mirror if configured). Redirect --
    # non-TTY docker pull progress prints a new line per layer per tick
    # (often written to stderr), so unredirected this alone was 95% of a
    # workspace's entire startup log.
    echo "Pre-pulling DDEV images..."
    _t_images=$SECONDS
    if ddev utility download-images > /tmp/ddev-download-images.log 2>&1; then
      echo "✓ DDEV images ready ($((SECONDS - _t_images))s)"
    else
      echo "⚠ ddev utility download-images failed (see /tmp/ddev-download-images.log)"
      tail -20 /tmp/ddev-download-images.log || true
    fi

    # Install DDEV mkcert CA
    mkcert -install 2>/dev/null || true


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

    ${module.claude_remote_control.startup_script}

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
  EOT

  env = {
    CODER_AGENT_FORCE_UPDATE    = "1"
    CODER_WORKSPACE_ID          = data.coder_workspace.me.id
    CODER_WORKSPACE_NAME        = data.coder_workspace.me.name
    CODER_WORKSPACE_OWNER_NAME  = data.coder_workspace_owner.me.name
    CODER_WORKSPACE_OWNER_EMAIL = data.coder_workspace_owner.me.email
    CODER_PROJECT_NAMES         = join(",", local.project_names)
    HOME                        = "/home/coder"
    # Silences Node's runtime deprecation warnings (e.g. url.parse()) that
    # code-server prints once per extension during VS Code Web's install step.
    NODE_NO_WARNINGS = "1"
  }

  metadata {
    display_name = "Coder DDEV Single-Project"
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
  folder         = "/home/coder/${data.coder_workspace.me.name}"
  accept_license = true
  order          = 2
  extensions     = local.selected_extensions
}

module "claude_remote_control" {
  source   = "./modules/claude-remote-control"
  agent_id = coder_agent.main.id
}

# One coder_app per project name. All route to ddev-router on port 8080.
# ddev-router dispatches by Host header: {slug}--{workspace}--{owner}.{domain}
# The DDEV project name must equal the slug for coder-routes to build the correct rule.
resource "coder_app" "ddev_web" {
  for_each     = toset(local.project_names)
  agent_id     = coder_agent.main.id
  slug         = each.key
  display_name = each.key
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

# Mailpit runs inside the web container at port 8025.
# DDEV service: {project}-web-8025 (from HTTP_EXPOSE=...,{mailpit_port}:8025 on the web container).
# One app per project so each gets its own subdomain: mailpit-{project}--{workspace}--{owner}.domain
resource "coder_app" "mailpit" {
  for_each     = toset(local.project_names)
  agent_id     = coder_agent.main.id
  slug         = "mailpit-${each.key}"
  display_name = "Mailpit (${each.key})"
  url          = "http://localhost:8025"
  icon         = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/mailpit.svg"
  subdomain    = true
  share        = "owner"

  healthcheck {
    url       = "http://localhost:8025"
    interval  = 10
    threshold = 30
  }
}

# xhgui is always present in the image (not an add-on). One app per project.
resource "coder_app" "xhgui" {
  for_each     = toset(local.project_names)
  agent_id     = coder_agent.main.id
  slug         = "xhgui-${each.key}"
  display_name = "xhgui (${each.key})"
  url          = "http://localhost:8143"
  icon         = "/icon/speedometer.svg"
  subdomain    = true
  share        = "owner"
}

# Adminer: optional database admin UI (enable_adminer variable). One app per project.
# HTTP_EXPOSE=9100:8080 → ddev-router port 9100 → adminer container port 8080.
resource "coder_app" "adminer" {
  for_each     = var.enable_adminer ? toset(local.project_names) : toset([])
  agent_id     = coder_agent.main.id
  slug         = "adminer-${each.key}"
  display_name = "Adminer (${each.key})"
  url          = "http://localhost:9100"
  icon         = "/icon/database.svg"
  subdomain    = true
  share        = "owner"

  healthcheck {
    url       = "http://localhost:9100"
    interval  = 10
    threshold = 30
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
  count                 = data.coder_workspace.me.start_count
  image                 = docker_image.workspace_image.image_id
  name                  = "coder-${data.coder_workspace.me.id}"
  hostname              = "${data.coder_workspace.me.name}-${data.coder_workspace_owner.me.name}"
  user                  = "coder"
  group_add             = [tostring(var.docker_gid)]
  stop_timeout          = 180
  stop_signal           = "SIGINT"
  destroy_grace_seconds = 60
  working_dir           = local.workspace_home
  cpu_shares            = var.cpu * 1024
  memory                = var.memory * 1024 * 1024 * 1024
  runtime               = "sysbox-runc"

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
  ]

  command = ["sh", "-c", coder_agent.main.init_script]
  restart = "unless-stopped"

  security_opts = [
    "apparmor:unconfined",
    "seccomp:unconfined"
  ]

  privileged = false

  depends_on = [null_resource.workspace_cleanup]
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
    key   = "image"
    value = "${docker_image.workspace_image.name} (version: ${local.image_version})"
  }
  item {
    key   = "ddev_projects"
    value = join(", ", local.project_names)
  }
  item {
    key   = "cpu"
    value = "${var.cpu} vCPU (soft limit)"
  }
  item {
    key   = "memory"
    value = "${var.memory} GB"
  }
}
