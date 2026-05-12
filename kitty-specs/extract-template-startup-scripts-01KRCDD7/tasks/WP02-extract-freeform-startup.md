---
work_package_id: WP02
title: Extract freeform startup_script
dependencies:
- WP01
requirement_refs:
- FR-001
- FR-002
- FR-004
- FR-005
- FR-006
- FR-008
- FR-009
planning_base_branch: extract-template-startup-scripts
merge_target_branch: extract-template-startup-scripts
branch_strategy: Single feature branch extract-template-startup-scripts off upstream/main. Final draft PR targets ddev/coder-ddev:main. Execution worktrees allocated per lane from lanes.json.
subtasks:
- T004
- T005
- T006
- T007
history:
- timestamp: '2026-05-12T00:00:00Z'
  event: created
authoritative_surface: scripts/templates/freeform/
execution_mode: code_change
owned_files:
- scripts/templates/freeform/**
- freeform/template.tf
tags: []
---

# WP02 — Extract `freeform` `startup_script`

## Objective

Lift the `<<-EOT` startup-script heredoc out of `freeform/template.tf` (currently lines ~196–421, ~225 bash lines), drop it into `scripts/templates/freeform/startup.sh`, and replace the heredoc with `file("${path.module}/../scripts/templates/freeform/startup.sh")` plus a `coder_agent.env` block carrying the one Terraform-evaluated value the script needs (`REGISTRY_MIRROR`).

This is the **pilot extraction** — WP03–WP05 follow the same shape, so any pattern decisions made here propagate.

## Context

- `freeform` is the smallest of the four templates (~225 lines in the heredoc) and has exactly **1 Terraform interpolation** (`${var.docker_registry_mirror}`) and **1 shell-escape** (`$${...}`). See [`research.md`](../research.md) R1.
- The interpolation appears at heredoc-relative line 92 (template.tf absolute line ~287):
  `REGISTRY_MIRROR="${var.docker_registry_mirror}"`
- WP01 has already created `scripts/templates/` and `scripts/shared/lib.sh`.
- `freeform` is the **only** template that keeps `ddev-router` running (multi-project Host-header dispatch). The startup script is structurally simpler than the Drupal templates but its routing-related logic is unique. Preserve every line verbatim except for the interpolation/escape handling.

## Branch strategy

- Planning/base branch: `extract-template-startup-scripts` (off `upstream/main`)
- Final merge target: `ddev/coder-ddev:main` (draft PR opened in WP07)
- Execution worktree allocated per lane from `lanes.json`.

## Subtasks

### T004 — Capture `freeform` pre-refactor baseline

**Purpose**: Record the exact pre-refactor state so the refactor's "no behavior change" claim is auditable.

**Steps**:
1. Save the current heredoc body to a temp file (for diffing later):
   ```bash
   sed -n '/^  startup_script = <<-EOT$/,/^  EOT$/p' freeform/template.tf \
     | sed '1d;$d' \
     > /tmp/wp02-freeform-startup-before.sh
   wc -l /tmp/wp02-freeform-startup-before.sh   # expect ~225
   ```

2. Grep manifests inside that range:
   ```bash
   grep -nE '\$\{[^}$]'   /tmp/wp02-freeform-startup-before.sh | grep -vE '\$\$\{' > /tmp/wp02-freeform-tf-interp.txt
   grep -nE '\$\$\{'      /tmp/wp02-freeform-startup-before.sh                    > /tmp/wp02-freeform-shell-escapes.txt
   wc -l /tmp/wp02-freeform-tf-interp.txt /tmp/wp02-freeform-shell-escapes.txt   # expect 1 and 1
   ```

3. (Optional but recommended) Capture a baseline boot time against a Coder host:
   ```bash
   time coder create --template freeform freeform-baseline --yes
   coder delete freeform-baseline --yes
   ```
   Record `time-to-agent-connected` from the agent log. Skip if no Coder host is available; rely on `validate` + `test`.

**Validation**:
- [ ] `/tmp/wp02-freeform-startup-before.sh` exists and has ~225 lines
- [ ] `/tmp/wp02-freeform-tf-interp.txt` contains exactly one line referencing `var.docker_registry_mirror`
- [ ] `/tmp/wp02-freeform-shell-escapes.txt` contains exactly one line

### T005 — Extract `freeform` heredoc to `scripts/templates/freeform/startup.sh`

**Purpose**: Move the heredoc body verbatim (modulo interpolation/escape handling) into a versioned `.sh` file.

**Steps**:
1. Create the directory:
   ```bash
   mkdir -p scripts/templates/freeform
   ```

2. Start the new file with the canonical header (per [`data-model.md`](../data-model.md)):
   ```bash
   #!/usr/bin/env bash
   # scripts/templates/freeform/startup.sh
   # Workspace startup script for the freeform template.
   #
   # Required env vars (set on coder_agent.env in freeform/template.tf):
   #   REGISTRY_MIRROR  - Docker registry mirror URL (from var.docker_registry_mirror)
   #
   # Exit codes:
   #   0   - workspace ready
   #   1   - generic failure
   #
   # Idempotency: yes — safe to re-run on workspace restart.

   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   # shellcheck source=../../shared/lib.sh
   . "${SCRIPT_DIR}/../../shared/lib.sh"
   ```

3. Append the body from `/tmp/wp02-freeform-startup-before.sh`, applying these transformations **only**:
   - Replace the line `REGISTRY_MIRROR="${var.docker_registry_mirror}"` with a comment: `# REGISTRY_MIRROR is injected by Terraform via coder_agent.env`. Then **remove** any subsequent assignment statement that the heredoc relied on Terraform for — the env var now arrives from the agent.
   - Unescape every `$${VAR}` to `${VAR}` (1 occurrence in this template).
   - Remove the leading 2-space indentation that the heredoc carries (since `<<-EOT` only strips tabs; check actual indentation). The extracted file should be left-aligned bash.

4. End the file with a final `log "freeform startup complete"` (or whatever the original closing line is — keep it).

5. Make the script executable:
   ```bash
   chmod +x scripts/templates/freeform/startup.sh
   ```

**Files**:
- `scripts/templates/freeform/startup.sh` (new, ~220 lines)

**Validation**:
- [ ] `bash -n scripts/templates/freeform/startup.sh` exits 0
- [ ] `grep -c '\${' scripts/templates/freeform/startup.sh` returns 0 occurrences of Terraform-style `${...}` (only shell `${VAR}` remains, which is bash syntax)
- [ ] (Optional) `shellcheck scripts/templates/freeform/startup.sh` is clean or only emits documented warnings
- [ ] `diff <(sed 's/\$\$/\$/g' /tmp/wp02-freeform-startup-before.sh) <(grep -v '^#' scripts/templates/freeform/startup.sh)` is empty modulo the REGISTRY_MIRROR line and header

### T006 — Replace `freeform/template.tf` heredoc with `file()` + `env`

**Purpose**: Switch `template.tf` from inline heredoc to file-load + env-var injection.

**Steps**:
1. Locate the `coder_agent` resource in `freeform/template.tf`. Find the `startup_script` field (line ~196).

2. Replace the existing heredoc with:
   ```hcl
     startup_script = file("${path.module}/../scripts/templates/freeform/startup.sh")
   ```

3. Add (or extend) the `env` block on the same `coder_agent` resource:
   ```hcl
     env = {
       REGISTRY_MIRROR = var.docker_registry_mirror
     }
   ```
   If an `env` block already exists, merge — do not replace existing keys.

4. Run `terraform fmt freeform/template.tf` to canonicalize formatting.

**Files**:
- `freeform/template.tf` (modified — heredoc removed, ~225 lines deleted, ~5 lines added)

**Validation**:
- [ ] `terraform fmt -check freeform/template.tf` exits 0
- [ ] `grep -c 'startup_script' freeform/template.tf` returns 1
- [ ] `grep -nE 'startup_script\s*=\s*file' freeform/template.tf` returns the expected `file(...)` call
- [ ] The line count of `freeform/template.tf` drops by ~220 lines

### T007 — Verify `freeform`

**Purpose**: Confirm behavior is preserved.

**Steps**:
1. Format check:
   ```bash
   terraform fmt -check -recursive
   ```

2. Validate:
   ```bash
   terraform -chdir=freeform init -backend=false
   terraform -chdir=freeform validate
   ```

3. Terraform tests (#71 surface):
   ```bash
   terraform -chdir=freeform test
   ```

4. (Optional) Live smoke-boot against a Coder host:
   ```bash
   time coder create --template freeform freeform-smoke --yes
   coder ssh freeform-smoke -- ddev --version    # confirm DDEV ready
   coder delete freeform-smoke --yes
   ```
   Compare time-to-agent-connected against the T004 baseline; must be within ±10%.

**Validation**:
- [ ] `terraform fmt -check -recursive` exits 0
- [ ] `terraform -chdir=freeform validate` exits 0
- [ ] `terraform -chdir=freeform test` exits 0
- [ ] (If live boot ran) wall-clock time within ±10% of baseline

## Definition of Done

- `scripts/templates/freeform/startup.sh` exists, passes `bash -n`, and is sourced from `freeform/template.tf` via `file()`.
- `freeform/template.tf` `startup_script` heredoc body is empty (≤ a few envelope lines if any remain) and uses `file(...)`.
- `coder_agent.env` carries `REGISTRY_MIRROR = var.docker_registry_mirror`.
- All verification commands above pass.
- No files outside `owned_files` modified.

## Risks

| Risk                                                                                          | Mitigation                                                                                          |
| --------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| Heredoc has nested `EOT`-like sentinels that change behavior when un-heredoc'd                | T005 verifies via `diff` against the captured pre-refactor body.                                    |
| `file()` path resolves differently than expected from the `freeform/` module dir              | `terraform validate` catches missing-file errors; T007 is the gate.                                 |
| `coder_agent` already has an `env` block that conflicts                                       | T006 step 3 explicitly merges, not replaces.                                                        |
| `REGISTRY_MIRROR` was used by something other than dockerd (downstream side effects)          | The pre-refactor `grep` in T004 confirms it appears once; reviewer cross-checks downstream usage.   |
| ddev-router-keeping logic (unique to freeform) silently broken                                | T007 live boot is the high-fidelity check; `coder ssh -- ddev --version` confirms DDEV up.          |

## Reviewer guidance

- Inspect the `template.tf` diff: heredoc should be gone, `file(...)` should be present, `env = { REGISTRY_MIRROR = ... }` should be present.
- Inspect `startup.sh`: header present, `lib.sh` sourced, no `${var.xxx}` Terraform syntax anywhere, exactly one un-escape (`$${...}` → `${...}`).
- Confirm no changes to `freeform/scripts/`, `freeform/tests/`, or any other file.

## Implementation command

```bash
spec-kitty agent action implement WP02 --agent <name>
```
