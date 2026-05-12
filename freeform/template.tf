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

locals {
  workspace_home      = "/home/coder"
  selected_extensions = jsondecode(data.coder_parameter.vscode_extensions.value)
  image_version       = try(trimspace(file("${path.module}/VERSION")), var.image_version)

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

  startup_script = file("${path.module}/../scripts/templates/freeform/startup.sh")

  env = {
    CODER_AGENT_FORCE_UPDATE    = "1"
    CODER_WORKSPACE_ID          = data.coder_workspace.me.id
    CODER_WORKSPACE_NAME        = data.coder_workspace.me.name
    CODER_WORKSPACE_OWNER_NAME  = data.coder_workspace_owner.me.name
    CODER_WORKSPACE_OWNER_EMAIL = data.coder_workspace_owner.me.email
    CODER_PROJECT_NAMES         = join(",", local.project_names)
    HOME                        = "/home/coder"
    REGISTRY_MIRROR             = var.docker_registry_mirror
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
  extensions     = local.selected_extensions
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
