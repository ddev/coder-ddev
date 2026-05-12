# Phase 1 — Script Interface Model

**Mission**: `extract-template-startup-scripts-01KRCDD7`
**Date**: 2026-05-12

This mission has no domain data model. This document describes the **shell-script interface** between Terraform and the extracted scripts, which is the closest analogue.

## Invocation contract

Each per-template entry-point script is invoked by the Coder agent as:

```bash
bash /tmp/coder.<id>/coder_agent_startup.sh   # path managed by Coder agent
```

The agent renders `coder_agent.main.startup_script` (in our case `file("${path.module}/../scripts/templates/<name>/startup.sh")`) into that file before running it. The script:

- Has no positional arguments.
- Reads inputs from environment variables (populated via `coder_agent.main.env`).
- Writes log output to stdout/stderr (captured by Coder agent).
- Returns a non-zero exit code on failure (agent reports startup failure).

## Per-template env-var inputs

| Template            | Required env vars (from `coder_agent.main.env`)                                                                                                                                                                                                                                  |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `freeform`          | `REGISTRY_MIRROR`                                                                                                                                                                                                                                                                |
| `user-defined-web`  | `REGISTRY_MIRROR`                                                                                                                                                                                                                                                                |
| `drupal-contrib`    | `REGISTRY_MIRROR`, `PROJECT_NAME`, `PROJECT_TYPE`, `ISSUE_FORK`, `ISSUE_BRANCH`, `DRUPAL_VERSION`, `INSTALL_PROFILE`                                                                                                                                                              |
| `drupal-core`       | `REGISTRY_MIRROR`, `ISSUE_FORK`, `ISSUE_BRANCH`, `INSTALL_PROFILE`, `DRUPAL_VERSION`                                                                                                                                                                                             |

These exactly mirror the Terraform interpolations identified in [`research.md`](research.md#r1--interpolation-manifest).

## Header convention (NFR-002)

Every `.sh` file added by this mission begins with:

```bash
#!/usr/bin/env bash
# <Purpose>
#
# Required env vars:
#   FOO  - <description>
#   BAR  - <description>
#
# Optional env vars:
#   BAZ  - <description, default value>
#
# Exit codes:
#   0   - success
#   1   - generic failure
#   2+  - reserved for specific failure classes (documented per script)
#
# Idempotency: <yes / no / partial>
set -euo pipefail
```

## Shared helper sourcing pattern

Per-template entry-point scripts source shared helpers via:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED_DIR="${SCRIPT_DIR}/../../shared"
# shellcheck source=../../shared/lib.sh
. "${SHARED_DIR}/lib.sh"
```

This pattern resolves shared helpers relative to the per-template script's own location, so it works regardless of how the Coder agent invokes the script.

## State / side effects

Side effects on the running workspace (unchanged from current behavior, listed here for review reference):
- `chown coder:coder /home/coder` (on every start)
- Copy `/home/coder-files/*` → `/home/coder/` if missing
- Start `dockerd` and wait for `/var/run/docker.sock`
- Place `~/.ddev/global_config.yaml`
- Configure GitSSH wrapper
- Set locale, PATH, workspace env vars
- Per-template: project clone / issue-branch checkout / drupal-version setup

No new side effects are introduced. No state changes are persisted beyond what the inline version already persists.
