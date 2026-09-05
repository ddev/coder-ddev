# Implementation Plan: Workspace Runtime Contract

**Branch**: `spec-workspace-runtime-contract` | **Date**: 2026-05-11 | **Spec**: `kitty-specs/workspace-runtime-contract-01KRC8WY/spec.md`
**Input**: Mission specification + descriptive-first contract synthesized from `image/Dockerfile`, `user-defined-web/template.tf`, and the inlined `startup_script`.

## Summary

Deliver the foundational `workspace-runtime-contract` as **proposal artifacts only**. The work consists of three coordinated outputs: (1) the Spec Kitty mission artifacts (spec.md, plan.md, research.md, data-model.md), already in flight; (2) the OpenSpec change `add-workspace-runtime-contract` with proposal, design, tasks, and a delta spec under `openspec/changes/add-workspace-runtime-contract/specs/workspace-runtime/spec.md`; (3) a cross-link layer joining the two systems via `meta.json` and the OpenSpec proposal body. No code under `image/`, `*/template.tf`, `*/scripts/`, or `Makefile` is touched.

## Technical Context

**Language/Version**: Markdown (specs), JSON (mission metadata), Terraform HCL (already in place — not modified).
**Primary Dependencies**: `spec-kitty-cli` 3.1.8, `openspec` CLI, `gh` CLI, `terraform` ≥ 1.5.
**Storage**: Filesystem (mission dir, openspec/changes dir), git (auto-committed by Spec Kitty + manual commits for OpenSpec).
**Testing**: `openspec validate add-workspace-runtime-contract --strict`; `terraform fmt -check -recursive`; mission `status.json` lane invariants.
**Target Platform**: WSL2 / Linux host running the agent; PR targets `ddev/coder-ddev:main` on GitHub.
**Project Type**: Documentation/governance change. No source code modifications.
**Performance Goals**: N/A.
**Constraints**: No edits outside `kitty-specs/workspace-runtime-contract-01KRC8WY/`, `openspec/changes/add-workspace-runtime-contract/`, and the eventual PR body. Draft PR only.
**Scale/Scope**: One foundational spec, nine invariants, six drift items, one OpenSpec change.

## Charter Check

Charter directive #1 (respect risk boundaries) identifies image, template, and startup-script changes as high-risk. This mission **does not modify** any of those surfaces; it only describes them. Charter directive #2 (keep documentation synchronized) is partially satisfied: the spec captures the current contract, but `CLAUDE.md` reconciliation is deferred to a follow-up change (FR-010). No charter gate is violated.

**Quality gates (from charter):**
- All changes via PR — satisfied.
- `terraform fmt -check` — satisfied (no HCL touched).
- `terraform validate` — satisfied (no HCL touched).
- `terraform test` — N/A (no HCL touched).
- Staging integration tests — N/A (no runtime behavior changes).

## Project Structure

### Documentation (this mission)

```
kitty-specs/workspace-runtime-contract-01KRC8WY/
├── spec.md                # Mission specification (filled)
├── plan.md                # This file
├── research.md            # Decisions + drift catalog (filled)
├── data-model.md          # INV-1…INV-9 entities + coverage matrix (filled)
├── research/
│   ├── evidence-log.csv   # Invariant → file/line evidence (filled)
│   └── source-register.csv# Source files used in synthesis (filled)
├── tasks.md               # WP manifest (next phase output)
├── wps.yaml               # Work package list (next phase output)
├── lanes.json             # Lane allocation (next phase output)
├── tasks/                 # Per-WP prompt files (next phase output)
├── meta.json              # Mission identity + OpenSpec cross-link
└── mission-events.jsonl   # Append-only event log
```

### Change artifacts (OpenSpec — created during implement phase)

```
openspec/changes/add-workspace-runtime-contract/
├── proposal.md
├── design.md
├── tasks.md
└── specs/workspace-runtime/spec.md   # The delta spec (ADDED Requirements x9)
```

**Structure Decision**: This is a *documentation-and-governance* mission. There is no source-code structure to choose. The two artifact homes (`kitty-specs/...` and `openspec/changes/...`) are joined by cross-references; no third location is introduced.

## Phases

### Phase 0 — Discovery (complete)
- Research artifacts populated from prior architectural analyses.
- Drift items D-1…D-6 cataloged as informational, not remediated here.

### Phase 1 — Specify (complete)
- Mission `spec.md` written with FR-001…FR-010 and C-001…C-005.
- Cross-link plan recorded in research (mission → OpenSpec change-id via `source_description` plus link in `proposal.md`).

### Phase 2 — Plan (this document)
- Confirm charter gates.
- Decide WP allocation (Phase 3 input).

### Phase 3 — Tasks (next)
The mission needs three work packages, each scoped to a non-overlapping artifact tree:

| WP | Title | Owned files | Depends on |
|----|-------|-------------|-----------|
| WP01 | Author OpenSpec proposal scaffold | `openspec/changes/add-workspace-runtime-contract/proposal.md`, `design.md`, `tasks.md` | — |
| WP02 | Author runtime-contract delta spec | `openspec/changes/add-workspace-runtime-contract/specs/workspace-runtime/spec.md` | WP01 |
| WP03 | Cross-link mission to OpenSpec + draft PR | `kitty-specs/workspace-runtime-contract-01KRC8WY/meta.json` (extend `source_description`), PR body | WP01, WP02 |

Each WP carries an FR ref set drawn from FR-001…FR-010 above. None modifies image, template, script, or Makefile.

### Phase 4 — Implement
- WPs executed sequentially (small dependency chain; parallelism not worthwhile).
- Each WP commits via Spec Kitty auto-commit on the mission branch.

### Phase 5 — Review and Accept
- `openspec validate add-workspace-runtime-contract --strict` must pass.
- `terraform fmt -check -recursive` must pass (defensive — no HCL touched, but enforced).
- Spec Kitty `accept` step validates lane state.

### Phase 6 — Merge (out of scope for this mission)
- A draft PR is opened against `upstream/main` (`ddev/coder-ddev:main`).
- Spec Kitty `merge` is **not** invoked — the PR remains draft until human reviewer approval.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Two governance systems active (OpenSpec + Spec Kitty) | Repo already has both initialized; unifying would itself be a larger change | Forcing a single system now would block on a decision this mission is not authorized to make |
| Three WPs for a documentation-only mission | Each artifact tree must be edited independently; lane `write_scope` prevents overlap | Bundling would obscure provenance and break the lane model |

## Risks

- **Auto-commit conflicts** — Spec Kitty's `auto_commit: true` interacts with manual commits for OpenSpec artifacts. Mitigation: stage OpenSpec files explicitly before invoking Spec Kitty steps to keep auto-commits scoped.
- **CLI/project version drift** — already encountered (3.1.7 vs 3.1.8). Mitigation: upgrade resolved; document in research.
- **PR base** — branch was created from `upstream/main`; PR must target `ddev/coder-ddev:main`, not `jonesrussell/coder-ddev:main`. Mitigation: explicit `-R ddev/coder-ddev` in `gh pr create`.
- **Existing live mission** (`github-org-gated-signup-01KR1P4G`) is concurrent. Mitigation: separate branch (`spec-workspace-runtime-contract`) isolates auto-commits.

## Done When

- All three WPs in `done` or `approved` lane in `status.json`.
- `openspec validate add-workspace-runtime-contract --strict` is green.
- Draft PR open against `ddev/coder-ddev:main` with body referencing change-id and mission slug.
- No file under `image/`, `*/template.tf`, `*/scripts/`, or `Makefile` in the PR diff.
