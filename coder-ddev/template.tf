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
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

provider "docker" {
  host = var.docker_host

  # Registry authentication (supports Docker Hub, GitLab, GitHub Container Registry, etc.)
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

variable "image" {
  description = "Base image for the workspace"
  type        = string
  default     = "ubuntu:24.04"
}

variable "registry_username" {
  description = "Username for container registry authentication"
  type        = string
  default     = ""
  sensitive   = true
}

variable "registry_password" {
  description = "Password/Token for container registry authentication"
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
data "coder_workspace_owner" "me" {}

# Task metadata - makes this template task-capable
data "coder_task" "me" {}

locals {
  # Determine workspace home path
  # Sysbox Strategy: Use standard /home/coder
  workspace_home = "/home/coder"

  # Read image version from VERSION file if it exists, otherwise use variable default
  image_version = try(trimspace(file("${path.module}/VERSION")), var.image_version)
}

variable "workspace_image_registry" {
  description = "Docker registry URL for the workspace base image (without tag, version is added automatically)"
  type        = string
  # Image from container registry
  # Requires registry_username and registry_password variables for authentication
  # The version tag is appended automatically from VERSION file
  # DO NOT include :latest or any version tag here - version is read from VERSION file or variable
  default = "index.docker.io/randyfay/coder-ddev"
}

# Local variable to ensure registry URL doesn't have any tag
# Remove any tag (including :latest) if present, but preserve port numbers (e.g., :5050)
locals {
  # Remove common tags from the end of the registry URL
  # First remove the current version tag, then remove :latest
  # This handles cases where old configs might still have :latest or version tags
  # Note: We can't use regex, so we handle the most common cases
  registry_without_version      = replace(var.workspace_image_registry, ":${local.image_version}", "")
  workspace_image_registry_base = replace(local.registry_without_version, ":latest", "")
}

# Use pre-built image from container registry
# The image is built and pushed by CI/CD pipeline
# This avoids prevent_destroy issues since the image is not managed by Terraform
# NOTE: Authentication may be required via registry_username and registry_password variables
resource "docker_image" "workspace_image" {
  # Always use version tag (never :latest) - version is read from VERSION file or variable
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

variable "node_version" {
  description = "Node.js version to install"
  type        = string
  default     = "20"
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

  # Ensure agent starts in the correct directory (Direct Mount Strategy)
  # IMPORTANT: Must use workspace_home (which exists) not workspace_folder (repo)
  # because the repo might not exist yet when agent starts!
  dir = local.workspace_home

  # Load startup script from external file for better maintainability
  startup_script = file("${path.module}/scripts/startup.sh")

  env = {
    # Force agent updates to this version for compatibility
    # Increment this when agent protocol changes require updates
    # Current version: 35 (required for Coder v2.13+)
    CODER_AGENT_FORCE_UPDATE = "35"

    # Force HOME to /home/coder (Standard Home Strategy)
    HOME = "/home/coder"
  }

  metadata {
    display_name = "CPU Usage"
    key          = "cpu"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Memory Usage"
    key          = "mem"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Docker Containers"
    key          = "docker_containers"
    script       = "docker ps --format '{{.Names}}' 2>/dev/null | wc -l || echo '0'"
    interval     = 30
    timeout      = 5
  }

  metadata {
    display_name = "DDEV Projects"
    key          = "ddev_projects"
    script       = "ddev list --json-output 2>/dev/null | jq -r 'length' || echo '0'"
    interval     = 60
    timeout      = 5
  }
}

# VS Code for Web
module "vscode-web" {
  count          = data.coder_workspace.me.start_count
  source         = "registry.coder.com/coder/vscode-web/coder"
  version        = "1.0.20"
  agent_id       = coder_agent.main.id
  folder         = "/home/coder"
  accept_license = true
}

# DDEV Web Server (HTTP) - appears when DDEV project is running
# Uses web container's direct HTTP port (8080) as configured in DDEV global_config.yaml
resource "coder_app" "ddev-web" {
  agent_id     = coder_agent.main.id
  slug         = "ddev-web"
  display_name = "DDEV Web"
  url          = "http://localhost:8080"
  icon         = "/icon/globe.svg"
  subdomain    = true
  share        = "owner"

  healthcheck {
    url       = "http://localhost:8080"
    interval  = 10
    threshold = 30
  }
}

# Mailpit (DDEV email catcher)
# Uses Mailpit's HTTP port (8025) inside the workspace container
resource "coder_app" "mailpit" {
  agent_id     = coder_agent.main.id
  slug         = "mailpit"
  display_name = "Mailpit"
  url          = "http://localhost:8025"
  icon         = "/icon/mail.svg"
  subdomain    = false
  share        = "owner"

  healthcheck {
    url       = "http://localhost:8025"
    interval  = 10
    threshold = 30
  }
}

# Graceful DDEV shutdown when workspace stops
resource "coder_script" "ddev_shutdown" {
  agent_id     = coder_agent.main.id
  display_name = "Stop DDEV Projects"
  icon         = "/icon/docker.svg"
  run_on_stop  = true
  script       = <<-EOT
    #!/bin/bash
    echo "Stopping all DDEV projects gracefully..."
    if command -v ddev > /dev/null 2>&1; then
      ddev poweroff || true
      echo "DDEV projects stopped"
    fi
  EOT
}

resource "docker_volume" "coder_dind_cache" {
  name = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}-dind-cache"
}

module "coder-login" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/coder-login/coder"
  version  = "1.0.31"
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

  # Increase stop_timeout to allow graceful DDEV shutdown
  # Default is usually 10s, which is not enough for ddev poweroff
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
  # This ensures isolation between workspaces while allowing persistent storage
  volumes {
    container_path = local.workspace_home
    host_path      = "/home/coder/workspaces/${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}"
    read_only      = false
  }

  # Docker-in-Docker cache volume
  # Persists /var/lib/docker across workspace restarts for faster container startup
  mounts {
    type   = "volume"
    source = docker_volume.coder_dind_cache.name
    target = "/var/lib/docker"
  }

  # Environment variables
  # Note: CODER_WORKSPACE_ID, CODER_WORKSPACE_NAME set by agent env, not duplicated here
  env = [
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
    "ELECTRON_DISABLE_SANDBOX=1",
    "ELECTRON_NO_SANDBOX=1",
  ]

  # Command to keep container running
  command = ["sh", "-c", coder_agent.main.init_script]

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

# Workspace cleanup after destroy
# Note: Terraform destroy provisioners are problematic with the Docker provider
# Alternatives for implementing cleanup:
# 1. Coder workspace lifecycle hooks (coder_script resource with run_on_stop)
# 2. External cleanup script triggered by Coder events or webhooks
# 3. Manual cleanup command: docker exec coder-{workspace-id} ddev poweroff
# 4. Host-level cleanup cronjob to remove orphaned volumes/containers
#
# Current implementation: Using coder_script.ddev_shutdown resource above

resource "coder_metadata" "workspace_info" {
  resource_id = docker_container.workspace[0].id
  count       = data.coder_workspace.me.start_count

  item {
    key   = "image"
    value = "${docker_image.workspace_image.name} (version: ${local.image_version})"
  }
  item {
    key   = "node_version"
    value = var.node_version
  }
  item {
    key   = "cpu"
    value = "${var.cpu} cores"
  }
  item {
    key   = "memory"
    value = "${var.memory} GB"
  }
}
