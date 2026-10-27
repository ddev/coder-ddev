data "coder_parameter" "enable_claude_runner" {
  name         = "enable_claude_runner"
  display_name = "Run a Claude Code self-hosted runner"
  description  = <<-EOT
    Start a Claude Code self-hosted runner on every workspace start, so sessions you start on claude.ai/code in that environment run in this workspace.

    **One-time setup:** create a self-hosted environment on claude.ai, then save its environment secret in the workspace as `~/.claude-runner/environment-secret` (mode 600). Until that file exists, the runner doesn't start and the startup log says why.

    **Use a workspace dedicated to the runner.** The runner deletes and rewrites `~/.gitconfig` and `~/.config/git` before every session. It can't be enabled together with Claude Code remote control.
  EOT

  type      = "bool"
  form_type = "switch"
  default   = "false"
  mutable   = true
  order     = var.parameter_order
}

data "coder_parameter" "claude_runner_capacity" {
  name         = "claude_runner_capacity"
  display_name = "Claude Code runner: concurrent sessions"
  description  = "How many sessions the runner hosts at once. They share this workspace's Docker daemon and DDEV; the runner installs a skill telling them how to avoid conflicts. Only takes effect when the runner is enabled."
  type         = "number"
  default      = "1"
  mutable      = true
  order        = var.parameter_order + 1
  validation {
    min = 1
    max = 4
  }
}

locals {
  # Compared as strings, not tobool(): see modules/claude-remote-control.
  enabled     = data.coder_parameter.enable_claude_runner.value == "true"
  capacity    = try(tonumber(data.coder_parameter.claude_runner_capacity.value), 1)
  secret_file = "/home/coder/.claude-runner/environment-secret"

  loop_script = templatefile("${path.module}/files/claude-runner-loop.sh.tftpl", {
    secret_file = local.secret_file
    base_dir    = var.base_dir
    capacity    = local.capacity
  })
}
