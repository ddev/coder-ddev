# Change: Add Workspace Runtime Contract

## Why

`coder-ddev` enforces nine load-bearing runtime invariants — Sysbox isolation, UID/GID identity, NOPASSWD sudo, in-container `dockerd` lifecycle, the two-volume persistence model, copy-if-missing hydration from `/home/coder-files`, single-project direct-bind web routing, host-aware cleanup, and env-sourced workspace identity. These invariants are scattered across `image/Dockerfile`, `user-defined-web/template.tf` (and its inlined `startup_script`), and prose in `CLAUDE.md`. Nothing in `openspec/specs/` describes them today, so a reviewer cannot confirm that a PR preserves them without re-reading three loosely coupled files.

This proposal codifies the invariants as a single foundational capability — `workspace-runtime` — that future changes can attach to (or modify) through OpenSpec deltas. The intent is **descriptive-first**: every requirement maps to behavior already enforced in the repo; no new runtime behavior is introduced.

This proposal also establishes the convention that a Spec Kitty mission *wraps* the OpenSpec change. Bidirectional cross-references between the mission `meta.json` and `proposal.md` keep both governance systems aligned without merging them.

**Spec Kitty Mission:** [`workspace-runtime-contract-01KRC8WY`](../../../kitty-specs/workspace-runtime-contract-01KRC8WY/spec.md)

## What Changes

- **Adds** capability `workspace-runtime` with nine requirements (INV-1 … INV-9) covering the runtime invariants enumerated above.
- **Adds** scenario-bearing requirements for the required agent boot sequence and the forbidden-behavior set (e.g., no host docker.sock mount, no `--privileged`, no hostname-derived identity).
- **Adds** a `## Known Drift` informational block enumerating D-1 … D-6 (missing `global_config.yaml`, uncopied DDEV host commands, missing `chmod 755` on `coder-setup`, dual dockerd-start models, broad socket chmod, single-tag image version). These are **not** remediated by this change; each will become its own follow-up OpenSpec proposal.

## Impact

- **Affected specs:** `workspace-runtime` (new capability).
- **Affected code:** **None.** No file under `image/`, `*/template.tf`, `*/scripts/`, or `Makefile` is modified.
- **Affected workflows:** future OpenSpec proposals that touch the image, any template, or the inlined `startup_script` are expected to reference `workspace-runtime` requirements by ID.
- **Affected governance:** establishes the Spec Kitty ↔ OpenSpec cohabitation rule (mission wraps change; spec text lives in OpenSpec; mission state lives in `kitty-specs/`).

## Non-Goals

- No edits to `CLAUDE.md` — reconciliation of architecture prose with the new spec is a follow-up after archive.
- No CI gate added in this change. CI integration is reserved for a separate proposal.
- No remediation of drift items D-1 … D-6.
- No introduction of a `freeform` template contract — `freeform` deviates from INV-7 and will be governed by a sibling capability later.
