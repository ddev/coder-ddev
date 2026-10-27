output "enabled" {
  description = "Whether the Claude Code self-hosted runner is enabled"
  value       = local.enabled
}

output "startup_script" {
  description = "Bash snippet for the caller to append to its coder_agent startup_script, after the claude-remote-control snippet and before the ~/.coder-startup.sh user hook."
  value       = <<-EOT

    # Claude Code self-hosted runner, in tmux session "claude-runner".
    CLAUDE_RUNNER_ENABLED="${local.enabled}"
    CLAUDE_REMOTE_CONTROL_ENABLED="${var.remote_control_enabled}"
    if [ "$CLAUDE_RUNNER_ENABLED" = "true" ]; then
      if [ "$CLAUDE_REMOTE_CONTROL_ENABLED" = "true" ]; then
        CLAUDE_RUNNER_MSG="✗ Claude Code self-hosted runner NOT started: Claude Code remote control is also enabled, and the runner rewrites ~/.gitconfig before every session. Turn one of them off."
      elif [ ! -s "${local.secret_file}" ]; then
        CLAUDE_RUNNER_MSG="✗ Claude Code self-hosted runner NOT started: save your environment secret as ${local.secret_file} (chmod 600), then restart the workspace."
      else
        # /etc is not persistent, so reinstall the session git config on every start.
        echo '${base64encode(file("${path.module}/files/gitconfig"))}' | base64 -d | sudo tee /etc/gitconfig >/dev/null
        echo '${base64encode(file("${path.module}/files/gitignore"))}' | base64 -d | sudo tee /etc/gitignore-claude-runner >/dev/null
        # The runner copies ~/.claude into each session when it starts.
        mkdir -p ~/.claude/skills/coder-shared-workspace ~/.cache "${var.base_dir}"
        echo '${base64encode(file("${path.module}/files/SKILL.md"))}' | base64 -d > ~/.claude/skills/coder-shared-workspace/SKILL.md
        mkdir -p ~/.local/bin
        echo '${base64encode(local.loop_script)}' | base64 -d > ~/.local/bin/claude-runner-loop
        chmod +x ~/.local/bin/claude-runner-loop
        echo '${base64encode(file("${path.module}/files/claude-sessions"))}' | base64 -d > ~/.local/bin/claude-sessions
        chmod +x ~/.local/bin/claude-sessions
        mkcert -install >/dev/null 2>&1 || true
        # Anchored on the program name: this script's own bash command line contains the phrase.
        if pgrep -f '^[^ ]*claude self-hosted-runner' >/dev/null || tmux has-session -t claude-runner 2>/dev/null; then
          CLAUDE_RUNNER_MSG="✓ Claude Code self-hosted runners already running (tmux attach -t claude-runner)"
        else
          tmux new-session -d -s claude-runner -n runner-1 "$HOME/.local/bin/claude-runner-loop 1"
          for i in $(seq 2 ${local.capacity}); do
            tmux new-window -t claude-runner -n "runner-$i" "$HOME/.local/bin/claude-runner-loop $i"
          done
          CLAUDE_RUNNER_MSG="✓ ${local.capacity} Claude Code self-hosted runner(s) started (tmux attach -t claude-runner; logs /tmp/claude-runner-*.log)"
        fi
      fi
      echo "$CLAUDE_RUNNER_MSG"
      echo "$CLAUDE_RUNNER_MSG" >> ~/WELCOME.txt
    fi
  EOT
}
