---
work_package_id: WP03
title: Cross-link mission to OpenSpec change and open draft PR
dependencies:
- WP01
- WP02
requirement_refs:
- C-002
- C-003
- FR-006
- FR-007
- FR-008
- FR-009
- FR-010
planning_base_branch: spec-workspace-runtime-contract
merge_target_branch: spec-workspace-runtime-contract
branch_strategy: Planning artifacts for this feature were generated on spec-workspace-runtime-contract. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into spec-workspace-runtime-contract unless the human explicitly redirects the landing branch.
subtasks:
- T010
- T011
- T012
- T013
- T014
history: []
authoritative_surface: kitty-specs/workspace-runtime-contract-01KRC8WY/meta.json
execution_mode: code_change
owned_files:
- kitty-specs/workspace-runtime-contract-01KRC8WY/meta.json
tags: []
---

# WP03 — Cross-link mission to OpenSpec and open draft PR

## Goal

Bind the Spec Kitty mission and the OpenSpec change with bidirectional references, verify pre-push gates, and open a **draft** pull request against `ddev/coder-ddev:main`.

## Inputs

- WP01 and WP02 completed outputs.
- `CLAUDE.md` pre-push checklist (terraform fmt/validate/test).
- `gh` CLI with `upstream` remote pointing at `ddev/coder-ddev`.

## Subtasks

- **T010** — Update `kitty-specs/workspace-runtime-contract-01KRC8WY/meta.json`: extend `source_description` to reference the OpenSpec change-id `add-workspace-runtime-contract` (without breaking schema).
- **T011** — Re-confirm `openspec/changes/add-workspace-runtime-contract/proposal.md` carries the "Spec Kitty Mission: `workspace-runtime-contract-01KRC8WY`" cross-link added in WP01.
- **T012** — Run `openspec validate add-workspace-runtime-contract --strict`; remediate any failures by editing only WP02 outputs.
- **T013** — Run `terraform fmt -check -recursive` and confirm zero changes (defensive — no HCL touched).
- **T014** — Open a draft PR with `gh pr create --draft --repo ddev/coder-ddev --base main --head jonesrussell:spec-workspace-runtime-contract --title "spec: workspace-runtime-contract (foundational spec)" --body-file <body>` where `<body>` references the OpenSpec change-id, the Spec Kitty mission slug, the descriptive-first nature of the change, and the known-drift catalog. Confirm PR is in draft state.

## Success Criteria

- `meta.json` references the OpenSpec change-id.
- `openspec validate add-workspace-runtime-contract --strict` is green.
- `terraform fmt -recursive` clean.
- Draft PR exists on `ddev/coder-ddev:main`. PR URL captured in the WP completion notes.
- No file under `image/`, `*/template.tf`, `*/scripts/`, or `Makefile` in the PR diff.
