---
work_package_id: WP01
title: Scaffold scripts/templates + scripts/shared/lib.sh
dependencies: []
requirement_refs:
- FR-003
- FR-007
planning_base_branch: extract-template-startup-scripts
merge_target_branch: extract-template-startup-scripts
branch_strategy: Planning artifacts for this feature were generated on extract-template-startup-scripts. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into extract-template-startup-scripts unless the human explicitly redirects the landing branch.
base_branch: kitty/mission-extract-template-startup-scripts-01KRCDD7
base_commit: ed61eb58ca3dca2609cefbdce88df535afc93dc3
created_at: '2026-05-12T17:08:56.592350+00:00'
subtasks:
- T001
- T002
- T003
shell_pid: "465542"
agent: "claude:opus-4-7:implementer:implementer"
history:
- timestamp: '2026-05-12T00:00:00Z'
  event: created
authoritative_surface: scripts/shared/
execution_mode: code_change
owned_files:
- scripts/templates/.gitkeep
- scripts/shared/.gitkeep
- scripts/shared/lib.sh
tags: []
---

# WP01 — Scaffold `scripts/templates/` + `scripts/shared/lib.sh`

## Objective

Create the runtime-script directory layout (`scripts/templates/` and `scripts/shared/`) at the repo root and ship a minimal shared prelude (`scripts/shared/lib.sh`) that every per-template `startup.sh` will source. This WP introduces no behavior — it only lays the foundation that WP02–WP05 build on.

## Context

- The 4 templates (`drupal-contrib/`, `drupal-core/`, `freeform/`, `user-defined-web/`) currently embed their entire `startup_script` as an inline `<<-EOT` heredoc inside `template.tf`. ~2,178 lines total.
- `scripts/` already exists at the repo root with `cleanup-deleted-workspaces.sh`, `coder-delete-workspace-dir.sh`, `coder-discord-relay`, and `coder-discord-relay.service`. Do not touch those.
- Three of the four templates have their own per-template `scripts/` directories holding test helpers (e.g., `drupal-contrib/scripts/create-test-workspaces.sh`). Per constraint **C-005**, those stay where they are — runtime helpers go under repo-root `scripts/templates/<name>/`.
- See [`research.md`](../research.md) for the interpolation manifest and [`contracts/shared-helpers.md`](../contracts/shared-helpers.md) for the shared-helper contracts. `lib.sh` is the only definite shared helper at this stage.

## Branch strategy

- Planning/base branch: `extract-template-startup-scripts` (off `upstream/main`)
- Final merge target: `ddev/coder-ddev:main` (draft PR opened in WP07)
- Execution worktrees allocated per lane from `lanes.json` after `finalize-tasks` runs.

## Subtasks

### T001 — Scaffold `scripts/templates/` and `scripts/shared/` directories

**Purpose**: Create the two new directories under the repo-root `scripts/` tree so subsequent WPs can drop files in.

**Steps**:
1. Create directories:
   ```bash
   mkdir -p scripts/templates scripts/shared
   ```
2. Add a `.gitkeep` in each new directory so git tracks the empty dirs:
   ```bash
   : > scripts/templates/.gitkeep
   : > scripts/shared/.gitkeep
   ```
3. Do **not** create per-template subdirectories under `scripts/templates/` yet — those are owned by WP02–WP05.

**Files**:
- `scripts/templates/.gitkeep` (new, empty)
- `scripts/shared/.gitkeep` (new, empty)

**Validation**:
- [ ] `ls scripts/templates/ scripts/shared/` returns at least the `.gitkeep` in each
- [ ] `git status --short` shows both `.gitkeep` files as new

### T002 — Write `scripts/shared/lib.sh`

**Purpose**: Provide a shared prelude with strict-mode setup, logging helpers, and an ERR trap. Every per-template `startup.sh` will source this.

**Steps**:
1. Create `scripts/shared/lib.sh` with the following content (this is the canonical shape — keep it close):

   ```bash
   #!/usr/bin/env bash
   # scripts/shared/lib.sh — shared prelude for template startup scripts.
   #
   # Source this from each per-template startup.sh:
   #   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   #   . "${SCRIPT_DIR}/../../shared/lib.sh"
   #
   # Required env vars: none.
   # Optional env vars:
   #   LIB_LOG_PREFIX  - prefix for log lines (default: $(basename "$0"))
   #
   # Exit codes:
   #   die() exits 1 by default; die <code> <msg> uses <code>.
   #
   # Idempotency: sourcing twice is a no-op.

   # Guard against double-sourcing.
   if [ -n "${__CODER_DDEV_LIB_SOURCED:-}" ]; then
     return 0 2>/dev/null || exit 0
   fi
   __CODER_DDEV_LIB_SOURCED=1

   set -euo pipefail

   : "${LIB_LOG_PREFIX:=$(basename "${0:-startup.sh}")}"

   log()  { printf '[%s] %s\n'       "${LIB_LOG_PREFIX}" "$*"; }
   warn() { printf '[%s] WARN: %s\n' "${LIB_LOG_PREFIX}" "$*" >&2; }
   die() {
     local code=1
     if [[ "${1:-}" =~ ^[0-9]+$ ]]; then code="$1"; shift; fi
     printf '[%s] FATAL: %s\n' "${LIB_LOG_PREFIX}" "$*" >&2
     exit "${code}"
   }

   trap 'die "line ${LINENO}: command failed: ${BASH_COMMAND}"' ERR
   ```

2. Make the file executable (it's sourced, not executed, but the shebang invites editor tooling):
   ```bash
   chmod +x scripts/shared/lib.sh
   ```

**Files**:
- `scripts/shared/lib.sh` (new, ~35 lines)

**Validation**:
- [ ] `bash -n scripts/shared/lib.sh` exits 0
- [ ] `shellcheck scripts/shared/lib.sh` is clean (if shellcheck is installed). If shellcheck is unavailable, note that in the WP review.
- [ ] Sourcing twice in the same shell is a no-op:
      ```bash
      bash -c '. scripts/shared/lib.sh; . scripts/shared/lib.sh; log "double-source ok"'
      ```

### T003 — Smoke-validate the scaffold

**Purpose**: Confirm the scaffold passes the gates that CI will run in WP07.

**Steps**:
1. Terraform formatting check:
   ```bash
   terraform fmt -check -recursive
   ```
   This should still pass — WP01 doesn't touch any `.tf` file. If it fails, the failure pre-exists and is not WP01's responsibility, but flag it in the WP review.

2. Bash syntax check on `lib.sh`:
   ```bash
   bash -n scripts/shared/lib.sh
   ```

3. (Optional) shellcheck:
   ```bash
   command -v shellcheck && shellcheck scripts/shared/lib.sh
   ```

4. Confirm no other files changed unexpectedly:
   ```bash
   git diff --stat HEAD
   git status --short
   ```
   Expected: 3 new files (`.gitkeep` x2, `lib.sh`).

**Validation**:
- [ ] `terraform fmt -check -recursive` exits 0
- [ ] `bash -n scripts/shared/lib.sh` exits 0
- [ ] `git status --short` lists only `scripts/templates/.gitkeep`, `scripts/shared/.gitkeep`, `scripts/shared/lib.sh`

## Definition of Done

- `scripts/templates/` and `scripts/shared/` exist with `.gitkeep` files.
- `scripts/shared/lib.sh` exists, passes `bash -n`, and (if available) `shellcheck`.
- `terraform fmt -check -recursive` is green.
- No `.tf` files modified.
- No files outside this WP's `owned_files` list modified.

## Risks

| Risk                                                                                          | Mitigation                                                                          |
| --------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| `shellcheck` not installed on dev machine                                                     | Optional gate; note in WP review. CI may or may not run shellcheck — WP07 confirms. |
| Existing `terraform fmt` violation pre-exists in the repo                                     | Flag in WP review; do not silently fix unrelated formatting.                        |

## Reviewer guidance

- Check that `lib.sh` does **not** assume any project-specific env vars beyond `LIB_LOG_PREFIX`.
- Check that the ERR trap message includes `${LINENO}` and `${BASH_COMMAND}` for debuggability.
- Confirm `.gitkeep` files are zero bytes and have no execute bit.

## Implementation command

```bash
spec-kitty agent action implement WP01 --agent <name>
```

## Activity Log

- 2026-05-12T17:08:57Z – claude:opus-4-7:implementer:implementer – shell_pid=465542 – Assigned agent via action command
- 2026-05-12T17:09:49Z – claude:opus-4-7:implementer:implementer – shell_pid=465542 – lib.sh prelude + scaffold ready for review
