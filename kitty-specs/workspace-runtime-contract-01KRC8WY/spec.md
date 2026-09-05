# Workspace Runtime Contract

## Summary

Establish `workspace-runtime-contract` as the foundational Spec Kitty / OpenSpec specification for the `coder-ddev` repository. The contract codifies the nine load-bearing invariants of a Coder workspace provisioned from a `coder-ddev` template: Sysbox isolation, UID/GID identity, sudo posture, in-container `dockerd` lifecycle, two-volume persistence model, copy-if-missing hydration from `/home/coder-files`, single-project direct-bind web routing, host-aware cleanup, and env-sourced workspace identity.

This mission delivers the contract as **proposal artifacts only** — no image, template, or script behavior changes. The spec is **descriptive-first**, extracted from current behavior in `image/Dockerfile`, `user-defined-web/template.tf`, and the inlined `startup_script`. It is the precondition for every later governance change in this repo.

**Related work:**

- OpenSpec change (drafted in this PR): `add-workspace-runtime-contract`.
- Charter directive #1 ("respect risk boundaries") names the surfaces this contract covers as high-risk.
- Known drift items D-1…D-6 are tracked inside `research.md` and remediated in **follow-up** OpenSpec changes, not in this mission.

## Goals

- Land the OpenSpec change `add-workspace-runtime-contract` with a full delta spec under `openspec/changes/add-workspace-runtime-contract/specs/workspace-runtime/spec.md`.
- Make `workspace-runtime-contract` the named dependency of every future template, image, or runtime spec.
- Document known drift (D-1…D-6) inside the research/spec so follow-up changes have a registered place to attach.
- Establish the convention that a Spec Kitty mission wraps an OpenSpec change (cross-linked via mission `meta.json` and the OpenSpec proposal body).

## Non-Goals

- No changes to `image/Dockerfile`, any `template.tf`, the inlined `startup_script`, or `Makefile`.
- No CI gate is added in this mission. CI integration is reserved for Phase 4 of the broader Spec Kitty adoption plan.
- No remediation of known drift items D-1…D-6; each gets its own OpenSpec proposal once the foundational spec is archived.
- No removal of the systemd-as-init code path in the image (forbidden by INV F-9 but retained pending a follow-up change).
- No reconciliation of `CLAUDE.md` architecture prose with the new spec; that follows after archive.

## User Scenarios & Testing

These scenarios describe agent and reviewer behavior the spec must enable, not workspace runtime behavior (which is already in place).

**Scenario 1 — proposal author scaffolds compliantly:**
An agent invokes the `openspec-proposal` workflow with a change that modifies `image/Dockerfile`. The agent reads `workspace-runtime-contract`, identifies which invariants are touched, and writes a delta spec referencing the affected requirements by ID.

**Scenario 2 — reviewer audits a template change:**
A reviewer opens a PR that edits `user-defined-web/template.tf`. The PR body links the OpenSpec change-id and the Spec Kitty mission slug. The reviewer reads the linked spec text and confirms each invariant is preserved or explicitly modified.

**Scenario 3 — drift remediation is filed against the spec:**
A contributor notices that `image/scripts/.ddev/global_config.yaml` is missing (drift item D-1). They open a follow-up OpenSpec change `restore-ddev-global-config` that cites `workspace-runtime-contract` D-1 and adds a `MODIFIED Requirements` delta.

**Scenario 4 — agent declines to write code at proposal stage:**
An agent receives this mission's WP01 prompt. It produces only `proposal.md`, `tasks.md`, `design.md`, and the spec delta — no edits to `image/`, `*/template.tf`, or `startup_script`. `openspec validate add-workspace-runtime-contract --strict` passes.

**Scenario 5 — draft PR is created, not merged:**
The mission's final WP opens a **draft** pull request against `upstream/main`. The PR body links both the OpenSpec change-id and the Spec Kitty mission slug. No spec archive happens until the PR is merged.

## Functional Requirements

| ID | Requirement | Status |
| ---- | ------------- | -------- |
| FR-001 | An OpenSpec change directory `openspec/changes/add-workspace-runtime-contract/` exists with `proposal.md`, `tasks.md`, `design.md`, and a delta spec at `specs/workspace-runtime/spec.md`. | Approved |
| FR-002 | The delta spec defines nine `## ADDED Requirements` corresponding to invariants INV-1…INV-9 (Sysbox runtime, UID/GID identity, sudo posture, dockerd lifecycle, volume model, hydration model, routing model, cleanup model, identity model). Each requirement has at least one `#### Scenario:`. | Approved |
| FR-003 | The delta spec captures the required boot sequence and the forbidden-behavior set as scenario-bearing requirements. | Approved |
| FR-004 | The delta spec captures known drift items D-1…D-6 as a `## Known Drift` block (informational, not enforced), so follow-up OpenSpec changes have a registered attachment point. | Approved |
| FR-005 | `openspec validate add-workspace-runtime-contract --strict` passes. | Approved |
| FR-006 | The Spec Kitty mission `meta.json` carries a cross-link to `add-workspace-runtime-contract` (in `source_description`), and `proposal.md` carries a "Spec Kitty Mission" link pointing at this mission's slug. | Approved |
| FR-007 | No file under `image/`, `*/template.tf`, `*/scripts/`, or `Makefile` is modified by this mission. | Approved |
| FR-008 | `terraform fmt -recursive` reports no changes (the working tree must remain format-clean even though no HCL is touched). | Approved |
| FR-009 | A draft pull request is opened against `upstream/main`. The PR body references the OpenSpec change-id and the Spec Kitty mission slug. The PR is explicitly `--draft`, not ready-for-review. | Approved |
| FR-010 | `CLAUDE.md` is not modified in this mission. It is reconciled in a follow-up change after the foundational spec is archived. | Approved |

## Constraints

| ID | Constraint |
| ---- | ----------- |
| C-001 | The mission is **proposal-stage only**. No implementation work happens here. `.agent/workflows/openspec-proposal.md` is the governing runbook. |
| C-002 | The branch base is `upstream/main`, not `origin/main` (per `CLAUDE.md`). |
| C-003 | The PR is a draft. Merging is blocked until human review approves the spec text. |
| C-004 | The spec text is descriptive-first: every invariant must cite the file/block where it is currently enforced. No invariant may describe behavior that does not already exist in the repo. |
| C-005 | Drift items must be enumerated, never silently corrected. Remediation is out of scope. |

## Acceptance

The mission is acceptable when:

1. `openspec validate add-workspace-runtime-contract --strict` is green.
2. `terraform fmt -recursive` reports zero changes.
3. The draft PR exists on `origin/spec-workspace-runtime-contract` targeting `ddev/coder-ddev:main`, body referencing the change-id and mission slug.
4. The Spec Kitty mission `status.json` reflects all WPs in the `approved` or `done` lane.
5. No file in `image/`, `*/template.tf`, `*/scripts/`, or `Makefile` is included in the PR diff.
