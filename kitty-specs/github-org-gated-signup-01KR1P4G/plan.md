# Implementation Plan: GitHub Org-Gated Signup

**Branch**: `20260507_speckitty` | **Date**: 2026-05-07 | **Spec**: [spec.md](spec.md)

**Branch contract**: Planning base `20260507_speckitty` → merge target `20260507_speckitty`.

---

## Summary

Restrict new account signups on coder.ddev.com and staging-coder.ddev.com to members of the `ddev` and `coder-ddev-com` GitHub organizations. The Coder server is deployed via the apt deb package and managed by systemd; its runtime configuration lives in `/etc/coder.d/coder.env` on the server host (not committed to this repo). The docs in this repo (`docs/admin/server-setup.md`, `docs/admin/user-management.md`) are the authoritative operator reference and will be updated to reflect the new configuration. Two separate GitHub OAuth Apps (one per environment) will be registered under the `ddev` GitHub org for credential isolation. The `coder-ddev-com` GitHub org will be created as the managed access list for non-ddev-org users.

---

## Technical Context

**Language/Version**: Markdown (documentation updates)
**Primary Dependencies**: Coder server env vars in `/etc/coder.d/coder.env` (managed on host, not in repo)
**Storage**: N/A
**Testing**: Manual scenario tests against staging-coder.ddev.com; existing BATS integration test suite
**Target Platform**: Ubuntu server running Coder via apt deb package + systemd
**Project Type**: Ops change + documentation update
**Performance Goals**: No increase in login round-trip time (under 10 seconds)
**Constraints**: Password auth must remain enabled; staging must be validated before production; OAuth credentials must not be committed to the repo

---

## Charter Check

- **All changes via PR**: ✓ — plan tracked in `kitty-specs/`, doc changes committed via PR on `20260507_speckitty`
- **Staging before production**: ✓ — explicit work package gate between staging validation and production rollout
- **No credentials in repo**: ✓ — `/etc/coder.d/coder.env` is a server-side file; client ID/secret documented as operator-supplied values only
- **Integration tests run against staging**: ✓ — staging validation WP includes manual scenario testing; BATS suite run post-config

No charter violations.

---

## Project Structure

### Spec artifacts

```text
kitty-specs/github-org-gated-signup-01KR1P4G/
├── spec.md              ✓ complete
├── plan.md              ← this file
├── research.md          ← Phase 0 output
└── tasks/               ← populated by /spec-kitty.tasks
```

### Source changes (repo root)

```text
docs/admin/
├── server-setup.md      ← update: ALLOWED_ORGS full list, staging OAuth App section, coder-ddev-com docs, sponsor table, runbook
├── user-management.md   ← update: add "Access Management" section
├── coder-ddev-com/      ← new: org README, access-requests repo README, issue template, sponsor notification
└── blog-post-draft.md   ← new: ready-to-apply diff for ddev.com blog post
```

No Terraform, shell script, or Dockerfile changes required.

---

## Phase 0: Research

See [research.md](research.md).

Key findings: all open questions resolved. No `[NEEDS CLARIFICATION]` markers remain.

---

## Phase 1: Work Package Approach

This feature decomposes into four work packages corresponding to the four documentation areas.

### WP01 — Update `docs/admin/server-setup.md`

- Update `CODER_OAUTH2_GITHUB_ALLOWED_ORGS` to full 27-org list
- Add staging OAuth App sub-section (separate app, staging callback URL)
- Document `coder-ddev-com` org purpose and membership management
- Add sponsor org access table (company → GitHub slug mapping)
- Add "Adding a new sponsor org" runbook

### WP02 — Update `docs/admin/user-management.md`

- Add "Access Management" top-level section
- Document granting access via `coder-ddev-com` org membership
- Document pre-creating password exception accounts
- Note on private org membership; list initial `coder-ddev-com` members

### WP03 — `coder-ddev-com` org content drafts (`docs/admin/coder-ddev-com/`)

- Org profile README draft (`.github/profile/README.md` content for the org)
- `access-requests` repo README draft (how to open a request, what to expect)
- Access-request GitHub issue template draft
- Sponsor notification message template

### WP04 — Blog post update draft (`docs/admin/blog-post-draft.md`)

- Update "Log In with GitHub" section — no longer open signup
- Add access restriction paragraph and access paths (coder-ddev-com, access-requests link)
- Add sponsor org access benefit mention
- This is a draft diff for an operator to submit as a PR to `ddev/ddev.com`

**WP04 depends on WP03** (needs access-requests repo URL/name).

---

## Staging Validation Scenarios (must all pass before production)

| # | Scenario | Expected |
| - | -------- | -------- |
| 1 | `ddev` org member signs in via GitHub | Account created, dashboard loads |
| 2 | `coder-ddev-com` org member signs in via GitHub | Account created, dashboard loads |
| 3 | Unauthorized GitHub user attempts sign-in | Error shown, no account created |
| 4 | Existing user (pre-existing account) logs in | Access unchanged |
| 5 | Exception account via password | Password login succeeds |

---

## Ops Tasks (operator-executed, documented in runbook)

These are documented in the deliverables but not automated by this repo:

1. Create `coder-ddev-com` GitHub org; add initial members (`dougvann`, others when known)
2. Register staging OAuth App under `ddev` org with staging callback URL
3. Register production OAuth App under `ddev` org with production callback URL
4. Apply config to staging; validate all 5 scenarios above
5. Apply config to production after staging validation passes
6. Notify each sponsor org in `ALLOWED_ORGS` (use WP03 notification template)
