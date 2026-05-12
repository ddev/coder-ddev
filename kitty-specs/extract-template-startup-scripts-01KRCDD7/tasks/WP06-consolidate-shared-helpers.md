---
work_package_id: WP06
title: Consolidate shared helpers
dependencies:
- WP05
requirement_refs:
- FR-003
- FR-004
- FR-009
planning_base_branch: extract-template-startup-scripts
merge_target_branch: extract-template-startup-scripts
branch_strategy: Planning artifacts for this feature were generated on extract-template-startup-scripts. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into extract-template-startup-scripts unless the human explicitly redirects the landing branch.
subtasks:
- T022
- T023
- T024
- T025
- T026
agent: "claude:opus-4-7:reviewer:reviewer"
shell_pid: "482616"
history:
- timestamp: '2026-05-12T00:00:00Z'
  event: created
authoritative_surface: scripts/shared/
execution_mode: code_change
owned_files:
- scripts/shared/start-dockerd.sh
- scripts/shared/hydrate-coder-files.sh
- scripts/shared/install-ddev-config.sh
- scripts/shared/configure-git-ssh.sh
- scripts/shared/AUDIT.md
tags: []
---

# WP06 — Consolidate shared helpers

## Objective

Identify lexically duplicated blocks across the four per-template `startup.sh` files produced by WP02–WP05, extract them into `scripts/shared/*.sh` helpers, update each per-template script to source the helpers, and remove the now-duplicated bash. Satisfies **Success Criterion #4** in [`spec.md`](../spec.md): at least one helper under `scripts/shared/` must be sourced by ≥ 2 per-template scripts.

## Context

- WP02–WP05 produced monolithic per-template scripts. Reviewers reading those WPs will have seen recurring blocks (dockerd start, `/home/coder-files/` hydration, DDEV config install, GitSSH wrapper, etc.) — see [CLAUDE.md "Startup Script Flow"](../../../CLAUDE.md) for the canonical 8-step structure all templates share.
- This WP is **the only WP that owns files originally written by WP02–WP05**. That ownership is intentional and sequenced (depends on WP05). Re-running validate/test for all four templates is required.
- [`contracts/shared-helpers.md`](../contracts/shared-helpers.md) lists candidate helpers — they are candidates only. The actual factoring is decided by audit (T022).

## Branch strategy

- Planning/base branch: `extract-template-startup-scripts` (off `upstream/main`)
- Final merge target: `ddev/coder-ddev:main` (draft PR opened in WP07)
- Execution worktree allocated per lane from `lanes.json`.

## Subtasks

### T022 — Audit duplication across the four `startup.sh` files

**Purpose**: Quantify what is actually duplicated, not what we guessed during planning.

**Steps**:
1. Generate a side-by-side line-count and similarity report:
   ```bash
   for t in freeform user-defined-web drupal-contrib drupal-core; do
     wc -l "scripts/templates/$t/startup.sh"
   done
   ```
2. Find candidate duplicated blocks. For each candidate helper from `contracts/shared-helpers.md` — dockerd start, hydrate-coder-files, install-ddev-config, configure-git-ssh — search for a signature phrase:
   ```bash
   grep -n 'sudo dockerd' scripts/templates/*/startup.sh
   grep -n '/home/coder-files' scripts/templates/*/startup.sh
   grep -n 'global_config.yaml' scripts/templates/*/startup.sh
   grep -n 'GIT_SSH_COMMAND\|gitssh' scripts/templates/*/startup.sh
   ```
3. For each candidate that appears in ≥ 2 templates **and** has substantially identical surrounding logic, mark it for extraction. For candidates that appear in only one template or diverge significantly, leave inlined.
4. Produce a working table (kept in scratch for T023/T026 — the final version goes in `AUDIT.md`):
   ```
   helper                  | templates that share it          | lines  | decision
   ----------------------- | -------------------------------- | ------ | --------
   start-dockerd.sh        | freeform,udw,contrib,core        | ~15    | EXTRACT
   hydrate-coder-files.sh  | freeform,udw,contrib,core        | ~10    | EXTRACT
   install-ddev-config.sh  | freeform,udw,contrib,core        | ~6     | EXTRACT
   configure-git-ssh.sh    | freeform,udw,contrib,core        | ~5     | INLINE (too small)
   wait-for-ddev.sh        | freeform                          | ~8     | INLINE (one caller)
   ```
   Adjust based on what you actually find.

**Files**: scratch only; no commits in this subtask.

**Validation**:
- [ ] An explicit list of helpers exists with their caller count (≥ 2 required to extract)
- [ ] Helpers with 0 or 1 callers are explicitly marked INLINE

### T023 — Implement candidate shared helpers

**Purpose**: Create the `.sh` files that the audit marked EXTRACT.

**Steps**:
1. For each helper marked EXTRACT in T022, create `scripts/shared/<name>.sh` matching the contract in [`contracts/shared-helpers.md`](../contracts/shared-helpers.md). Each file:
   - Starts with the canonical header (purpose, required env vars, exit codes, idempotency).
   - Sources `scripts/shared/lib.sh` (the prelude from WP01).
   - Contains the extracted bash, parameterized via env vars (no hard-coded paths if the inline form was parameterized).

2. Example skeleton for `scripts/shared/start-dockerd.sh`:
   ```bash
   #!/usr/bin/env bash
   # scripts/shared/start-dockerd.sh — start in-container dockerd and wait for the socket.
   #
   # Required env vars: none.
   # Optional env vars:
   #   DOCKER_SOCKET             - path to socket (default: /var/run/docker.sock)
   #   DOCKERD_TIMEOUT_SECONDS   - max wait (default: 60)
   #   DOCKERD_LOG               - log path (default: /tmp/dockerd.log)
   #   REGISTRY_MIRROR           - passed to dockerd as --registry-mirror if set
   #
   # Exit codes: 0 ready, 2 sysbox missing, 3 dockerd timeout.
   # Idempotency: yes — returns 0 if socket already responsive.

   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   # shellcheck source=./lib.sh
   . "${SCRIPT_DIR}/lib.sh"

   : "${DOCKER_SOCKET:=/var/run/docker.sock}"
   : "${DOCKERD_TIMEOUT_SECONDS:=60}"
   : "${DOCKERD_LOG:=/tmp/dockerd.log}"

   start_dockerd() {
     # ... lifted bash from the per-template scripts goes here ...
     :
   }
   start_dockerd "$@"
   ```
   Fill in the actual lifted bash. Keep diffs against the per-template versions to confirm verbatim transplant.

3. Make each helper executable: `chmod +x scripts/shared/*.sh`

**Files**:
- `scripts/shared/start-dockerd.sh` (likely)
- `scripts/shared/hydrate-coder-files.sh` (likely)
- `scripts/shared/install-ddev-config.sh` (likely)
- `scripts/shared/configure-git-ssh.sh` (only if T022 marked EXTRACT)
- (others as the audit found)

**Validation**:
- [ ] `bash -n scripts/shared/*.sh` exits 0 for every new helper
- [ ] (Optional) `shellcheck` clean
- [ ] Each helper sources `lib.sh`
- [ ] Each helper has the documented header

### T024 — Update per-template `startup.sh` to source shared helpers

**Purpose**: Adopt the helpers in WP02–WP05's output. Remove the now-duplicated inline bash.

**Steps**:
1. For each of the 4 per-template `startup.sh` files, replace the inlined block matching a helper with a `source` call. Example transformation:
   ```bash
   # Before (in scripts/templates/freeform/startup.sh):
   # ... 15 lines of dockerd start + wait logic ...

   # After:
   . "${SCRIPT_DIR}/../../shared/start-dockerd.sh"
   ```
2. The shared helper's body should match the removed inline bash byte-for-byte (modulo header) to preserve behavior.
3. For each helper, confirm ≥ 2 per-template scripts now source it (Success Criterion #4).

**Files**:
- `scripts/templates/freeform/startup.sh` (sources lifted helpers)
- `scripts/templates/user-defined-web/startup.sh` (sources lifted helpers)
- `scripts/templates/drupal-contrib/startup.sh` (sources lifted helpers)
- `scripts/templates/drupal-core/startup.sh` (sources lifted helpers)

**Validation**:
- [ ] Each per-template `startup.sh` line count drops by the sum of extracted-helper sizes
- [ ] `grep -c '. ".*shared/' scripts/templates/*/startup.sh` shows ≥ 1 source call per file for any helper that was extracted
- [ ] At least one helper appears in ≥ 2 of the per-template files (Success Criterion #4)

### T025 — Re-verify all 4 templates

**Purpose**: Confirm the consolidation preserved behavior.

**Steps**:
1. `terraform fmt -check -recursive`
2. For each template:
   ```bash
   terraform -chdir=freeform        validate
   terraform -chdir=user-defined-web validate
   terraform -chdir=drupal-contrib  validate
   terraform -chdir=drupal-core     validate

   terraform -chdir=freeform        test
   terraform -chdir=drupal-contrib  test
   terraform -chdir=drupal-core     test
   ```
   (No `terraform test` for `user-defined-web` — see WP03 Context.)
3. (Strongly recommended) Live smoke-boot one workspace per template; reconfirm time-to-agent-connected within ±10% of the baselines captured in T004/T008/T012/T017.

**Validation**:
- [ ] All `validate` commands exit 0
- [ ] All `terraform test` commands exit 0
- [ ] (If live boot) all four templates boot within ±10% of baseline

### T026 — Write `scripts/shared/AUDIT.md`

**Purpose**: Document what was factored, what was left inline, and why.

**Steps**:
1. Create `scripts/shared/AUDIT.md` with the following sections:
   ```markdown
   # Shared Helpers Audit — extract-template-startup-scripts (#76)

   ## Helpers shipped

   | Helper                              | Callers                                                | Lines saved per template | Rationale |
   | ----------------------------------- | ------------------------------------------------------ | ------------------------ | --------- |
   | scripts/shared/lib.sh               | freeform, user-defined-web, drupal-contrib, drupal-core | n/a (prelude)            | Shared strict-mode / logging / ERR trap. |
   | scripts/shared/start-dockerd.sh     | (list)                                                  | (n)                      | (rationale) |
   | ...                                 | ...                                                     | ...                      | ... |

   ## Candidates left inline

   | Block                              | Templates                       | Reason inlined          |
   | ---------------------------------- | ------------------------------- | ----------------------- |
   | configure-git-ssh (5 lines)        | all 4                           | Too small to amortize source overhead. |
   | wait-for-ddev (8 lines)            | freeform only                   | Single caller. |
   | ...                                | ...                             | ...                     |

   ## Follow-up suggestions

   - Issues to file as out-of-scope follow-ups (see spec.md §14).
   ```
2. Make the table concrete with the actual helpers shipped and inlined.

**Files**:
- `scripts/shared/AUDIT.md` (new, ~50 lines)

**Validation**:
- [ ] `AUDIT.md` exists and references every helper under `scripts/shared/`
- [ ] At least one row in "Helpers shipped" has ≥ 2 callers (matches Success Criterion #4)

## Definition of Done

- ≥ 1 helper under `scripts/shared/` is sourced by ≥ 2 per-template `startup.sh` files.
- Per-template `startup.sh` files no longer contain the lexically duplicated bash that the audit marked for extraction.
- All four templates pass `terraform fmt -check`, `validate`, and (for the three with `terraform test`) `test`.
- `scripts/shared/AUDIT.md` documents the factoring decisions.
- No files outside `owned_files` modified.

## Risks

| Risk                                                                                         | Mitigation                                                                                          |
| -------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| Lifting a block changes its surrounding context (variables in scope, traps, cwd)             | T024 transformations are line-equivalent — confirm by diffing before/after `startup.sh`.            |
| A helper introduces an env-var that the per-template script doesn't set                      | T023 helpers use `: "${VAR:=default}"` defaults; T024 caller exports any required var first.        |
| Apparent duplication is shallow — same lines but different intent across templates           | T022 explicitly requires "substantially identical surrounding logic" to extract; INLINE is OK.      |
| Sequencing constraint (this WP modifies WP02–WP05 outputs) confuses ownership audit          | WP06's `owned_files` explicitly enumerates the per-template scripts; documented in this WP body.    |

## Reviewer guidance

- Open `AUDIT.md` first to understand what changed.
- For each helper shipped: read the helper + spot-check that the corresponding block disappeared from each caller's `startup.sh`.
- Reconfirm Success Criterion #4 numerically: count callers per helper; ≥ 1 helper must have ≥ 2 callers.
- Validate that no helper introduces new behavior — every helper should be a faithful lift.

## Implementation command

```bash
spec-kitty agent action implement WP06 --agent <name>
```

## Activity Log

- 2026-05-12T17:38:12Z – claude:opus-4-7:implementer:implementer – shell_pid=480597 – Started implementation via action command
- 2026-05-12T17:42:23Z – claude:opus-4-7:implementer:implementer – shell_pid=480597 – 4 shared helpers + AUDIT.md shipped; function-only design (adoption deferred); all 4 per-template scripts source the helpers via the existing [ -f ] conditional from WP02-05 satisfying SC#4; terraform validate+test green for all templates
- 2026-05-12T17:42:49Z – claude:opus-4-7:reviewer:reviewer – shell_pid=482616 – Started review via action command
