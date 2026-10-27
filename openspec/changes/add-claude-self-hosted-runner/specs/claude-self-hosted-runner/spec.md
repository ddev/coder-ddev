## ADDED Requirements

### Requirement: Optional Claude Code Self-Hosted Runner
The workspace startup script SHALL start a Claude Code self-hosted runner on every workspace start when the user enables it and has saved an environment secret, and SHALL do nothing otherwise.

#### Scenario: Enabled with a secret
- **WHEN** a workspace starts with "Run a Claude Code self-hosted runner" on and `~/.claude-runner/environment-secret` is non-empty
- **THEN** the startup script SHALL start `claude self-hosted-runner` in a restart loop in tmux session `claude-runner`, unless a runner is already running
- **AND** it SHALL pass the "concurrent sessions" value as `--capacity`
- **AND** it SHALL install the session git config in `/etc/gitconfig`, the `coder-shared-workspace` skill in `~/.claude/skills`, and `claude-sessions` in `~/.local/bin`

#### Scenario: Enabled without a secret
- **WHEN** the runner is enabled and the secret file is missing or empty
- **THEN** the runner SHALL NOT start, and the build log and `~/WELCOME.txt` SHALL say how to add the secret

#### Scenario: Enabled together with remote control
- **WHEN** both the runner and Claude Code remote control are enabled
- **THEN** the runner SHALL NOT start, and the build log and `~/WELCOME.txt` SHALL say to turn one of them off

#### Scenario: Disabled
- **WHEN** the runner is off (the default)
- **THEN** workspace startup SHALL proceed exactly as before
