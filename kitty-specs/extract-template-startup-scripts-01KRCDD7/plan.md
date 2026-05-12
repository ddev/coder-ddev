# Implementation Plan: Extract Template Startup Scripts

**Mission**: `extract-template-startup-scripts-01KRCDD7` (mid8 `01KRCDD7`, id `01KRCDD730HK8SWWHAADCM8KQH`)
**Branch**: `extract-template-startup-scripts` (off `upstream/main`)
**Final merge target**: `ddev/coder-ddev:main` (draft PR from `jonesrussell/coder-ddev:extract-template-startup-scripts`)
**Spec**: [`kitty-specs/extract-template-startup-scripts-01KRCDD7/spec.md`](spec.md)
**Source issue**: [ddev/coder-ddev#76](https://github.com/ddev/coder-ddev/issues/76)
**Date**: 2026-05-12

## Summary

Behavior-preserving refactor that lifts ~2,178 lines of inline bash out of four Coder templates' `coder_agent.main.startup_script` heredocs into versioned `.sh` files under `scripts/templates/<name>/` and `scripts/shared/`. Templates load extracted scripts via Terraform's `file()`, and Terraform-evaluated values are passed in via the `coder_agent.env` map (env-var injection) rather than `templatefile()`. Verification per WP: `terraform fmt -check`, `terraform -chdir=<template> init -backend=false && validate && test`. Mission stays scoped to `startup_script` only; `shutdown_script`, secondary `script` heredocs, and Dockerfile heredocs are explicit follow-ups.

## Technical Context

**Language/Version**: Bash (Ubuntu 24.04 `/bin/bash`), Terraform/HCL (no specific version constraint imposed by this mission)
**Primary Dependencies**: Terraform `coder/coder` provider (existing), Coder agent runtime (existing)
**Storage**: N/A — this mission touches build-time artifacts only
**Testing**: `terraform fmt -check -recursive`, `terraform -chdir=<template> validate`, `terraform -chdir=<template> test` (#71 test surface), per-template `tests/` directories
**Target Platform**: Coder workspaces on Sysbox-runc, Ubuntu 24.04 base image (see CLAUDE.md "Sysbox Runtime Model")
**Project Type**: Multi-template Terraform monorepo. Templates at repo root (`drupal-contrib/`, `drupal-core/`, `freeform/`, `user-defined-web/`); shared scripts at `scripts/` root.
**Performance Goals**: Workspace startup time within ±10% of baseline per template (NFR-001)
**Constraints**:
- Behavior-preserving (C-001)
- No external downloads at terraform apply time (C-002)
- Draft PR only (C-003)
- No new package managers / build tools (C-004)
- Preserve existing per-template `scripts/` test helpers (C-005)
- Always compare against `upstream/main`, never local `main` (C-006, repo convention)
**Scale/Scope**: 4 templates, ~2,178 inline bash lines to extract, ≤ 20 lines may remain across all 4 `startup_script` envelopes (NFR-003)

## Charter Check

*GATE: must pass before Phase 0; re-check after Phase 1.*

Charter context (from `spec-kitty charter context --action plan`):
- Template set: `software-dev-default`
- Directives present: `DIR-001`, `DIR-002`
- No project-specific tactics

Gate evaluation:
| Directive area      | Mission posture                                                                                 | Status |
| ------------------- | ----------------------------------------------------------------------------------------------- | ------ |
| Branch Strategy     | Feature branch off `upstream/main`; merge target = `main` via draft PR. Aligns with CLAUDE.md "Never use local `main`". | PASS   |
| Testing Standards   | Uses existing `terraform test` surface from #71; no new test framework introduced.              | PASS   |
| Quality Gates       | `terraform fmt -check -recursive` already runs in CI; mission must leave it green.              | PASS   |
| Performance Bench.  | NFR-001 sets a ±10% startup-time guard per template, measured over 3 runs.                      | PASS   |
| Governance Activ.   | Mission is governed under Spec Kitty 3.1.8; charter is `software-dev-default`.                  | PASS   |

No violations to log in Complexity Tracking.

## Project Structure

### Documentation (this mission)

```
kitty-specs/extract-template-startup-scripts-01KRCDD7/
├── spec.md              # Source of truth (already committed)
├── plan.md              # This file
├── meta.json            # Mission identity
├── research.md          # Phase 0 output (see Phase 0)
├── data-model.md        # Phase 1 output (see Phase 1) — minimal here, no domain data
├── quickstart.md        # Phase 1 output (see Phase 1)
├── contracts/           # Phase 1 output (see Phase 1) — script interface contracts
├── checklists/
│   └── requirements.md  # Already committed
└── tasks/               # Filled by /spec-kitty.tasks later
```

### Source code (repository root, post-refactor)

```
coder-ddev/
├── drupal-contrib/
│   ├── template.tf                     # MODIFIED: startup_script = file("${path.module}/../scripts/templates/drupal-contrib/startup.sh")
│   ├── scripts/                        # UNCHANGED (existing test helpers)
│   └── tests/                          # UNCHANGED
├── drupal-core/
│   ├── template.tf                     # MODIFIED (same shape)
│   ├── scripts/                        # UNCHANGED
│   └── tests/                          # UNCHANGED
├── freeform/
│   ├── template.tf                     # MODIFIED (same shape)
│   ├── scripts/                        # UNCHANGED
│   └── tests/                          # UNCHANGED
├── user-defined-web/
│   ├── template.tf                     # MODIFIED (same shape)
│   └── tests/                          # UNCHANGED
└── scripts/
    ├── templates/                      # NEW
    │   ├── drupal-contrib/
    │   │   └── startup.sh              # NEW (~692 lines from the heredoc, minus what gets factored into shared/)
    │   ├── drupal-core/
    │   │   └── startup.sh              # NEW (~921 lines)
    │   ├── freeform/
    │   │   └── startup.sh              # NEW (~225 lines)
    │   └── user-defined-web/
    │       └── startup.sh              # NEW (~340 lines)
    ├── shared/                         # NEW
    │   ├── lib.sh                      # NEW — common header (logging, set -e, traps)
    │   ├── start-dockerd.sh            # NEW — start dockerd + wait for socket (candidate, validated in Phase 0)
    │   ├── hydrate-coder-files.sh      # NEW — copy /home/coder-files/* into /home/coder (candidate)
    │   └── install-ddev-config.sh      # NEW — place ~/.ddev/global_config.yaml (candidate)
    ├── cleanup-deleted-workspaces.sh   # UNCHANGED (existing top-level script)
    ├── coder-delete-workspace-dir.sh   # UNCHANGED
    ├── coder-discord-relay             # UNCHANGED
    └── coder-discord-relay.service     # UNCHANGED
```

**Structure Decision**: New runtime helpers live at repo root under `scripts/templates/<name>/` and `scripts/shared/`. Existing per-template `scripts/` directories (test helpers) are left alone (C-005). Existing repo-root `scripts/` contents (cleanup, discord relay) are unchanged.

## Phase 0 — Outline & Research

Goal: validate the technical assumptions before WP execution. Deliverable: [`research.md`](research.md).

Research items:

1. **Interpolation manifest (DONE during planning)** — see table below. No surprises; all `${...}` Terraform interpolations are simple variable assignments at heredoc top, can be moved to `coder_agent.env` cleanly.

2. **Terraform `file()` path resolution** — verify `${path.module}/../scripts/templates/<name>/startup.sh` resolves correctly from each template directory.

3. **`coder_agent.env` semantics** — confirm `coder_agent` accepts a map of env vars and exposes them to `startup_script` execution.

4. **Cross-template duplication audit** — quantify true lexical duplication for shared-helper candidates. Plan-phase guess (validated during WP5): dockerd start, `/home/coder-files/` hydration, DDEV global_config placement, GitSSH wrapper, locale/PATH setup.

5. **Test surface for `user-defined-web`** — the CLAUDE.md "pre-push checklist" only lists `terraform test` for `drupal-core`, `drupal-contrib`, `freeform`. Confirm `user-defined-web` ships no `terraform test` files (only `tests/` shell helpers), and verify FR-009 stays accurate.

### Interpolation manifest (validated during planning)

| Template            | Terraform `${...}` references (1 per line)                                                                                                                                                                                                                                  | `$${...}` escapes (shell `${VAR}`) | Loading mechanism                |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------- | -------------------------------- |
| `drupal-contrib`    | `var.docker_registry_mirror`, `data.coder_parameter.project_name.value`, `data.coder_parameter.project_type.value`, `data.coder_parameter.issue_fork.value`, `data.coder_parameter.issue_branch.value`, `data.coder_parameter.drupal_version.value`, `data.coder_parameter.install_profile.value` | 31 occurrences                     | `file()` + 7 env-var injections  |
| `drupal-core`       | `var.docker_registry_mirror`, `data.coder_parameter.issue_fork.value`, `data.coder_parameter.issue_branch.value`, `data.coder_parameter.install_profile.value`, `data.coder_parameter.drupal_version.value`                                                                  | 42 occurrences                     | `file()` + 5 env-var injections  |
| `freeform`          | `var.docker_registry_mirror`                                                                                                                                                                                                                                                | 1 occurrence                       | `file()` + 1 env-var injection   |
| `user-defined-web`  | `var.docker_registry_mirror`                                                                                                                                                                                                                                                | 0 occurrences                      | `file()` + 1 env-var injection   |

All Terraform interpolations are top-of-heredoc assignments to `NAME=` shell variables — trivially convertible to `env = { NAME = ... }` on the `coder_agent` resource. The `$${...}` escapes become normal `${...}` in the extracted `.sh` files (the whole point of leaving HCL string scope).

## Phase 1 — Design & Contracts

Goal: produce the planning artifacts needed by `/spec-kitty.tasks`.

### data-model.md (minimal)

This mission has no domain data model. `data-model.md` will document the **script interface** instead:
- Each per-template `startup.sh` is invoked as `bash startup.sh` (no args).
- Required env vars per template (from interpolation manifest above) — listed by template.
- Optional sourcing of `scripts/shared/lib.sh` for common logging/traps.

### contracts/

Script contracts (one Markdown stub per shared helper) describing:
- Helper name and source path
- Inputs (env vars)
- Outputs (files written, services started, ports opened)
- Exit-code contract
- Idempotency notes

### quickstart.md

A short "how to validate this mission locally" document:
1. `terraform fmt -check -recursive`
2. For each template: `terraform -chdir=<t> init -backend=false && terraform -chdir=<t> validate`
3. For `drupal-core`, `drupal-contrib`, `freeform`: `terraform -chdir=<t> test`
4. Boot one workspace per template against `staging-coder.ddev.com` (or local Coder host), confirm same end state.
5. Diff helper: `git diff upstream/main...HEAD -- '*.tf'` to confirm `.tf` diffs are minimal.

## WP Sequencing (preview for `/spec-kitty.tasks`)

| WP   | Title                                                       | Scope                                                                                                                                                       | Verification                                                                                          |
| ---- | ----------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| WP1  | Scaffold `scripts/templates/` + `scripts/shared/lib.sh`     | Create new directories. Add `scripts/shared/lib.sh` with shared header (shebang, `set -euo pipefail`, simple `log()` and `die()` helpers). No template changes. | `bash -n scripts/shared/lib.sh`; shellcheck (if available); `terraform fmt -check`.                   |
| WP2  | Extract `freeform/startup_script`                           | Smallest template (~225 lines, 1 Terraform interpolation, 1 escape). Move heredoc body to `scripts/templates/freeform/startup.sh`. Replace heredoc with `file()` + `env = {...}`. | `terraform -chdir=freeform validate && test`; smoke-boot one freeform workspace.                       |
| WP3  | Extract `user-defined-web/startup_script`                   | ~340 lines, 1 Terraform interpolation, 0 escapes. Same shape as WP2.                                                                                         | `terraform -chdir=user-defined-web validate`; smoke-boot one workspace (no `terraform test` exists here per Phase 0 item 5). |
| WP4  | Extract `drupal-contrib/startup_script`                     | ~692 lines, 7 Terraform interpolations, 31 escapes. Same shape, more env vars.                                                                              | `terraform -chdir=drupal-contrib validate && test`; smoke-boot.                                       |
| WP5  | Extract `drupal-core/startup_script`                        | ~921 lines, 5 Terraform interpolations, 42 escapes. Largest extract.                                                                                        | `terraform -chdir=drupal-core validate && test`; smoke-boot.                                          |
| WP6  | Consolidate shared helpers                                  | After WP2–WP5, factor lexically duplicated logic into `scripts/shared/*.sh` (candidates: dockerd start, hydrate-coder-files, DDEV config install, GitSSH wrapper). Source from each per-template `startup.sh`. | Re-run `terraform -chdir=<t> validate && test` for all templates; re-run smoke-boot per template.       |
| WP7  | Open draft PR + finalize                                    | `git push origin extract-template-startup-scripts`; open draft PR `jonesrussell/coder-ddev:extract-template-startup-scripts` → `ddev/coder-ddev:main`. Fill in PR body referencing #76 and listing follow-up issues to file. | PR created in draft mode; CI green; PR description checklist matches success criteria.                |

**Sequencing rationale**: One template per WP, smallest → largest, so each WP is independently reviewable and risk grows monotonically. Shared helpers are extracted **after** all four templates land as monolithic per-template scripts (WP6), because lexical duplication is only fully visible once all four are extracted; this avoids speculative factoring in WP2 that later gets refactored in WP4.

**Dependency graph (linear)**: WP1 → WP2 → WP3 → WP4 → WP5 → WP6 → WP7. No parallel lanes recommended — each WP touches `scripts/` and a template's `template.tf`; sequential review keeps the diff readable. (Spec Kitty may still allocate lanes per its policy; the linear chain is what the plan recommends.)

## Re-check Charter Check (post-design)

No new gates triggered by the Phase 0 / Phase 1 design. The plan introduces no new tools, no new test framework, no new runtime. PASS.

## Complexity Tracking

*Empty — no Charter violations to justify.*

## Open Items for `/spec-kitty.tasks`

- Translate WP1–WP7 above into work-package files under `tasks/`.
- For WP2–WP5, include a pre-flight grep step (`grep -c '\${' template.tf` before/after) as part of the acceptance check, to catch stranded Terraform interpolations.
- For WP6, the helper list is **candidate** until WP2–WP5 reveal the actual duplication; WP6 may end up smaller than scaffolded.
