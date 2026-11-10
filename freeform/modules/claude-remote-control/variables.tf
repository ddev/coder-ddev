variable "agent_id" {
  description = "ID of the coder_agent to attach the Claude Code fallback terminal app to"
  type        = string
}

variable "parameter_order" {
  description = "Base UI order for the two coder_parameters this module declares (uses this value and this value + 1)"
  type        = number
  default     = 10
}

variable "app_order" {
  description = "UI order for the fallback terminal coder_app"
  type        = number
  default     = 12
}

variable "default_enabled" {
  description = "Default value of the \"Enable Claude Code remote control\" parameter"
  type        = bool
  default     = false
}

variable "default_skip_permissions" {
  description = "Default value of the \"skip permission prompts\" parameter"
  type        = bool
  default     = false
}

variable "project_directory" {
  description = "Directory the remote-control session starts in. Shell variables such as $HOME are expanded when tmux starts the session."
  type        = string
  default     = "$HOME"
}

variable "launch_script" {
  description = "Optional script content to run in the remote-control pane instead of the default claude command. It runs with SSH_AUTH_SOCK, CLAUDE_EXTRA_FLAGS and the agent environment set, and must exec claude itself. Empty runs the default command."
  type        = string
  default     = ""
}
