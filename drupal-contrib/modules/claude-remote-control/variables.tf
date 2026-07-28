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
