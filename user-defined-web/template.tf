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



# Workspace data source
data "coder_workspace" "me" {}

# Workspace owner data source (Coder v2+)
data "coder_workspace_owner" "me" {}
# Per-workspace user parameters (shown in workspace creation UI)
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



# Extract repository name from Git URL for folder path

# Example: https://gitlab.example.com/group/my-project.git -> my-project
# Example: git@gitlab.example.com:group/my-project.git -> my-project
locals {
  # Determine workspace home path
  # Sysbox Strategy: Use standard /home/coder
  workspace_home      = "/home/coder"
  selected_extensions = jsondecode(data.coder_parameter.vscode_extensions.value)
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

  # Ensure agent starts in the correct directory (Direct Mount Strategy)
  # IMPORTANT: Must use workspace_home (which exists) not workspace_folder (repo) 
  # because the repo might not exist yet when agent starts!
  dir = local.workspace_home

  shutdown_script = <<EOT
    echo "Stopping DDEV"
    ddev poweroff || true
  EOT

  startup_script = file("${path.module}/../scripts/templates/user-defined-web/startup.sh")

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
    # Injected for scripts/templates/user-defined-web/startup.sh
    REGISTRY_MIRROR = var.docker_registry_mirror
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
  folder         = "/home/coder"
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
  destroy_grace_seconds = 60


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
    key   = "image"
    value = "${docker_image.workspace_image.name} (version: ${local.image_version})"
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

# Output for Vault integration status (visible in Terraform logs)



