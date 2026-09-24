# Change: Add Optional User Startup Hook

## Why
Workspace restarts stop all running processes. Anything a user needs running (DDEV projects, a long-running agent or runner in `tmux`, a dev server) has to be restarted by hand after each start. The only user-controlled startup point today is `~/.bashrc`, which only runs once someone opens an interactive shell, so a workspace that restarts with nobody logged in comes back with nothing running.

## What Changes
- Each template's `coder_agent` `startup_script` (`drupal-core`, `drupal-contrib`, `freeform`) runs `~/.coder-startup.sh` if it exists and is executable.
- The hook runs after the rest of workspace setup (Docker, DDEV, the Claude remote-control snippet), detached with `nohup setsid` and stdin from `/dev/null`, so it never blocks or fails agent startup.
- Hook output goes to `/tmp/coder-startup-user.log`.
- `PATH` for the hook includes `~/.local/bin`, `~/.npm-global/bin` and `/home/linuxbrew/.linuxbrew/bin`, because `~/.bashrc` returns early for non-interactive shells.
- Documented in `docs/user/using-workspaces.md`.

This is opt-in and does nothing unless the user creates the file, consistent with the template's "infrastructure-only, no auto-bootstrap" philosophy.

## Impact
- Affected specs: `workspace-lifecycle` (new capability)
- Affected code: `drupal-core/template.tf`, `drupal-contrib/template.tf`, `freeform/template.tf`, their `tests/validate.tftest.hcl`, `docs/user/using-workspaces.md`
