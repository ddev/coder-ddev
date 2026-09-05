# Tasks: Add Workspace Runtime Contract

These tasks deliver the proposal-stage artifacts only. No code is changed.

- [ ] 1. Author `proposal.md`, `design.md`, and `tasks.md` under `openspec/changes/add-workspace-runtime-contract/`.
- [ ] 2. Author delta spec at `openspec/changes/add-workspace-runtime-contract/specs/workspace-runtime/spec.md` with:
  - [ ] 2.1. Nine `## ADDED Requirements` (INV-1 … INV-9) — each with a `shall` and at least one `#### Scenario:`.
  - [ ] 2.2. Boot-sequence requirements (the ordered steps the agent script must satisfy).
  - [ ] 2.3. Forbidden-behavior requirements (no host docker.sock mount, no `--privileged`, no hostname-derived identity, no `set -e`, no overwriting user state during hydration, etc.).
  - [ ] 2.4. `## Known Drift` informational block enumerating D-1 … D-6 with the relevant file references.
- [ ] 3. Cross-link mission and change:
  - [ ] 3.1. Update `kitty-specs/workspace-runtime-contract-01KRC8WY/meta.json` `source_description` to reference change-id `add-workspace-runtime-contract`.
  - [ ] 3.2. Confirm `proposal.md` carries a `Spec Kitty Mission` link to the mission slug.
- [ ] 4. Validate:
  - [ ] 4.1. `openspec validate add-workspace-runtime-contract --strict` — green.
  - [ ] 4.2. `terraform fmt -check -recursive` — zero changes (defensive; no HCL touched).
  - [ ] 4.3. Diff scope check — no file under `image/`, `*/template.tf`, `*/scripts/`, or `Makefile` modified.
- [ ] 5. Open a **draft** pull request against `ddev/coder-ddev:main`. Body references the OpenSpec change-id, the Spec Kitty mission slug, and the descriptive-first stance.

**Not in scope for this change:**
- Remediating drift items D-1 … D-6.
- Editing `CLAUDE.md` or any architecture prose.
- Adding CI gates.
- Removing the systemd install in the image.
