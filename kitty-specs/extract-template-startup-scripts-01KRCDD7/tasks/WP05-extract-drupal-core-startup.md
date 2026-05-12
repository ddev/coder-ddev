---
work_package_id: WP05
title: Extract drupal-core startup_script
dependencies:
- WP04
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
- T017
- T018
- T019
- T020
- T021
history:
- timestamp: '2026-05-12T00:00:00Z'
  event: created
authoritative_surface: scripts/templates/drupal-core/
execution_mode: code_change
owned_files:
- scripts/templates/drupal-core/**
- drupal-core/template.tf
tags: []
---

# WP05 — Extract `drupal-core` `startup_script`

## Objective

Apply the established extraction pattern to `drupal-core` — the **largest** of the four templates (~921 lines in the heredoc). Promote **5 Terraform interpolations** to `coder_agent.env`, un-escape **42 `$${...}`** occurrences, and replace the heredoc with `file(...)`.

## Context

- Heredoc range: `drupal-core/template.tf` lines ~324–1245 (~921 bash lines). This is the longest extract; allocate time accordingly.
- **5 Terraform interpolations** (from [`research.md`](../research.md) R1):
  | Heredoc line (relative) | Assignment                                                                    | Env key            | Terraform expression                                |
  | ----------------------- | ----------------------------------------------------------------------------- | ------------------ | --------------------------------------------------- |
  | 137                     | `REGISTRY_MIRROR="${var.docker_registry_mirror}"`                             | `REGISTRY_MIRROR`  | `var.docker_registry_mirror`                        |
  | 240                     | `ISSUE_FORK="${data.coder_parameter.issue_fork.value}"`                       | `ISSUE_FORK`       | `data.coder_parameter.issue_fork.value`             |
  | 242                     | `ISSUE_BRANCH="${data.coder_parameter.issue_branch.value}"`                   | `ISSUE_BRANCH`     | `data.coder_parameter.issue_branch.value`           |
  | 243                     | `INSTALL_PROFILE="${data.coder_parameter.install_profile.value}"`             | `INSTALL_PROFILE`  | `data.coder_parameter.install_profile.value`        |
  | 265                     | `DRUPAL_VERSION="${data.coder_parameter.drupal_version.value}"`               | `DRUPAL_VERSION`   | `data.coder_parameter.drupal_version.value`         |
- **42 `$${...}` shell-escape occurrences** — each becomes `${...}` in the extracted `.sh`.
- `drupal-core` ships `terraform test` files and is the most actively developed template per CLAUDE.md. Verification rigor matters more here than anywhere else.
- Note: this template has a `script = <<-EOT` block at lines 1353–1369 (secondary `script` block, **out of scope per spec.md FR-008**). Do not touch it.

## Branch strategy

- Planning/base branch: `extract-template-startup-scripts` (off `upstream/main`)
- Final merge target: `ddev/coder-ddev:main` (draft PR opened in WP07)
- Execution worktree allocated per lane from `lanes.json`.

## Subtasks

### T017 — Capture `drupal-core` pre-refactor baseline

**Steps**:
1. Extract heredoc body:
   ```bash
   sed -n '/^  startup_script = <<-EOT$/,/^  EOT$/p' drupal-core/template.tf \
     | sed '1d;$d' \
     > /tmp/wp05-core-startup-before.sh
   wc -l /tmp/wp05-core-startup-before.sh   # expect ~921
   ```
   ⚠️ `drupal-core` has multiple `<<-EOT` blocks. Confirm `sed` captured only the `startup_script` heredoc — the file size should match the expected ~921 lines, not include the secondary `script` block (~16 lines). If `sed` greedy-matches, anchor with explicit line numbers from `grep -n 'startup_script = <<-EOT' drupal-core/template.tf`.

2. Manifests:
   ```bash
   grep -nE '\$\{[^}$]' /tmp/wp05-core-startup-before.sh | grep -vE '\$\$\{' > /tmp/wp05-core-tf-interp.txt
   grep -nE '\$\$\{'    /tmp/wp05-core-startup-before.sh                     > /tmp/wp05-core-shell-escapes.txt
   wc -l /tmp/wp05-core-tf-interp.txt /tmp/wp05-core-shell-escapes.txt        # expect 5 and 42
   ```

3. (Optional) Live baseline:
   ```bash
   time coder create --template drupal-core drupal-core-baseline --yes
   coder delete drupal-core-baseline --yes
   ```

**Validation**:
- [ ] ~921 lines captured (and only the startup_script heredoc, not the secondary `script` block)
- [ ] Exactly 5 Terraform interpolations
- [ ] Exactly 42 `$${...}` escapes

### T018 — Extract heredoc to `scripts/templates/drupal-core/startup.sh`

**Steps**:
1. `mkdir -p scripts/templates/drupal-core`

2. Open the new file with the header:
   ```bash
   #!/usr/bin/env bash
   # scripts/templates/drupal-core/startup.sh
   # Workspace startup script for the drupal-core template.
   #
   # Required env vars (from coder_agent.env):
   #   REGISTRY_MIRROR   - Docker registry mirror URL
   #   ISSUE_FORK        - Fork URL for issue branch (may be empty)
   #   ISSUE_BRANCH      - Issue branch name (may be empty)
   #   INSTALL_PROFILE   - Drupal install profile (may be empty)
   #   DRUPAL_VERSION    - Major Drupal version
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

3. Append the body from `/tmp/wp05-core-startup-before.sh`, applying ONLY:
   - For each of the 5 Terraform assignments listed in Context, replace with `# <KEY> is injected via coder_agent.env`.
   - Un-escape all 42 `$${...}` to `${...}`.
   - Strip leading heredoc indentation.

4. `chmod +x scripts/templates/drupal-core/startup.sh`

**Files**:
- `scripts/templates/drupal-core/startup.sh` (new, ~915 lines)

**Validation**:
- [ ] `bash -n scripts/templates/drupal-core/startup.sh` exits 0
- [ ] `grep -c '\${var\.\|\${data\.' scripts/templates/drupal-core/startup.sh` returns 0
- [ ] `grep -c '\$\$\{' scripts/templates/drupal-core/startup.sh` returns 0
- [ ] (Optional) `shellcheck` clean

### T019 — Convert 5 Terraform interpolations to `env = { ... }` entries

**Steps**:
1. In `drupal-core/template.tf`, find the `coder_agent` resource (around line 324).
2. Add (or extend) the `env` block:
   ```hcl
     env = {
       REGISTRY_MIRROR = var.docker_registry_mirror
       ISSUE_FORK      = data.coder_parameter.issue_fork.value
       ISSUE_BRANCH    = data.coder_parameter.issue_branch.value
       INSTALL_PROFILE = data.coder_parameter.install_profile.value
       DRUPAL_VERSION  = data.coder_parameter.drupal_version.value
     }
   ```
   Merge with existing `env` block keys if present.

**Files**:
- `drupal-core/template.tf` (env block added/extended)

**Validation**:
- [ ] `terraform fmt -check drupal-core/template.tf` exits 0
- [ ] All 5 env keys present

### T020 — Replace heredoc with `file()`

**Steps**:
1. Replace `startup_script = <<-EOT ... EOT` (lines ~324–1245) with:
   ```hcl
     startup_script = file("${path.module}/../scripts/templates/drupal-core/startup.sh")
   ```
2. **Leave the secondary `script = <<-EOT ... EOT` block (around lines 1353–1369) untouched** — out of scope per FR-008.
3. `terraform fmt drupal-core/template.tf`

**Files**:
- `drupal-core/template.tf` (only `startup_script` modified)

**Validation**:
- [ ] `grep -c 'startup_script' drupal-core/template.tf` returns 1
- [ ] `grep -nE 'startup_script\s*=\s*file' drupal-core/template.tf` matches the `file(...)` call
- [ ] `grep -c '<<-EOT' drupal-core/template.tf` returns at least 1 (the secondary `script` block survives; shutdown_script uses `<<EOT` without dash)
- [ ] `template.tf` line count drops by ~915 lines

### T021 — Verify `drupal-core`

**Steps**:
1. `terraform fmt -check -recursive`
2. `terraform -chdir=drupal-core init -backend=false && terraform -chdir=drupal-core validate`
3. `terraform -chdir=drupal-core test`
4. (Strongly recommended) Live smoke-boot:
   ```bash
   time coder create --template drupal-core drupal-core-smoke --yes
   coder ssh drupal-core-smoke -- ddev --version
   coder ssh drupal-core-smoke -- docker info > /dev/null
   coder delete drupal-core-smoke --yes
   ```

**Validation**:
- [ ] All four commands exit 0
- [ ] (If live boot) within ±10% of T017 baseline; DDEV + dockerd healthy
- [ ] `git diff upstream/main...HEAD -- drupal-core/template.tf` shows ~915-line deletion and ~10-line addition (env block + file() call)

## Definition of Done

- `scripts/templates/drupal-core/startup.sh` exists, sourced from `drupal-core/template.tf` via `file()`.
- `coder_agent.env` carries all 5 required keys.
- 0 Terraform interpolations and 0 `$${...}` escapes remain in the extracted script.
- Secondary `script = <<-EOT` block (line ~1353) **untouched**.
- All verification commands pass.
- No files outside `owned_files` modified.

## Risks

| Risk                                                                                          | Mitigation                                                                                |
| --------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| Accidentally extracting the secondary `script` block (line ~1353) too                          | T017 step 1 explicitly anchors `sed` to the `startup_script` block only.                  |
| Missing one of 42 `$${...}` un-escapes                                                         | T018 validation grep enforces zero `$${` survives.                                        |
| `drupal-core` is the most actively developed template; concurrent changes on `upstream/main`  | Rebase before opening the draft PR (WP07); flag any merge conflicts in WP07 review.       |
| Large diff (~915 lines deleted) makes review hard                                              | Reviewer should diff the extracted `.sh` against the captured `/tmp/wp05-core-startup-before.sh` rather than reading the raw `.tf` deletion. |

## Reviewer guidance

- Confirm the 5-key `env` block matches the Context table exactly.
- Run `diff <(sed 's/\$\$/\$/g' /tmp/wp05-core-startup-before.sh) <(grep -v '^#\|^$\|^SCRIPT_DIR\|^\. ' scripts/templates/drupal-core/startup.sh)` and inspect — there should be only the 5 KEY assignment lines as the diff, plus any header lines.
- Verify the secondary `script` block at template.tf:1353-1369 is unchanged.
- `drupal-core` test suite is the most thorough; trust `terraform -chdir=drupal-core test` exit code as the primary gate.

## Implementation command

```bash
spec-kitty agent action implement WP05 --agent <name>
```
