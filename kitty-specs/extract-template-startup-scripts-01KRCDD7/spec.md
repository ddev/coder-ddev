# Mission Specification: Extract Template Startup Scripts

**Mission ID:** `01KRCDD730HK8SWWHAADCM8KQH`
**Mission slug:** `extract-template-startup-scripts-01KRCDD7`
**Mission type:** software-dev
**Source:** GitHub issue [ddev/coder-ddev#76](https://github.com/ddev/coder-ddev/issues/76)
**Feature branch:** `extract-template-startup-scripts` (off `upstream/main`)
**Final merge target:** `ddev/coder-ddev:main` (draft PR)

## 1. Problem & Motivation

The four Coder workspace templates — `drupal-contrib/`, `drupal-core/`, `freeform/`, `user-defined-web/` — each define their `coder_agent.main.startup_script` as a large inline bash heredoc inside `template.tf`. Today the inline bash spans roughly:

| Template            | startup_script heredoc range (in `template.tf`) | Approx. lines |
| ------------------- | ----------------------------------------------- | ------------- |
| `drupal-contrib`    | line 295 → 987                                  | ~692          |
| `drupal-core`       | line 324 → 1245                                 | ~921          |
| `freeform`          | line 196 → 421                                  | ~225          |
| `user-defined-web`  | line 230 → 570                                  | ~340          |

Total: **~2,178 lines** of bash embedded in HCL across four files.

Consequences today:
- Bash is interpolated inside Terraform strings, so shellcheck, formatters, and IDE jump-to-definition do not work.
- Reviewers cannot diff a behavior change in startup logic without scrolling through `template.tf` noise.
- Logic that recurs across templates (e.g., DDEV setup, `coder-files` hydration, dockerd bring-up) is copy-pasted rather than factored.
- Contributors cannot easily run a startup step in isolation for debugging.

Issue author's framing: *"Currently there is lots of poor inline bash in the templates. This should go into scripts, many of which can be shared between templates."*

CLAUDE.md already documents the canonical startup flow (Permissions → Home init → Git SSH → File copy → dockerd → DDEV config → DDEV verify → Environment), so the structural decomposition target is well-understood.

## 2. Goal

Extract the inline bash inside each template's `coder_agent.main.startup_script` heredoc into versioned `.sh` files, factor cross-template duplication into a shared library, and have the templates load these scripts via Terraform's `file()` (or `templatefile()` where Terraform-level variable interpolation is required). Preserve current runtime behavior exactly.

## 3. Scope

### In scope
- The single `startup_script = <<-EOT ... EOT` block inside each of the four templates' `template.tf`.
- Creation of new directories: `scripts/templates/<template-name>/` and `scripts/shared/` at the repo root.
- Refactoring duplicated logic across the four startup scripts into shared helpers.
- Updating each `template.tf` to consume the extracted script via `file()` or `templatefile()`.
- Confirming the existing test surface from issue #71 (`terraform -chdir=<template> test` + per-template `tests/`) still passes against each refactored template.

### Out of scope (this mission)
- `shutdown_script` blocks (separate heredocs at `template.tf` lines 288, 315, 191, 225 — kept inline for this mission).
- Other inline heredocs in `template.tf` files (the secondary `script = <<-EOT` blocks around lines 1078 / 1353 / 534 / 638).
- Inline bash inside `image/Dockerfile` (`RUN <<EOF` heredocs).
- `null_resource` provisioners and `local-exec` blocks.
- New CI gates (shellcheck enforcement, lint hooks) — may be a follow-up issue.
- New functionality — this is a behavior-preserving refactor.

### Bulk-edit classification
**Mode:** normal refactor. This mission does **not** rename a shared string across many files; it extracts unique content from four files into new files and replaces each with a single `file(...)` call. Bulk-edit guardrails do not apply.

## 4. Users

- **Reviewers / maintainers** of `ddev/coder-ddev` — gain readable, lintable, diffable scripts in PRs that touch startup logic.
- **Template contributors** — can edit `.sh` directly with shellcheck and editor tooling, and reuse shared helpers.
- **Workspace end users (Coder users launching templates)** — see no change. Startup behavior is identical.

## 5. User Scenarios & Acceptance Tests

### Scenario A: Workspace boots identically after refactor
**As a** workspace user creating a Coder workspace from `drupal-contrib`,
**when** the agent runs its `startup_script`,
**then** the resulting workspace state (DDEV running, `coder-files` hydrated, ports forwarded, expected files in `/home/coder`) is observationally identical to the pre-refactor template, and `terraform -chdir=drupal-contrib test` passes.

### Scenario B: Reviewer reads a startup logic change as a diff in a `.sh` file
**As a** reviewer of a future PR that changes how `drupal-core` clones an issue branch,
**when** I open the PR,
**then** the diff is in `scripts/templates/drupal-core/startup.sh` (or a shared helper in `scripts/shared/`), with `template.tf` largely untouched.

### Scenario C: Shared helper reused across two templates
**As a** contributor adding a fix to "wait for dockerd socket readiness",
**when** I edit `scripts/shared/wait-for-dockerd.sh`,
**then** all templates that source that helper pick up the change with no `template.tf` edit.

### Scenario D: Template-level variables still flow through
**As a** template that needs to inject Terraform-managed values (e.g., `data.coder_workspace.me.name`, `var.docker_gid`),
**when** its startup_script loads from disk,
**then** those values still reach the script — either via `templatefile()` substitution or by being exported as environment variables before the script is executed.

### Edge cases
- Heredoc-escaped `$${var}` (Terraform's escape for shell `$var`) is preserved through extraction so shell variables remain shell variables.
- Multi-line strings embedded in the bash (e.g., `cat <<EOF > file`) survive extraction without quoting drift.
- Script ordering and `set -e` / trap semantics match the inline version exactly.

## 6. Functional Requirements

| ID      | Requirement                                                                                                                                       | Status   |
| ------- | ------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| FR-001  | Each of the 4 templates SHALL have its `startup_script` inline heredoc replaced by a call to `file()` or `templatefile()` pointing at an extracted `.sh` file under `scripts/templates/<template-name>/`. | Required |
| FR-002  | The extracted entry-point script for each template SHALL be `scripts/templates/<template-name>/startup.sh` and SHALL be the single file referenced from `template.tf`.                                  | Required |
| FR-003  | Logic that appears in two or more templates' startup scripts SHALL be factored into `scripts/shared/<helper-name>.sh` and sourced by the per-template entry-point scripts.                              | Required |
| FR-004  | Extracted scripts SHALL preserve existing shell semantics (shebang, `set -e`/error handling, traps, `cd` behavior, exit codes) of the inline version.                                                    | Required |
| FR-005  | Where the inline heredoc used Terraform interpolation (`${ ... }` resolved by Terraform), the extracted form SHALL use `templatefile()` with the same input variables, OR the calling `template.tf` SHALL export those values as environment variables read by the script. | Required |
| FR-006  | Where the inline heredoc used the Terraform escape `$${ ... }` (a literal shell `${...}`), the extracted form SHALL render the shell variable form directly with no double-escaping.                     | Required |
| FR-007  | Scripts SHALL live in the repository at predictable paths so that `terraform plan` and template rendering work from a fresh clone with no additional setup.                                              | Required |
| FR-008  | The mission SHALL NOT change `shutdown_script` blocks, the secondary `script = <<-EOT` blocks (around `template.tf` lines 1078 / 1353 / 534 / 638), `null_resource` provisioners, or any `image/` files. | Required |
| FR-009  | `terraform fmt -check -recursive` SHALL pass on the resulting tree, and `terraform -chdir=<template> test` SHALL pass for each of the three templates that ship a `tests/` directory with `terraform test` coverage (`drupal-core`, `drupal-contrib`, `freeform`).                                                                  | Required |

## 7. Non-Functional Requirements

| ID       | Requirement                                                                                                                                                  | Threshold / Measure                                                                          | Status   |
| -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------- | -------- |
| NFR-001  | Workspace startup time SHALL NOT regress.                                                                                                                    | Median wall-clock time from workspace start → "agent connected" within 10% of pre-refactor baseline for each template, measured over 3 runs against the same Coder host. | Required |
| NFR-002  | Each extracted script SHALL have a header block documenting its purpose, required environment variables / `templatefile()` vars, and exit codes.            | Block present at top of every `.sh` file added by this mission.                              | Required |
| NFR-003  | After refactor, the count of bash content lines remaining inside `template.tf` `startup_script` heredocs (across all 4 templates combined) SHALL be ≤ 20.   | `wc -l` on the heredoc range; allowance covers only the `<<-EOT ... EOT` envelope plus minimal pre-script env setup. | Required |
| NFR-004  | Each extracted `.sh` file SHALL start with `#!/usr/bin/env bash` and use portable bash compatible with the workspace image's `/bin/bash` (Ubuntu 24.04).     | First-line check + manual review.                                                            | Required |

## 8. Constraints

| ID    | Constraint                                                                                                                  |
| ----- | --------------------------------------------------------------------------------------------------------------------------- |
| C-001 | The mission MUST be a behavior-preserving refactor — no new features, no UX changes, no infrastructure changes.             |
| C-002 | Scripts MUST load from the templates' relative path inside the repo (e.g., `${path.module}/../scripts/...`). No external download, no curl-from-internet at terraform apply time. |
| C-003 | The mission MUST land as a **draft PR** against `ddev/coder-ddev:main` from feature branch `extract-template-startup-scripts` on the user's fork (`jonesrussell/coder-ddev`). |
| C-004 | The mission MUST NOT introduce a new package manager, build tool, or non-bash runtime. Plain bash + Terraform only.         |
| C-005 | Existing per-template `scripts/` directories (currently holding test helpers like `create-test-workspaces.sh`) MUST be preserved. New startup scripts go under repo-root `scripts/templates/<name>/`, NOT under each template's existing `scripts/` directory, so test helpers and runtime helpers stay distinct. |
| C-006 | Per repo convention (CLAUDE.md), all comparisons and branch operations MUST use `upstream/main`, never local `main`.        |

## 9. Success Criteria

1. Each of the 4 `template.tf` files contains ≤ 20 bash-content lines inside its `startup_script` heredoc.
2. A reviewer opening a future PR that changes startup behavior can read the change as a diff inside a `.sh` file with shell syntax highlighting.
3. `terraform fmt -check -recursive` passes and `terraform -chdir=<template> test` passes for `drupal-core`, `drupal-contrib`, and `freeform`.
4. At least one helper exists under `scripts/shared/` and is sourced by ≥ 2 per-template `startup.sh` files (evidence that duplication was actually removed, not just relocated).
5. Workspace startup wall-clock time per template stays within 10% of baseline over 3 runs.
6. The draft PR's diff manifest contains no changes to `shutdown_script` heredocs, secondary `script` heredocs, `image/` files, or any other out-of-scope file.

## 10. Key Entities

- **Template (`<name>`)**: One of `drupal-contrib`, `drupal-core`, `freeform`, `user-defined-web`. Each is a directory at the repo root containing `template.tf`, `README.md`, `tests/`, and (for three of four) `scripts/`.
- **`startup_script` heredoc**: The `coder_agent.main.startup_script = <<-EOT ... EOT` block inside `template.tf`. The bash inside this heredoc is the subject of extraction.
- **Per-template entry-point script**: `scripts/templates/<name>/startup.sh` — the single `.sh` file referenced from `template.tf` for that template.
- **Shared helper script**: `scripts/shared/<helper>.sh` — bash logic sourced by two or more per-template entry-point scripts.
- **Test surface (#71)**: The test suites under each template's `tests/` directory and `terraform -chdir=<template> test`. The refactor must leave these green.

## 11. Assumptions

- Cross-template duplication is real and lexical enough to factor (likely candidates from CLAUDE.md's flow: ownership fix, `/home/coder-files/` hydration, GitSSH wrapper, dockerd start + socket wait, `~/.ddev/global_config.yaml` placement, DDEV verify, locale/PATH). Plan phase will quantify this with a side-by-side read; if real duplication is small, `scripts/shared/` may end up with 1–2 helpers, which still satisfies Success Criterion #4 if at least one helper is reused twice.
- Terraform `file()` and `templatefile()` resolve paths relative to the calling module. Per-template `template.tf` files live at `<repo>/<template>/template.tf`, so `${path.module}/../scripts/templates/<name>/startup.sh` reaches the repo-root `scripts/` directory.
- Where the inline form relied on Terraform-injected values, switching to `templatefile()` is acceptable; env-var injection from the `coder_agent` resource (via the `env` field) is also acceptable and may be preferable for sensitive values.
- Tests added in #71 cover enough surface area to detect a behavior regression in the refactor. If a coverage gap is discovered during implementation, it is logged as a follow-up issue rather than patched silently inside this mission.

## 12. Dependencies

- **Closed prerequisite:** [#71 — Add automated tests](https://github.com/ddev/coder-ddev/issues/71) (closed 2026-05-10). The test surface that gates this refactor exists.
- No runtime dependencies on other in-flight missions. The unrelated `spec-workspace-runtime-contract` work (PR #149 / issue #150) is informational only and lives on a separate branch.

## 13. Risks & Mitigations

| Risk                                                                                                                       | Mitigation                                                                                                                                              |
| -------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Terraform escape behavior (`${}` vs `$${}`) differs between heredoc form and file-loaded form, leaking shell variables.    | Audit every `$${` and `${` occurrence in the inline heredocs before extraction; choose `file()` vs `templatefile()` per-template based on what's needed. |
| Hidden duplication is structural but not lexical, making clean factoring hard.                                             | Plan-phase side-by-side review; if shared helpers can't be cleanly factored, ship per-template scripts first and file a follow-up.                      |
| Tests from #71 don't exercise a particular startup branch.                                                                 | Log coverage gaps as separate follow-up issues; do not silently expand test scope inside this mission.                                                  |
| `user-defined-web/` has no existing `scripts/` directory; introducing one could surprise contributors.                     | Per C-005, new startup scripts go under repo-root `scripts/templates/user-defined-web/`, not under `user-defined-web/scripts/`.                         |
| Long inline heredocs may contain subtle Terraform interpolation that's easy to miss when extracting.                       | Plan phase produces a per-template interpolation manifest before code changes start; each WP includes a pre-flight grep for `${` / `$${` survivors.     |

## 14. Out-of-Scope Follow-ups (suggested issues)

- Extract `shutdown_script` blocks similarly.
- Extract the secondary `script = <<-EOT` blocks (around `template.tf` lines 1078 / 1353 / 534 / 638).
- Add a shellcheck CI gate over `scripts/`.
- Extract `RUN <<EOF` heredocs in `image/Dockerfile`.
