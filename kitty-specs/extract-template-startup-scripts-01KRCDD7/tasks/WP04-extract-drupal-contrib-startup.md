---
work_package_id: WP04
title: Extract drupal-contrib startup_script
dependencies:
- WP03
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
branch_strategy: Planning artifacts for this feature were generated on extract-template-startup-scripts. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into extract-template-startup-scripts unless the human explicitly redirects the landing branch.
subtasks:
- T012
- T013
- T014
- T015
- T016
agent: "claude:opus-4-7:reviewer:reviewer"
shell_pid: "477200"
history:
- timestamp: '2026-05-12T00:00:00Z'
  event: created
authoritative_surface: scripts/templates/drupal-contrib/
execution_mode: code_change
owned_files:
- scripts/templates/drupal-contrib/**
- drupal-contrib/template.tf
tags: []
---

# WP04 — Extract `drupal-contrib` `startup_script`

## Objective

Apply the WP02/WP03 extraction pattern to `drupal-contrib` — the third-largest template (~692 lines in the heredoc). This template promotes **7 Terraform interpolations** to `coder_agent.env` and un-escapes **31 `$${...}`** occurrences to `${...}`. Same shape, more env keys.

## Context

- Heredoc range: `drupal-contrib/template.tf` lines ~295–987 (~692 bash lines).
- **7 Terraform interpolations** (all top-of-heredoc assignments — see [`research.md`](../research.md) R1):
  | Heredoc line (relative) | Assignment                                                                          | Env key            | Terraform expression                                |
  | ----------------------- | ----------------------------------------------------------------------------------- | ------------------ | --------------------------------------------------- |
  | 89                      | `REGISTRY_MIRROR="${var.docker_registry_mirror}"`                                   | `REGISTRY_MIRROR`  | `var.docker_registry_mirror`                        |
  | 153                     | `PROJECT_NAME="${data.coder_parameter.project_name.value}"`                         | `PROJECT_NAME`     | `data.coder_parameter.project_name.value`           |
  | 154                     | `PROJECT_TYPE="${data.coder_parameter.project_type.value}"`                         | `PROJECT_TYPE`     | `data.coder_parameter.project_type.value`           |
  | 217                     | `ISSUE_FORK="${data.coder_parameter.issue_fork.value}"`                             | `ISSUE_FORK`       | `data.coder_parameter.issue_fork.value`             |
  | 218                     | `ISSUE_BRANCH="${data.coder_parameter.issue_branch.value}"`                         | `ISSUE_BRANCH`     | `data.coder_parameter.issue_branch.value`           |
  | 269                     | `DRUPAL_VERSION="${data.coder_parameter.drupal_version.value}"`                     | `DRUPAL_VERSION`   | `data.coder_parameter.drupal_version.value`         |
  | 445                     | `INSTALL_PROFILE="${data.coder_parameter.install_profile.value}"`                   | `INSTALL_PROFILE`  | `data.coder_parameter.install_profile.value`        |
- **31 `$${...}` shell-escape occurrences**, each becomes `${...}` in the extracted `.sh`.
- `drupal-contrib` does ship `terraform test` files. Use them in T016.

## Branch strategy

- Planning/base branch: `extract-template-startup-scripts` (off `upstream/main`)
- Final merge target: `ddev/coder-ddev:main` (draft PR opened in WP07)
- Execution worktree allocated per lane from `lanes.json`.

## Subtasks

### T012 — Capture `drupal-contrib` pre-refactor baseline

**Purpose**: Snapshot.

**Steps**:
1. Extract heredoc body:
   ```bash
   sed -n '/^  startup_script = <<-EOT$/,/^  EOT$/p' drupal-contrib/template.tf \
     | sed '1d;$d' \
     > /tmp/wp04-contrib-startup-before.sh
   wc -l /tmp/wp04-contrib-startup-before.sh   # expect ~692
   ```

2. Manifests:
   ```bash
   grep -nE '\$\{[^}$]' /tmp/wp04-contrib-startup-before.sh | grep -vE '\$\$\{' > /tmp/wp04-contrib-tf-interp.txt
   grep -nE '\$\$\{'    /tmp/wp04-contrib-startup-before.sh                     > /tmp/wp04-contrib-shell-escapes.txt
   wc -l /tmp/wp04-contrib-tf-interp.txt /tmp/wp04-contrib-shell-escapes.txt    # expect 7 and 31
   ```

3. (Optional) Live baseline:
   ```bash
   time coder create --template drupal-contrib drupal-contrib-baseline --yes
   coder delete drupal-contrib-baseline --yes
   ```

**Validation**:
- [ ] ~692 lines captured
- [ ] Exactly 7 Terraform interpolations found
- [ ] Exactly 31 `$${...}` escapes found

### T013 — Extract heredoc to `scripts/templates/drupal-contrib/startup.sh`

**Purpose**: Create the per-template script file.

**Steps**:
1. `mkdir -p scripts/templates/drupal-contrib`

2. Open the new file with the header:
   ```bash
   #!/usr/bin/env bash
   # scripts/templates/drupal-contrib/startup.sh
   # Workspace startup script for the drupal-contrib template.
   #
   # Required env vars (from coder_agent.env):
   #   REGISTRY_MIRROR   - Docker registry mirror URL
   #   PROJECT_NAME      - DDEV project name
   #   PROJECT_TYPE      - DDEV project type (drupal, php, etc.)
   #   ISSUE_FORK        - Fork URL for issue branch (may be empty)
   #   ISSUE_BRANCH      - Issue branch name (may be empty)
   #   DRUPAL_VERSION    - Major Drupal version
   #   INSTALL_PROFILE   - Drupal install profile (may be empty)
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

3. Append the body from `/tmp/wp04-contrib-startup-before.sh`, applying ONLY:
   - For each of the 7 Terraform assignments listed in Context, replace the line with a comment of the form `# <KEY> is injected via coder_agent.env`. The script now expects `${REGISTRY_MIRROR}`, `${PROJECT_NAME}`, etc. to be present in the environment.
   - Un-escape all 31 `$${VAR}` occurrences to `${VAR}`.
   - Strip leading heredoc indentation.

4. `chmod +x scripts/templates/drupal-contrib/startup.sh`

**Files**:
- `scripts/templates/drupal-contrib/startup.sh` (new, ~685 lines)

**Validation**:
- [ ] `bash -n scripts/templates/drupal-contrib/startup.sh` exits 0
- [ ] `grep -c '\${var\.\|\${data\.' scripts/templates/drupal-contrib/startup.sh` returns 0
- [ ] `grep -c '\$\$\{' scripts/templates/drupal-contrib/startup.sh` returns 0 (no double-dollar escapes survive)
- [ ] (Optional) `shellcheck` clean

### T014 — Convert 7 Terraform interpolations to `env = { ... }` entries

**Purpose**: Move Terraform-evaluated values onto the `coder_agent.env` map.

**Steps**:
1. In `drupal-contrib/template.tf`, find the `coder_agent` resource.
2. Add (or extend) the `env` block:
   ```hcl
     env = {
       REGISTRY_MIRROR = var.docker_registry_mirror
       PROJECT_NAME    = data.coder_parameter.project_name.value
       PROJECT_TYPE    = data.coder_parameter.project_type.value
       ISSUE_FORK      = data.coder_parameter.issue_fork.value
       ISSUE_BRANCH    = data.coder_parameter.issue_branch.value
       DRUPAL_VERSION  = data.coder_parameter.drupal_version.value
       INSTALL_PROFILE = data.coder_parameter.install_profile.value
     }
   ```
   Merge with any existing `env` block — do not drop existing keys.

**Files**:
- `drupal-contrib/template.tf` (env block added/extended)

**Validation**:
- [ ] `terraform fmt -check drupal-contrib/template.tf` exits 0
- [ ] The 7 env keys appear in the `env` block

### T015 — Replace heredoc with `file()`

**Purpose**: Finalize the `template.tf` switchover.

**Steps**:
1. Replace `startup_script = <<-EOT ... EOT` with:
   ```hcl
     startup_script = file("${path.module}/../scripts/templates/drupal-contrib/startup.sh")
   ```
2. `terraform fmt drupal-contrib/template.tf`

**Files**:
- `drupal-contrib/template.tf` (heredoc removed, `file(...)` in place)

**Validation**:
- [ ] `grep -c 'startup_script' drupal-contrib/template.tf` returns 1
- [ ] `grep -nE 'startup_script\s*=\s*file' drupal-contrib/template.tf` matches the `file(...)` call
- [ ] `template.tf` line count drops by ~685 lines

### T016 — Verify `drupal-contrib`

**Purpose**: Confirm behavior preserved.

**Steps**:
1. `terraform fmt -check -recursive`
2. `terraform -chdir=drupal-contrib init -backend=false && terraform -chdir=drupal-contrib validate`
3. `terraform -chdir=drupal-contrib test`
4. (Optional) Live smoke-boot:
   ```bash
   time coder create --template drupal-contrib drupal-contrib-smoke --yes
   coder ssh drupal-contrib-smoke -- ddev --version
   coder ssh drupal-contrib-smoke -- docker info > /dev/null
   coder delete drupal-contrib-smoke --yes
   ```

**Validation**:
- [ ] All four commands exit 0
- [ ] (If live boot) within ±10% of T012 baseline; DDEV + dockerd healthy

## Definition of Done

- `scripts/templates/drupal-contrib/startup.sh` exists and is sourced from `drupal-contrib/template.tf` via `file()`.
- `coder_agent.env` carries all 7 required keys.
- 0 Terraform interpolations and 0 `$${...}` escapes remain in the extracted script.
- All verification commands pass.
- No files outside `owned_files` modified.

## Risks

| Risk                                                                                    | Mitigation                                                                              |
| --------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| Missing one of 31 `$${...}` un-escapes silently changes a shell variable name           | T013 validation grep enforces zero `$${` survives; reviewer cross-checks.               |
| One of the 7 env keys not actually exported (e.g., typo)                                | T016 `terraform test` exercises the parameter wiring; live boot would surface failures. |
| Env-var-only injection breaks a path that depended on Terraform's compile-time literal  | None of the 7 values is a path or HCL expression — all are simple string parameters.    |

## Reviewer guidance

- Sanity-check the 7-key `env` block matches the table in Context.
- Confirm zero `${var.` / `${data.` strings in the extracted `.sh`.
- Confirm `drupal-contrib/scripts/` (test helpers) untouched.
- Run `terraform -chdir=drupal-contrib test` locally — that's the highest-confidence gate.

## Implementation command

```bash
spec-kitty agent action implement WP04 --agent <name>
```

## Activity Log

- 2026-05-12T17:26:16Z – claude:opus-4-7:implementer:implementer – shell_pid=475729 – Started implementation via action command
- 2026-05-12T17:29:24Z – claude:opus-4-7:implementer:implementer – shell_pid=475729 – drupal-contrib extracted; 7 env vars + 31 escapes converted; terraform validate+test green; live boot deferred
- 2026-05-12T17:29:54Z – claude:opus-4-7:reviewer:reviewer – shell_pid=477200 – Started review via action command
