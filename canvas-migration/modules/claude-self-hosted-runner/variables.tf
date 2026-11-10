variable "parameter_order" {
  description = "Base UI order for the two coder_parameters this module declares (uses this value and this value + 1)"
  type        = number
  default     = 14
}

variable "base_dir" {
  description = "Directory the runner clones session repositories into"
  type        = string
  default     = "/home/coder/workspace"
}

variable "remote_control_enabled" {
  description = "Whether Claude Code remote control is enabled in the same workspace; the runner refuses to start alongside it"
  type        = bool
  default     = false
}
