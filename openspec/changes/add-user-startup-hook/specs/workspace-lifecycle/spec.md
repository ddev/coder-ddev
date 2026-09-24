## ADDED Requirements

### Requirement: Optional User Startup Hook
The workspace startup script SHALL run the user-provided executable `~/.coder-startup.sh`, when present, on every workspace start, without blocking or failing workspace startup.

#### Scenario: Hook present
- **WHEN** a workspace starts and `~/.coder-startup.sh` exists and is executable
- **THEN** the startup script SHALL launch it after the rest of workspace setup has run, detached from the agent
- **AND** its output SHALL be written to `/tmp/coder-startup-user.log`
- **AND** its `PATH` SHALL include `~/.local/bin`, `~/.npm-global/bin` and `/home/linuxbrew/.linuxbrew/bin`

#### Scenario: Hook absent
- **WHEN** a workspace starts and `~/.coder-startup.sh` does not exist or is not executable
- **THEN** workspace startup SHALL proceed exactly as before

#### Scenario: Hook is slow or fails
- **WHEN** the hook runs indefinitely or exits non-zero
- **THEN** the agent startup script SHALL still complete and the workspace SHALL become ready
