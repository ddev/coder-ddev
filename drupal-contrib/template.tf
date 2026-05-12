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

  startup_script = file("${path.module}/../scripts/templates/drupal-contrib/startup.sh")

  env = {
    CODER_AGENT_FORCE_UPDATE    = "1"
    CODER_WORKSPACE_ID          = data.coder_workspace.me.id
    CODER_WORKSPACE_NAME        = data.coder_workspace.me.name
    CODER_WORKSPACE_OWNER_NAME  = data.coder_workspace_owner.me.name
    CODER_WORKSPACE_OWNER_EMAIL = data.coder_workspace_owner.me.email
    HOME                        = "/home/coder"
    REGISTRY_MIRROR             = var.docker_registry_mirror
    PROJECT_NAME                = data.coder_parameter.project_name.value
    PROJECT_TYPE                = data.coder_parameter.project_type.value
    ISSUE_FORK                  = data.coder_parameter.issue_fork.value
    ISSUE_BRANCH                = data.coder_parameter.issue_branch.value
    DRUPAL_VERSION              = data.coder_parameter.drupal_version.value
    INSTALL_PROFILE             = data.coder_parameter.install_profile.value
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

  env = [
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
    "CODER_WORKSPACE_NAME=${data.coder_workspace.me.name}",
    "ELECTRON_DISABLE_SANDBOX=1",
    "ELECTRON_NO_SANDBOX=1",
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
