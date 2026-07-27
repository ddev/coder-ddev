data "coder_parameter" "enable_claude_code" {
  name         = "enable_claude_code"
  display_name = "Enable Claude Code remote control"
  description  = <<-EOT
    Control Claude Code in this workspace from claude.ai/code or the Claude mobile app.

    **First use:** open the "Claude Code" app button (or SSH into the workspace) and complete the one-time Claude login plus the workspace-trust prompt.

    **Work in a project directory:** Claude starts in `$HOME`. From any terminal, `cd` into your project and run `claude-here` to bring Claude there — no re-login needed, just a one-time trust prompt for that directory. This replaces the current conversation.

    Requires a Claude Pro/Max/Team/Enterprise subscription (API-key auth is not supported); does not work with Bedrock/Vertex/a custom gateway. Remote sessions disconnect after ~10 minutes offline.
  EOT

  type      = "bool"
  form_type = "switch"
  default   = "false"
  mutable   = true
  order     = var.parameter_order
}

data "coder_parameter" "claude_code_skip_permissions" {
  name         = "claude_code_skip_permissions"
  display_name = "Claude Code: skip permission prompts"
  description  = "Pass --dangerously-skip-permissions. Only takes effect when remote control is enabled."
  type         = "bool"
  form_type    = "switch"
  default      = "false"
  mutable      = true
  order        = var.parameter_order + 1
}

locals {
  # Deliberately compared as strings, not tobool(): the blanket coder_parameter
  # mock in callers' tests defaults every parameter's value to "[]", which
  # tobool() would reject outright.
  enabled          = data.coder_parameter.enable_claude_code.value == "true"
  skip_permissions = data.coder_parameter.claude_code_skip_permissions.value == "true"
  remote_cmd = join(" ", compact([
    "claude", "--remote-control", "$CODER_WORKSPACE_NAME",
    local.skip_permissions ? "--dangerously-skip-permissions" : "",
  ]))
}

# Terminal-tab fallback for first login/troubleshooting. The primary intended
# usage is connecting from claude.ai/code or the mobile app to the named tmux
# session started by the caller's startup script, not this button.
resource "coder_app" "claude_code" {
  count        = local.enabled ? 1 : 0
  agent_id     = var.agent_id
  slug         = "claude-code"
  display_name = "Claude Code"
  command      = "tmux attach -t \"$CODER_WORKSPACE_NAME:0\" || tmux new-session -A -s \"$CODER_WORKSPACE_NAME\""
  order        = var.app_order
}
