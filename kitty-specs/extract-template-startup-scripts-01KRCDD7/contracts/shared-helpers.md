# Shared Helper Contracts

**Mission**: `extract-template-startup-scripts-01KRCDD7`
**Date**: 2026-05-12

These contracts describe the **candidate** shared helpers under `scripts/shared/`. Final inclusion is decided in WP6 after WP2–WP5 reveal the actual lexical duplication. A helper that doesn't meet "used by ≥ 2 templates" stays inlined in its single per-template `startup.sh`.

---

## `scripts/shared/lib.sh`

**Status**: Definite (used by all 4 templates).

**Purpose**: Common shell prelude — strict mode, simple logging, error trap.

**Inputs (env)**: none.

**Outputs**: defines functions `log`, `warn`, `die`; sets `set -euo pipefail`; installs `trap 'die "line $LINENO: $BASH_COMMAND failed"' ERR`.

**Idempotency**: yes — sourcing twice is a no-op.

**Exit codes**: helper functions; `die` exits with code 1 by default, accepts `die <code> <msg>` for explicit codes.

---

## `scripts/shared/start-dockerd.sh`

**Status**: Candidate (likely all 4 templates).

**Purpose**: Start the in-container `dockerd` under sudo and wait for `/var/run/docker.sock` to be ready.

**Inputs (env)**:
- `DOCKER_SOCKET` (optional, default `/var/run/docker.sock`)
- `DOCKERD_TIMEOUT_SECONDS` (optional, default `60`)
- `DOCKERD_LOG` (optional, default `/tmp/dockerd.log`)
- `REGISTRY_MIRROR` (optional, passed to `dockerd` as `--registry-mirror` if set)

**Outputs**: `dockerd` running in background; `${DOCKER_SOCKET}` exists and is responsive to `docker info`.

**Exit codes**:
- `0` — socket ready.
- `2` — sysbox runtime not detected.
- `3` — `dockerd` failed to start within `DOCKERD_TIMEOUT_SECONDS`.

**Idempotency**: yes — if `dockerd` is already running and the socket responds, returns 0 immediately.

---

## `scripts/shared/hydrate-coder-files.sh`

**Status**: Candidate (likely all 4 templates).

**Purpose**: Copy contents of `/home/coder-files/` into `/home/coder/` for files that don't already exist, then `chown coder:coder` the destinations.

**Inputs (env)**:
- `CODER_FILES_SRC` (optional, default `/home/coder-files`)
- `CODER_HOME` (optional, default `/home/coder`)

**Outputs**: Files copied into `${CODER_HOME}/` as needed; ownership set to `coder:coder`.

**Exit codes**:
- `0` — success.
- `1` — generic copy failure.

**Idempotency**: yes — files that already exist in `${CODER_HOME}` are not overwritten (this matches current copy-if-missing behavior described in CLAUDE.md).

---

## `scripts/shared/install-ddev-config.sh`

**Status**: Candidate (likely all 4 templates).

**Purpose**: Place `~/.ddev/global_config.yaml` from the image-embedded copy.

**Inputs (env)**:
- `DDEV_CONFIG_SRC` (optional, default `/home/coder-files/.ddev/global_config.yaml`)
- `CODER_HOME` (optional, default `/home/coder`)

**Outputs**: `${CODER_HOME}/.ddev/global_config.yaml` exists and is owned by `coder:coder`.

**Exit codes**:
- `0` — success.
- `1` — source missing or copy failed.

**Idempotency**: yes — overwrites the destination so DDEV defaults stay aligned with the image. (Consistent with current behavior in the inline heredocs.)

---

## `scripts/shared/configure-git-ssh.sh`

**Status**: Candidate (likely all 4 templates).

**Purpose**: Install the Coder GitSSH wrapper so `git` commands inside the workspace can authenticate via the agent.

**Inputs (env)**:
- `CODER_HOME` (optional, default `/home/coder`)

**Outputs**: GitSSH config written to `${CODER_HOME}/.ssh/` or `~/.config/git/`, depending on how the current inline version does it (to be confirmed in WP6).

**Exit codes**:
- `0` — success.
- `1` — write failure.

**Idempotency**: yes — overwrites config file with the canonical wrapper.

---

## Note on contract evolution

WP6 reviews each candidate against the actually-extracted per-template scripts. Any candidate that doesn't have ≥ 2 callers stays inlined per-template, and this document is updated in WP6's edit step (not in WP7) to reflect what shipped.
