---
name: coder-shared-workspace
description: Rules for sharing this Coder workspace, its Docker daemon and its DDEV install with other Claude sessions that the self-hosted runner runs at the same time. Read before running ddev, docker, or a repository's integration tests, before cleaning up disk, and before working in a checkout another session may be using.
---

# Sharing this workspace with other sessions

This workspace runs a Claude Code self-hosted runner that can host several
sessions at once. They all run as the same Unix user, with the same home
directory, one Docker daemon and one DDEV global configuration. Nothing
isolates them except the rules below.

## See who else is here

```bash
pgrep -af -- '--sdk-url' | grep -o 'sessions/cse_[A-Za-z0-9]*' | sort -u
pgrep -af -- '--sdk-url' | grep -o -- '--add-dir [^ ]*' | sort | uniq -c
```

The first lists active sessions; the second shows which directories they
work in. If you are the only session, the rest of this file still applies,
since another session can start at any time.

## Repositories and checkouts

- Sessions working in different repositories do not interfere with each
  other's files.
- Never switch the branch, reset, stash, or clean a checkout another
  session is using. If your working directory is a checkout another session
  also has, make your own worktree and work there:

  ```bash
  repo=~/workspace/<owner>/<repo>
  git -C "$repo" worktree add ~/workspace/<repo>-worktrees/<your-branch> -b <your-branch> <base>
  ```

  Keep worktrees under `~/workspace/<repo>-worktrees/`. Remove yours with
  `git worktree remove` when the session is done. Two worktrees cannot have
  the same branch checked out.
- Put scratch files in `~/tmp/<your session id>/`, not directly in `~/tmp`.

## Docker and DDEV

There is one Docker daemon. A command that affects every container affects
every session.

- **Never** run these unless the user asks for them:
  `ddev poweroff`, `ddev stop --all`, `ddev delete images`,
  `ddev clean`, `docker system prune`, `docker volume prune`,
  `docker rm -f $(docker ps -aq)`, or anything that restarts dockerd.
  Stop, restart or delete only projects you started.
- Do not change the DDEV global configuration (`ddev config global`,
  `~/.ddev/global_config.yaml`). Put settings in the project's
  `.ddev/config.*.yaml` instead.
- Give throwaway projects names no other session will pick, such as
  `<purpose>-<first 8 characters of your session id>`, and delete them with
  `ddev delete -Oy <name>` when done. The names registered in the workspace
  (`$CODER_PROJECT_NAMES`) are the only ones reachable from a browser; check
  `ddev list` and ask before taking one another session is using.
- Do not set fixed host ports (`host_https_port`, `host_webserver_port`,
  `host_db_port`) in a project. Let DDEV choose, so two projects never
  collide. Pick free ports for any other server you run.
- A project you started may be stopped by another session's tests (see
  below). If it is, `ddev start` it again.

## Tests that take over Docker

Some test suites start and power off DDEV projects on their own, for
example the integration tests of `ddev/ddev` (`make testpkg`, `make testcmd`,
`go test ./pkg/ddevapp/...`), which run `ddev poweroff`. Run those only
while holding the workspace-wide Docker lock, so two of them never run at
the same time:

```bash
flock --exclusive ~/.cache/coder-docker.lock make testpkg TESTARGS="-run TestName"
```

`flock` waits until the lock is free. Tell the user when you have been
waiting more than a few minutes, rather than waiting silently. Code that
only compiles or runs unit tests that do not touch Docker needs no lock.

## Disk

The disk is shared. When it fills up, stop what you started and delete
only what you created (build output, your worktrees, your `~/tmp`
directory, your test projects). Never delete another session's files, and
never prune Docker images or volumes another session may use.
