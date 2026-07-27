output "enabled" {
  description = "Whether Claude Code remote control is enabled"
  value       = local.enabled
}

output "app_count" {
  description = "Number of coder_app.claude_code instances created (0 or 1) - exposed for tests"
  value       = length(coder_app.claude_code)
}

output "startup_script" {
  description = "Bash snippet for the caller to append to its coder_agent startup_script, after other ~/.bashrc customizations."
  value       = <<-EOT

    # Claude Code remote control: this launches `claude --remote-control` in a named
    # tmux session so it's connectable from claude.ai/code or the mobile app.
    CLAUDE_CODE_ENABLED="${local.enabled}"
    if [ "$CLAUDE_CODE_ENABLED" = "true" ]; then
      sed -i '/^export CLAUDE_REMOTE_CMD=/d' ~/.bashrc || true
      echo 'export CLAUDE_REMOTE_CMD="${local.remote_cmd}"' >> ~/.bashrc
      export CLAUDE_REMOTE_CMD="${local.remote_cmd}"

      # Target window 0 explicitly, not just the session: an untargeted
      # `-t "$CODER_WORKSPACE_NAME"` resolves to the session's current
      # *active* window, which silently becomes some other window if one
      # was ever created (e.g. by the user running tmux themselves) and
      # left focused - respawning the wrong pane instead of the intended
      # Claude Code session.
      mkdir -p ~/.local/bin
      cat > ~/.local/bin/claude-here <<-'CLAUDEHERE'
    #!/usr/bin/env bash
    set -euo pipefail
    tmux respawn-pane -k -t "$CODER_WORKSPACE_NAME:0" -c "$(pwd)" "$CLAUDE_REMOTE_CMD"
    CLAUDEHERE
      chmod +x ~/.local/bin/claude-here

      if ! tmux has-session -t "$CODER_WORKSPACE_NAME" 2>/dev/null; then
        tmux new-session -d -s "$CODER_WORKSPACE_NAME" -c "$HOME" "$CLAUDE_REMOTE_CMD"
        echo "✓ Claude Code remote control session started: $CODER_WORKSPACE_NAME"
      fi
    fi
  EOT
}
