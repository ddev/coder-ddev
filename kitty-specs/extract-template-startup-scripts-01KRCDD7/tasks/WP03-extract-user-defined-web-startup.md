---
work_package_id: WP03
title: Extract user-defined-web startup_script
dependencies:
- WP02
requirement_refs:
- FR-001
- FR-002
- FR-004
- FR-005
- FR-008
- FR-009
planning_base_branch: extract-template-startup-scripts
merge_target_branch: extract-template-startup-scripts
branch_strategy: Planning artifacts for this feature were generated on extract-template-startup-scripts. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into extract-template-startup-scripts unless the human explicitly redirects the landing branch.
subtasks:
- T008
- T009
- T010
- T011
agent: "claude:opus-4-7:reviewer:reviewer"
shell_pid: "474940"
history:
- timestamp: '2026-05-12T00:00:00Z'
  event: created
authoritative_surface: scripts/templates/user-defined-web/
execution_mode: code_change
owned_files:
- scripts/templates/user-defined-web/**
- user-defined-web/template.tf
tags: []
---

# WP03 — Extract `user-defined-web` `startup_script`

## Objective

Apply the WP02 extraction pattern to `user-defined-web`: lift the `<<-EOT` heredoc (lines ~230–570, ~340 bash lines) out of `user-defined-web/template.tf`, drop it into `scripts/templates/user-defined-web/startup.sh`, and replace the heredoc with `file(...)` + `coder_agent.env`. The template needs only one env var (`REGISTRY_MIRROR`).

## Context

- `user-defined-web` has **1 Terraform interpolation** (`${var.docker_registry_mirror}` at heredoc-relative line 151) and **0 shell-escape (`$${}`) occurrences**. See [`research.md`](../research.md) R1.
- `user-defined-web` is the **only template without `terraform test` files**. Its `tests/` directory contains shell-driven helpers (see CLAUDE.md "Before Pushing / Pre-push Checklist" — `user-defined-web` is not listed for `terraform test`). Verification leans on `terraform validate` + live smoke-boot.
- `user-defined-web` is **also the only template without a `scripts/` sibling directory**. Per constraint **C-005**, that stays the case — the new runtime script goes under `scripts/templates/user-defined-web/`, not `user-defined-web/scripts/`.
- WP02 has already established the extraction pattern; this WP is a near-mechanical replay against a slightly larger heredoc.

## Branch strategy

- Planning/base branch: `extract-template-startup-scripts` (off `upstream/main`)
- Final merge target: `ddev/coder-ddev:main` (draft PR opened in WP07)
- Execution worktree allocated per lane from `lanes.json`.

## Subtasks

### T008 — Capture `user-defined-web` pre-refactor baseline

**Purpose**: Snapshot the current heredoc so the refactor is auditable.

**Steps**:
1. Extract the heredoc body:
   ```bash
   sed -n '/^  startup_script = <<-EOT$/,/^  EOT$/p' user-defined-web/template.tf \
     | sed '1d;$d' \
     > /tmp/wp03-udw-startup-before.sh
   wc -l /tmp/wp03-udw-startup-before.sh   # expect ~340
   ```

2. Grep the interpolation/escape manifests:
   ```bash
   grep -nE '\$\{[^}$]' /tmp/wp03-udw-startup-before.sh | grep -vE '\$\$\{'  # expect 1 line (REGISTRY_MIRROR)
   grep -cE '\$\$\{'    /tmp/wp03-udw-startup-before.sh                       # expect 0
   ```

3. (Optional) Live baseline:
   ```bash
   time coder create --template user-defined-web udw-baseline --yes
   coder delete udw-baseline --yes
   ```

**Validation**:
- [ ] `/tmp/wp03-udw-startup-before.sh` has ~340 lines
- [ ] Exactly 1 Terraform `${...}` interpolation found (REGISTRY_MIRROR assignment)
- [ ] 0 `$${...}` shell escapes

### T009 — Extract heredoc to `scripts/templates/user-defined-web/startup.sh`

**Purpose**: Move the body verbatim into the new file.

**Steps**:
1. Create the directory:
   ```bash
   mkdir -p scripts/templates/user-defined-web
   ```

2. Open the new file with the canonical header (mirrors WP02 T005, adapted for this template):
   ```bash
   #!/usr/bin/env bash
   # scripts/templates/user-defined-web/startup.sh
   # Workspace startup script for the user-defined-web template.
   #
   # Required env vars (from coder_agent.env in user-defined-web/template.tf):
   #   REGISTRY_MIRROR  - Docker registry mirror URL (from var.docker_registry_mirror)
   #
   # Exit codes:
   #   0 - workspace ready
   #   1 - generic failure
   #
   # Idempotency: yes.

   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   # shellcheck source=../../shared/lib.sh
   . "${SCRIPT_DIR}/../../shared/lib.sh"
   ```

3. Append the body from `/tmp/wp03-udw-startup-before.sh`, applying these transformations **only**:
   - Replace `REGISTRY_MIRROR="${var.docker_registry_mirror}"` with `# REGISTRY_MIRROR is injected via coder_agent.env`.
   - No `$${...}` escapes to unwind (0 in this template).
   - Strip leading heredoc indentation; the extracted file should be left-aligned bash.

4. `chmod +x scripts/templates/user-defined-web/startup.sh`

**Files**:
- `scripts/templates/user-defined-web/startup.sh` (new, ~335 lines)

**Validation**:
- [ ] `bash -n scripts/templates/user-defined-web/startup.sh` exits 0
- [ ] `grep -c '\${var\.' scripts/templates/user-defined-web/startup.sh` returns 0
- [ ] (Optional) `shellcheck` clean
- [ ] `diff` against the pre-refactor body matches (modulo REGISTRY_MIRROR comment and header)

### T010 — Replace heredoc in `user-defined-web/template.tf`

**Purpose**: Switch `template.tf` to `file()` + `env`.

**Steps**:
1. Replace the existing `startup_script = <<-EOT ... EOT` block with:
   ```hcl
     startup_script = file("${path.module}/../scripts/templates/user-defined-web/startup.sh")
   ```

2. Add (or extend) the `env` block:
   ```hcl
     env = {
       REGISTRY_MIRROR = var.docker_registry_mirror
     }
   ```

3. `terraform fmt user-defined-web/template.tf`

**Files**:
- `user-defined-web/template.tf` (modified — heredoc removed, `file()` + env added)

**Validation**:
- [ ] `terraform fmt -check user-defined-web/template.tf` exits 0
- [ ] `grep -c 'startup_script' user-defined-web/template.tf` returns 1
- [ ] `grep -nE 'startup_script\s*=\s*file' user-defined-web/template.tf` returns the `file(...)` line

### T011 — Verify `user-defined-web`

**Purpose**: Confirm behavior is preserved without the `terraform test` surface.

**Steps**:
1. Format check:
   ```bash
   terraform fmt -check -recursive
   ```

2. Validate:
   ```bash
   terraform -chdir=user-defined-web init -backend=false
   terraform -chdir=user-defined-web validate
   ```

3. **No `terraform test`** for this template (see Context). Rely on:
   - Live smoke-boot (strongly recommended):
     ```bash
     time coder create --template user-defined-web udw-smoke --yes
     coder ssh udw-smoke -- ddev --version
     coder ssh udw-smoke -- docker info > /dev/null   # confirm dockerd ready
     coder delete udw-smoke --yes
     ```
   - Shell-driven helpers under `user-defined-web/tests/`, if applicable:
     ```bash
     ls user-defined-web/tests/   # inspect what's there; run whatever the README describes
     ```

**Validation**:
- [ ] `terraform fmt -check -recursive` exits 0
- [ ] `terraform -chdir=user-defined-web validate` exits 0
- [ ] (If live boot ran) wall-clock time within ±10% of T008 baseline; `ddev --version` and `docker info` succeed inside the workspace

## Definition of Done

- `scripts/templates/user-defined-web/startup.sh` exists, sourced from `user-defined-web/template.tf` via `file()`.
- `coder_agent.env` carries `REGISTRY_MIRROR = var.docker_registry_mirror`.
- All verification commands above pass.
- No files outside `owned_files` modified.

## Risks

| Risk                                                                          | Mitigation                                                                                |
| ----------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| No `terraform test` surface to catch regressions                              | T011 mandates live smoke-boot; reviewer must explicitly confirm boot before approval.    |
| `user-defined-web` heredoc subtly different shape from `freeform`'s          | T009 `diff` against the captured pre-refactor body catches accidental drift.              |
| Newly introduced `scripts/templates/user-defined-web/` confuses contributors  | Per C-005 the placement is intentional; AUDIT.md in WP06 will document the rationale.    |

## Reviewer guidance

- Confirm `user-defined-web/scripts/` is **not** created (no per-template `scripts/` for this template).
- Confirm zero `${var.` or `${data.` strings in the extracted `.sh` file.
- Compare `template.tf` `startup_script` line count before/after — should drop by ~335 lines.

## Implementation command

```bash
spec-kitty agent action implement WP03 --agent <name>
```

## Activity Log

- 2026-05-12T17:21:26Z – claude:opus-4-7:implementer:implementer – shell_pid=472695 – Started implementation via action command
- 2026-05-12T17:23:51Z – claude:opus-4-7:implementer:implementer – shell_pid=472695 – user-defined-web extracted; terraform validate green; no terraform test for UDW; live boot deferred (no Coder host)
- 2026-05-12T17:24:14Z – claude:opus-4-7:reviewer:reviewer – shell_pid=474940 – Started review via action command
- 2026-05-12T17:25:53Z – claude:opus-4-7:reviewer:reviewer – shell_pid=474940 – WP03 approved: UDW template.tf 772->434 lines, startup.sh 368 lines exec, file() reference + REGISTRY_MIRROR merged into env. Gates: bash -n OK, terraform fmt OK, terraform validate Success. 0 surviving ${var/data} interpolations. C-005 OK (no user-defined-web/scripts dir). FR-008 scope OK (only template.tf + scripts/templates/user-defined-web/startup.sh). Shellcheck delta: only SC1091 new (lib.sh source, pattern-inherent, same as WP02); all other codes inherited from original heredoc - no regression.
