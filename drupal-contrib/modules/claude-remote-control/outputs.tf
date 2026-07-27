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
      sed -i '/^export CLAUDE_REMOTE_CMD=/d;/^export CLAUDE_EXTRA_FLAGS=/d' ~/.bashrc || true
      echo 'export CLAUDE_REMOTE_CMD="${local.remote_cmd}"' >> ~/.bashrc
      echo 'export CLAUDE_EXTRA_FLAGS="${local.extra_flags}"' >> ~/.bashrc
      export CLAUDE_REMOTE_CMD="${local.remote_cmd}"
      export CLAUDE_EXTRA_FLAGS="${local.extra_flags}"

      # Target window 0 explicitly, not just the session: an untargeted
      # `-t "$CODER_WORKSPACE_NAME"` resolves to the session's current
      # *active* window, which silently becomes some other window if one
      # was ever created (e.g. by the user running tmux themselves) and
      # left focused - respawning the wrong pane instead of the intended
      # Claude Code session.
      #
      # The remote-control name includes the current directory's basename
      # so each retarget shows up as a visibly different session in
      # claude.ai/code - reusing the exact same name every time makes it
      # impossible to tell the new (live) session apart from the old
      # (now-dead, since a respawn never resumes the prior one) ones in
      # that list.
      mkdir -p ~/.local/bin
      cat > ~/.local/bin/claude-here <<-'CLAUDEHERE'
    #!/usr/bin/env bash
    set -euo pipefail
    DIR_NAME=$(basename "$(pwd)")
    tmux respawn-pane -k -t "$CODER_WORKSPACE_NAME:0" -c "$(pwd)" "claude --remote-control $CODER_WORKSPACE_NAME-$DIR_NAME $CLAUDE_EXTRA_FLAGS"
    CLAUDEHERE
      chmod +x ~/.local/bin/claude-here

      # claude-ensure: makes sure window 0 of the named tmux session is
      # actually running claude, (re)launching it if not. Needed because
      # tmux has-session alone isn't a sufficient guard: the session could
      # already exist but be a bare shell instead of claude - e.g. the
      # "Claude Code" app button raced ahead of this script and created it
      # first, or the claude process itself already exited (it will, if
      # nobody completes login/connects within its idle window) leaving the
      # tmux server dead entirely. Shared by both this startup script and
      # the app button's command so either one can revive a dead/bare
      # session, not just create it once at boot.
      cat > ~/.local/bin/claude-ensure <<-'CLAUDEENSURE'
    #!/usr/bin/env bash
    set -euo pipefail
    if tmux has-session -t "$CODER_WORKSPACE_NAME" 2>/dev/null; then
      CURRENT_CMD=$(tmux list-panes -t "$CODER_WORKSPACE_NAME:0" -F '#{pane_current_command}' 2>/dev/null | head -1)
      if [ "$CURRENT_CMD" != "claude" ]; then
        tmux respawn-pane -k -t "$CODER_WORKSPACE_NAME:0" -c "$HOME" "$CLAUDE_REMOTE_CMD"
      fi
    else
      tmux new-session -d -s "$CODER_WORKSPACE_NAME" -c "$HOME" "$CLAUDE_REMOTE_CMD"
    fi
    CLAUDEENSURE
      chmod +x ~/.local/bin/claude-ensure

      ~/.local/bin/claude-ensure
      echo "✓ Claude Code remote control session ready: $CODER_WORKSPACE_NAME"
    fi
  EOT
}
