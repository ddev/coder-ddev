variable "agent_id" {
  description = "ID of the coder_agent to attach the Docker daemon shutdown script to"
  type        = string
}

variable "docker_registry_mirror" {
  description = "Optional Docker registry mirror URL override (e.g. http://your-host:5000). When empty, startup auto-detects a mirror at http://<coder-host>:5000 if reachable."
  type        = string
  default     = ""
}
