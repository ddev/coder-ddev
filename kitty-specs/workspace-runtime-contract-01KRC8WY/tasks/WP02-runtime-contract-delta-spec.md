---
work_package_id: WP02
title: Author workspace-runtime delta spec with INV-1..INV-9 + drift catalog
dependencies:
- WP01
requirement_refs:
- C-004
- C-005
- FR-002
- FR-003
- FR-004
- FR-005
planning_base_branch: spec-workspace-runtime-contract
merge_target_branch: spec-workspace-runtime-contract
branch_strategy: Planning artifacts for this feature were generated on spec-workspace-runtime-contract. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into spec-workspace-runtime-contract unless the human explicitly redirects the landing branch.
subtasks:
- T005
- T006
- T007
- T008
- T009
history: []
authoritative_surface: openspec/changes/add-workspace-runtime-contract/specs/workspace-runtime/spec.md
execution_mode: doc_change
owned_files:
- openspec/changes/add-workspace-runtime-contract/specs/workspace-runtime/spec.md
tags: []
---

# WP02 — Author the runtime-contract delta spec

## Goal

Write the OpenSpec delta spec for capability `workspace-runtime` with nine `## ADDED Requirements`, the boot-sequence and forbidden-behavior requirements, and an informational `## Known Drift` block.

## Inputs

- WP01 outputs (proposal, design, tasks).
- Mission spec.md (FRs).
- Mission data-model.md (INV-1…INV-9 entities, coverage matrix).
- Mission research.md (drift D-1…D-6).
- Existing OpenSpec delta-spec examples under `openspec/changes/*/specs/*/spec.md`.

## Subtasks

- **T005** — Create directory `openspec/changes/add-workspace-runtime-contract/specs/workspace-runtime/`.
- **T006** — Write `spec.md` opening (purpose, scope, derivation, dependency note).
- **T007** — Write nine `## ADDED Requirements` blocks (INV-1…INV-9). Each requirement: clear "shall" statement + at least one `#### Scenario:` describing a verifiable observation in the running workspace.
- **T008** — Write the boot sequence and forbidden-behavior requirements (the §3/§4 of the drafted contract) as scenario-bearing requirements.
- **T009** — Write the `## Known Drift` block enumerating D-1…D-6 as informational (not enforced); each entry names the affected invariant.

## Success Criteria

- File at `openspec/changes/add-workspace-runtime-contract/specs/workspace-runtime/spec.md`.
- `openspec validate add-workspace-runtime-contract --strict` is green.
- Each `ADDED Requirement` has at least one `#### Scenario:`.
- Drift block is clearly labeled informational and cites the relevant source files.
