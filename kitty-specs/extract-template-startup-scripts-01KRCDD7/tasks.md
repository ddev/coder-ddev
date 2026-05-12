# Tasks — Extract Template Startup Scripts

**Mission**: `extract-template-startup-scripts-01KRCDD7`
**Branch**: `extract-template-startup-scripts` (off `upstream/main`)
**Final merge target**: `ddev/coder-ddev:main` (draft PR)
**Source**: ddev/coder-ddev#76
**Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

## Subtask Index

| ID    | Description                                                                                  | WP   | Parallel |
| ----- | -------------------------------------------------------------------------------------------- | ---- | -------- |
| T001  | Scaffold `scripts/templates/` and `scripts/shared/` directories                              | WP01 |          | [D] |
| T002  | Write `scripts/shared/lib.sh` (prelude: shebang, strict mode, log/warn/die)                  | WP01 |          | [D] |
| T003  | Smoke-validate the scaffold (`bash -n`, `shellcheck` if present, `terraform fmt -check`)     | WP01 |          | [D] |
| T004  | Capture `freeform` pre-refactor baseline (interpolation grep + boot time)                    | WP02 |          | [D] |
| T005  | Extract `freeform` `startup_script` heredoc to `scripts/templates/freeform/startup.sh`       | WP02 |          | [D] |
| T006  | Replace `freeform` `startup_script` with `file()` + `env = { REGISTRY_MIRROR = ... }`        | WP02 |          | [D] |
| T007  | Verify `freeform`: `terraform fmt`, `validate`, `test`; boot-time within ±10% of baseline    | WP02 |          | [D] |
| T008  | Capture `user-defined-web` pre-refactor baseline                                              | WP03 |          |
| T009  | Extract `user-defined-web` heredoc to `scripts/templates/user-defined-web/startup.sh`         | WP03 |          |
| T010  | Replace `user-defined-web` heredoc with `file()` + `env = { REGISTRY_MIRROR = ... }`          | WP03 |          |
| T011  | Verify `user-defined-web`: `fmt`, `validate`, smoke-boot (no `terraform test` exists)         | WP03 |          |
| T012  | Capture `drupal-contrib` pre-refactor baseline (7 Terraform refs, 31 `$${}` escapes)         | WP04 |          |
| T013  | Extract `drupal-contrib` heredoc to `scripts/templates/drupal-contrib/startup.sh`             | WP04 |          |
| T014  | Convert 7 Terraform interpolations to `env = { ... }` entries; un-escape 31 `$${}` → `${}`    | WP04 |          |
| T015  | Replace `drupal-contrib` heredoc with `file()` + 7-key env block                              | WP04 |          |
| T016  | Verify `drupal-contrib`: `fmt`, `validate`, `test`; boot-time within ±10%                     | WP04 |          |
| T017  | Capture `drupal-core` pre-refactor baseline (5 Terraform refs, 42 `$${}` escapes)            | WP05 |          |
| T018  | Extract `drupal-core` heredoc to `scripts/templates/drupal-core/startup.sh`                   | WP05 |          |
| T019  | Convert 5 Terraform interpolations to `env = { ... }` entries; un-escape 42 `$${}` → `${}`    | WP05 |          |
| T020  | Replace `drupal-core` heredoc with `file()` + 5-key env block                                 | WP05 |          |
| T021  | Verify `drupal-core`: `fmt`, `validate`, `test`; boot-time within ±10%                        | WP05 |          |
| T022  | Side-by-side audit of the 4 extracted `startup.sh` files; identify lexically duplicated blocks | WP06 |          |
| T023  | Implement candidate shared helpers under `scripts/shared/` per audit findings                 | WP06 |          |
| T024  | Update per-template `startup.sh` files to source shared helpers; remove now-duplicated bash   | WP06 |          |
| T025  | Re-verify all 4 templates: `fmt`, `validate`, `test`; confirm ≥1 helper sourced by ≥2 callers | WP06 |          |
| T026  | Write `AUDIT.md` summarizing what was factored vs. left inline and why                        | WP06 |          |
| T027  | Generate PR body (`pr-body.md`) referencing #76 + listed follow-up issues                     | WP07 |          |
| T028  | Push branch to `origin`; open draft PR `jonesrussell:extract-template-startup-scripts` → `ddev/coder-ddev:main` | WP07 |          |
| T029  | Confirm CI green; verify final diff against Success Criteria checklist                        | WP07 |          |

## Work Packages

### WP01 — Scaffold `scripts/templates/` + `scripts/shared/lib.sh`

**Goal**: Create the directory layout and a minimal shared prelude that every per-template script will source. No template changes.
**Priority**: Foundation (must run first).
**Dependencies**: none.
**Independent test**: `bash -n scripts/shared/lib.sh && terraform fmt -check -recursive`.
**Estimated prompt**: ~250 lines.

Included subtasks:
- [x] T001 Scaffold `scripts/templates/` and `scripts/shared/` directories (WP01)
- [x] T002 Write `scripts/shared/lib.sh` (prelude: shebang, strict mode, log/warn/die) (WP01)
- [x] T003 Smoke-validate the scaffold (`bash -n`, `shellcheck` if present, `terraform fmt -check`) (WP01)

Prompt: [`tasks/WP01-scaffold-scripts-and-shared-lib.md`](tasks/WP01-scaffold-scripts-and-shared-lib.md)

### WP02 — Extract `freeform` `startup_script`

**Goal**: Extract ~225 lines of inline bash from `freeform/template.tf` into `scripts/templates/freeform/startup.sh` and replace the heredoc with `file(...)` + `env`. Smallest template — used to validate the extraction pattern before tackling larger ones.
**Priority**: First extraction (pilot for the pattern).
**Dependencies**: WP01.
**Independent test**: `terraform -chdir=freeform init -backend=false && terraform -chdir=freeform validate && terraform -chdir=freeform test`; live boot of a freeform workspace stays within ±10% of pre-refactor baseline.
**Estimated prompt**: ~350 lines.

Included subtasks:
- [x] T004 Capture `freeform` pre-refactor baseline (interpolation grep + boot time) (WP02)
- [x] T005 Extract `freeform` `startup_script` heredoc to `scripts/templates/freeform/startup.sh` (WP02)
- [x] T006 Replace `freeform` `startup_script` with `file()` + `env = { REGISTRY_MIRROR = ... }` (WP02)
- [x] T007 Verify `freeform`: `terraform fmt`, `validate`, `test`; boot-time within ±10% of baseline (WP02)

Prompt: [`tasks/WP02-extract-freeform-startup.md`](tasks/WP02-extract-freeform-startup.md)

### WP03 — Extract `user-defined-web` `startup_script`

**Goal**: Same extraction pattern as WP02, applied to `user-defined-web` (~340 lines, 1 Terraform interpolation, 0 shell escapes).
**Priority**: Second extraction.
**Dependencies**: WP02.
**Independent test**: `terraform -chdir=user-defined-web validate` + live smoke-boot. (`user-defined-web` has no `terraform test` files — see research.md R5.)
**Estimated prompt**: ~350 lines.

Included subtasks:
- [ ] T008 Capture `user-defined-web` pre-refactor baseline (WP03)
- [ ] T009 Extract `user-defined-web` heredoc to `scripts/templates/user-defined-web/startup.sh` (WP03)
- [ ] T010 Replace `user-defined-web` heredoc with `file()` + `env = { REGISTRY_MIRROR = ... }` (WP03)
- [ ] T011 Verify `user-defined-web`: `fmt`, `validate`, smoke-boot (no `terraform test` exists) (WP03)

Prompt: [`tasks/WP03-extract-user-defined-web-startup.md`](tasks/WP03-extract-user-defined-web-startup.md)

### WP04 — Extract `drupal-contrib` `startup_script`

**Goal**: Extract ~692 lines from `drupal-contrib/template.tf`. 7 Terraform interpolations promoted to `env`, 31 `$${...}` escapes un-escaped to `${...}` in the extracted script.
**Priority**: Third extraction (larger, more env vars).
**Dependencies**: WP03.
**Independent test**: `terraform -chdir=drupal-contrib validate && terraform -chdir=drupal-contrib test`; live smoke-boot within ±10%.
**Estimated prompt**: ~420 lines.

Included subtasks:
- [ ] T012 Capture `drupal-contrib` pre-refactor baseline (7 Terraform refs, 31 `$${}` escapes) (WP04)
- [ ] T013 Extract `drupal-contrib` heredoc to `scripts/templates/drupal-contrib/startup.sh` (WP04)
- [ ] T014 Convert 7 Terraform interpolations to `env = { ... }` entries; un-escape 31 `$${}` → `${}` (WP04)
- [ ] T015 Replace `drupal-contrib` heredoc with `file()` + 7-key env block (WP04)
- [ ] T016 Verify `drupal-contrib`: `fmt`, `validate`, `test`; boot-time within ±10% (WP04)

Prompt: [`tasks/WP04-extract-drupal-contrib-startup.md`](tasks/WP04-extract-drupal-contrib-startup.md)

### WP05 — Extract `drupal-core` `startup_script`

**Goal**: Extract ~921 lines from `drupal-core/template.tf` — the largest heredoc. 5 Terraform interpolations promoted to `env`, 42 `$${...}` escapes un-escaped.
**Priority**: Fourth extraction (largest).
**Dependencies**: WP04.
**Independent test**: `terraform -chdir=drupal-core validate && test`; live smoke-boot within ±10%.
**Estimated prompt**: ~440 lines.

Included subtasks:
- [ ] T017 Capture `drupal-core` pre-refactor baseline (5 Terraform refs, 42 `$${}` escapes) (WP05)
- [ ] T018 Extract `drupal-core` heredoc to `scripts/templates/drupal-core/startup.sh` (WP05)
- [ ] T019 Convert 5 Terraform interpolations to `env = { ... }` entries; un-escape 42 `$${}` → `${}` (WP05)
- [ ] T020 Replace `drupal-core` heredoc with `file()` + 5-key env block (WP05)
- [ ] T021 Verify `drupal-core`: `fmt`, `validate`, `test`; boot-time within ±10% (WP05)

Prompt: [`tasks/WP05-extract-drupal-core-startup.md`](tasks/WP05-extract-drupal-core-startup.md)

### WP06 — Consolidate shared helpers

**Goal**: Identify lexically duplicated blocks across the 4 extracted `startup.sh` files, extract them to `scripts/shared/*.sh`, update each per-template `startup.sh` to source the helpers, and remove the now-duplicated bash. Satisfies Success Criterion #4 (≥1 helper sourced by ≥2 templates).
**Priority**: Consolidation.
**Dependencies**: WP05.
**Independent test**: Re-run `terraform -chdir=<t> validate && test` for all 4 templates; manually verify ≥1 helper under `scripts/shared/` is sourced by ≥2 per-template `startup.sh` files.
**Estimated prompt**: ~480 lines.

**Note on ownership**: This WP modifies per-template `startup.sh` files written in WP02–WP05. Sequencing (dependency on WP05) makes this safe; ownership overlap is documented in this WP's frontmatter rather than enforced by partition.

Included subtasks:
- [ ] T022 Side-by-side audit of the 4 extracted `startup.sh` files; identify lexically duplicated blocks (WP06)
- [ ] T023 Implement candidate shared helpers under `scripts/shared/` per audit findings (WP06)
- [ ] T024 Update per-template `startup.sh` files to source shared helpers; remove now-duplicated bash (WP06)
- [ ] T025 Re-verify all 4 templates: `fmt`, `validate`, `test`; confirm ≥1 helper sourced by ≥2 callers (WP06)
- [ ] T026 Write `scripts/shared/AUDIT.md` summarizing what was factored vs. left inline and why (WP06)

Prompt: [`tasks/WP06-consolidate-shared-helpers.md`](tasks/WP06-consolidate-shared-helpers.md)

### WP07 — Open draft PR + finalize

**Goal**: Push the branch and open a draft PR against `ddev/coder-ddev:main` from `jonesrussell:extract-template-startup-scripts`. Confirm CI is green and the final diff matches the Success Criteria checklist.
**Priority**: Ship.
**Dependencies**: WP06.
**Independent test**: PR exists in draft mode; CI green; PR body checklist matches spec.md Success Criteria.
**Estimated prompt**: ~220 lines.

Included subtasks:
- [ ] T027 Generate PR body (`pr-body.md`) referencing #76 + listed follow-up issues (WP07)
- [ ] T028 Push branch to `origin`; open draft PR `jonesrussell:extract-template-startup-scripts` → `ddev/coder-ddev:main` (WP07)
- [ ] T029 Confirm CI green; verify final diff against Success Criteria checklist (WP07)

Prompt: [`tasks/WP07-open-draft-pr.md`](tasks/WP07-open-draft-pr.md)

## Dependency graph

```
WP01 ──► WP02 ──► WP03 ──► WP04 ──► WP05 ──► WP06 ──► WP07
```

Linear chain. No parallel lanes — each WP touches `scripts/` and a `template.tf`, so sequential review keeps the diff readable. Risk grows monotonically with template size.

## MVP scope

WP01 + WP02 (freeform extraction) is the smallest shippable demonstration of the pattern. If the project ever needs to pause the mission, that's a coherent stopping point — freeform is the smallest template and proves the `file()` + `env` mechanism end-to-end.
