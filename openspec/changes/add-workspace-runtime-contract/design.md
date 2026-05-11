# Design: Workspace Runtime Contract

## Context

The `coder-ddev` runtime has nine invariants that are load-bearing today but unspecified anywhere reviewable. The invariants are spread across:
- `image/Dockerfile` — image build (UID/GID, sudo, daemon binaries, hydration staging).
- `user-defined-web/template.tf` — Terraform shape (Sysbox runtime, volumes, agent env, cleanup).
- `user-defined-web/template.tf:startup_script` — inline shell pipeline executed by the Coder agent on each boot (hydration, dockerd start, identity, profile assembly).
- `CLAUDE.md` — prose summary used by AI agents.

Without a single spec home, reviewers must read three files to confirm an invariant is preserved; agents must re-derive the invariants from prose; and drift items (`global_config.yaml` missing, host commands uncopied, dual dockerd-start models) have no registered attachment point.

## Approach

**Descriptive-first.** The spec captures *what is true today*. No requirement may state behavior that does not already exist in the repo. The contract introduces zero runtime changes.

**One capability, nine requirements.** A single capability — `workspace-runtime` — holds INV-1 through INV-9 as `## ADDED Requirements`, each with a `shall` statement and at least one `#### Scenario:` describing a verifiable observation. Boot sequence and forbidden behaviors are encoded as additional scenario-bearing requirements rather than as a separate capability.

**Drift catalog as informational appendix.** Items D-1 … D-6 live in a `## Known Drift` block. They are not enforced; they are named so follow-up `MODIFIED` deltas can reference them by ID without re-discovering them.

**Spec Kitty ↔ OpenSpec join.** The Spec Kitty mission wraps the OpenSpec change. The mission `meta.json.source_description` references the OpenSpec change-id; `proposal.md` carries a `Spec Kitty Mission` link. Spec text lives only in OpenSpec; mission state and event log live only in `kitty-specs/`. No content is duplicated.

## Decisions

| ID | Decision | Rationale |
|----|----------|-----------|
| D-1 | One capability per mission, not one capability per invariant. | The nine invariants are cross-cutting; splitting them would obscure relationships (e.g., INV-3 sudo is required by INV-4 dockerd). |
| D-2 | Drift items are informational, not `MODIFIED Requirements`. | They are anomalies in the *implementation*, not changes to the contract. Each will become its own change later. |
| D-3 | The `freeform` template is excluded. | Freeform deviates from INV-7 (keeps ddev-router) and INV-4 (multiple projects per workspace). Its contract is a future sibling capability. |
| D-4 | `CLAUDE.md` is not touched in this change. | Reconciling prose and spec mid-archive would conflate two concerns. A separate proposal will retire duplicated architecture sections after the first archive lands. |
| D-5 | The two systemd-init code paths remain forbidden (INV F-9) but the systemd install in the image stays. | Removing the systemd install is a real image change requiring its own proposal. Documenting it as forbidden behavior is sufficient for this contract. |
| D-6 | Per-template image pinning is not allowed by this contract. | A single `VERSION` is enforced today; per-template variance would require breaking INV-5 or extending it. Tracked as D-6 for the follow-up proposal. |

## Risks

- **Stale spec** — if `image/Dockerfile`, any `template.tf`, or the startup script drifts after archive, the spec rots. *Mitigation:* descriptive-first language + a future CI drift check (out of scope here).
- **Cohabitation friction** — OpenSpec and Spec Kitty cohabit with no enforced join. *Mitigation:* bidirectional cross-link convention codified here; CI gating reserved for a future proposal.
- **Pilot mission collision** — the existing Spec Kitty mission `github-org-gated-signup-01KR1P4G` is concurrent and auto-commits. *Mitigation:* this mission runs on its own branch (`spec-workspace-runtime-contract`) based on `upstream/main`.

## Alternatives Considered

- **One spec per invariant.** Rejected — fragments the relationships and inflates the cross-reference surface.
- **Promote `CLAUDE.md` to the spec.** Rejected — prose lacks scenarios and validation hooks; OpenSpec format provides both.
- **Skip OpenSpec, use only Spec Kitty.** Rejected — OpenSpec is already initialized with `.agent/workflows/` runbooks; replacing it would itself be a large governance change this proposal is not authorized to make.
- **Defer until drift is remediated.** Rejected — the foundational spec must land first so drift remediations can attach to a stable reference.
