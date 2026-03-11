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

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

locals {
  workspace_home = "/home/coder"
  image_version  = try(trimspace(file("${path.module}/VERSION")), var.image_version)

  registry_without_version      = replace(var.workspace_image_registry, ":${local.image_version}", "")
  workspace_image_registry_base = replace(local.registry_without_version, ":latest", "")
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
    set +e

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
    for _var in VSCODE_PROXY_URI CODER_WORKSPACE_NAME CODER_WORKSPACE_OWNER_NAME CODER_WORKSPACE_OWNER_EMAIL; do
      _val=$(printenv "$_var" 2>/dev/null || true)
      if [ -n "$_val" ]; then
        sed -i "/^export $_var=/d" ~/.bashrc || true
        echo "export $_var=$_val" >> ~/.bashrc
      fi
    done

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

    # Create .ddev directory (DDEV creates global_config.yaml on first use)
    mkdir -p ~/.ddev/commands/host
    if [ -d /home/coder-files/.ddev/commands/host ]; then
      cp -f /home/coder-files/.ddev/commands/host/* ~/.ddev/commands/host/
      chmod 755 ~/.ddev/commands/host/*
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
    npm config set prefix "~/.npm-global"
    export PATH="$HOME/.npm-global/bin:$PATH"
    if ! grep -q "\.npm-global/bin" ~/.bashrc; then
      echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.bashrc
    fi

    echo ""
    echo "=== Setup Complete ==="
    echo ""
    echo "Next steps:"
    echo "  1. Clone or create your project:"
    echo "       git clone <repo-url> ~/myproject"
    echo "       cd ~/myproject"
    echo "  2. Configure DDEV:"
    echo "       ddev config --project-type=<type>"
    echo "  3. Install Coder routing hook (once per project):"
    echo "       ddev coder-setup"
    echo "  4. Start DDEV:"
    echo "       ddev start"
    echo ""
    exit 0
  EOT

  env = {
    CODER_AGENT_FORCE_UPDATE   = "1"
    CODER_WORKSPACE_ID         = data.coder_workspace.me.id
    CODER_WORKSPACE_NAME       = data.coder_workspace.me.name
    CODER_WORKSPACE_OWNER_NAME  = data.coder_workspace_owner.me.name
    CODER_WORKSPACE_OWNER_EMAIL = data.coder_workspace_owner.me.email
    HOME                        = "/home/coder"
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

module "vscode-web" {
  count          = data.coder_workspace.me.start_count
  source         = "registry.coder.com/coder/vscode-web/coder"
  version        = "~> 1.0"
  agent_id       = coder_agent.main.id
  folder         = "/home/coder/${data.coder_workspace.me.name}"
  accept_license = true
  order          = 2
  extensions     = [
    "xdebug.php-debug",
    "bmewburn.vscode-intelephense-client",
    "dbaeumer.vscode-eslint",
    "esbenp.prettier-vscode",
    "sanderronde.phpstan-vscode",
    "streetsidesoftware.code-spell-checker",
    "stylelint.vscode-stylelint",
    "valeryanm.vscode-phpsab",
    "biati.ddev-manager",
  ]
}

# Slug matches the workspace name, which is also the DDEV project name.
# Coder subdomain URL: {workspace_name}--{workspace_name}--{owner}.{domain}
# Traefik rule in coder-routes.yaml matches this exact host.
resource "coder_app" "ddev-web" {
  agent_id     = coder_agent.main.id
  slug         = data.coder_workspace.me.name
  display_name = "DDEV Web"
  order        = 1
  url          = "http://localhost:80"
  icon         = "https://raw.githubusercontent.com/ddev/ddev/main/docs/content/developers/logos/SVG/Logo.svg"
  subdomain    = true
  share        = "owner"

  healthcheck {
    url       = "http://localhost:80"
    interval  = 10
    threshold = 30
  }
}

# Mailpit runs inside the web container at port 8025.
# DDEV service: {project}-web-8025 (from HTTP_EXPOSE=...,{mailpit_port}:8025 on the web container).
resource "coder_app" "mailpit" {
  agent_id     = coder_agent.main.id
  slug         = "mailpit"
  display_name = "Mailpit"
  url          = "http://localhost:8025"
  icon         = "/icon/mailhog.svg"
  subdomain    = true
  share        = "owner"

  healthcheck {
    url       = "http://localhost:8025"
    interval  = 10
    threshold = 30
  }
}

# Adminer: database admin UI added by ddev get ddev/ddev-adminer.
# HTTP_EXPOSE=9100:8080 → ddev-router port 9100 → adminer container port 8080.
# coder-routes post-start hook adds the Traefik router automatically.
resource "coder_app" "adminer" {
  count        = var.enable_adminer ? 1 : 0
  agent_id     = coder_agent.main.id
  slug         = "adminer"
  display_name = "Adminer"
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
  count        = data.coder_workspace.me.start_count
  image        = docker_image.workspace_image.image_id
  name         = "coder-${data.coder_workspace.me.id}"
  hostname     = "${data.coder_workspace.me.name}-${data.coder_workspace_owner.me.name}"
  user         = "coder"
  group_add    = [tostring(var.docker_gid)]
  stop_timeout = 180
  stop_signal  = "SIGINT"
  destroy_grace_seconds = 60
  working_dir  = local.workspace_home
  cpu_shares   = var.cpu * 1024
  memory       = var.memory * 1024 * 1024 * 1024
  runtime      = "sysbox-runc"

  volumes {
    container_path = local.workspace_home
    host_path      = "/home/coder/workspaces/${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}"
    read_only      = false
  }

  mounts {
    type   = "volume"
    source = docker_volume.coder_dind_cache.name
    target = "/var/lib/docker"
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
}

resource "coder_metadata" "workspace_info" {
  resource_id = docker_container.workspace[0].id
  count       = data.coder_workspace.me.start_count

  item {
    key   = "image"
    value = "${docker_image.workspace_image.name} (version: ${local.image_version})"
  }
  item {
    key   = "ddev_project_name"
    value = data.coder_workspace.me.name
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
