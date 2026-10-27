# Change: Add Optional Claude Code Self-Hosted Runner

## Why
A Coder workspace can serve as a Claude Code self-hosted runner, so sessions started on claude.ai/code run with the workspace's Docker and DDEV. Today that takes a hand-written `~/.coder-startup.sh`, a restart loop in tmux and a hand-maintained `/etc/gitconfig`, and it is easy to get wrong: a startup marker kept in `/tmp` survived a workspace stop/start and silently kept the runner from starting. Several sessions on one runner also share one Docker daemon and one DDEV install, and nothing tells them how to avoid breaking each other's work.

## What Changes
- New module `modules/claude-self-hosted-runner`, vendored into `freeform` only (`make sync-claude-runner-module`, part of `make sync-shared`). The Drupal templates set up one project for a person to work on, which is not what a runner workspace needs.
- Two parameters: "Run a Claude Code self-hosted runner" (switch, default off) and "Claude Code runner: concurrent sessions" (1–4, default 1).
- When on, and `~/.claude-runner/environment-secret` exists, the startup script starts one `claude self-hosted-runner` per concurrent session, each in a restart loop in its own window of tmux session `claude-runner`, with `--use-anthropic-git-proxy` and `--capacity 1`. The runner refuses `--use-anthropic-git-proxy` with a larger capacity, so each runner gets its own base directory `~/workspace/runner-<n>` and its own `GIT_CONFIG_GLOBAL`. The secret never goes through Terraform.
- Because the runner rewrites `~/.gitconfig` and `~/.config/git` before every session, the session git identity and ignore list are installed in `/etc/gitconfig` on every start.
- The runner refuses to start when Claude Code remote control is also on, and says why in the build log and `~/WELCOME.txt`.
- Installs the skill `~/.claude/skills/coder-shared-workspace`, which the runner copies into every session: stay out of other runners' checkouts, a DDEV global directory per session via `DDEV_XDG_CONFIG_HOME`, no workspace-wide Docker/DDEV commands, a `flock` around test suites that power off DDEV, and disk cleanup limited to a session's own files.
- Installs `claude-sessions`, which lists live sessions with their checkout, branch and unpushed commit count.
- Documented in `docs/user/using-workspaces.md`.

## Impact
- Affected specs: `claude-self-hosted-runner` (new capability)
- Affected code: `modules/claude-self-hosted-runner/` and its vendored copy in `freeform/`, `freeform/template.tf`, `freeform/tests/validate.tftest.hcl`, `Makefile`, `CLAUDE.md`, `docs/user/using-workspaces.md`
