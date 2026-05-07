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
├── server-setup.md      ← update: add coder-ddev-com to ALLOWED_ORGS, staging OAuth App section
└── user-management.md   ← update: add access management runbook section
```

No Terraform, shell script, or Dockerfile changes required. All Coder server configuration changes are applied on the host via `/etc/coder.d/coder.env`.

---

## Phase 0: Research

See [research.md](research.md).

Key findings: all open questions resolved. No `[NEEDS CLARIFICATION]` markers remain.

---

## Phase 1: Work Package Approach

This feature decomposes into three types of work:

### Type A — Repository changes (agent-implementable)

1. **Update `docs/admin/server-setup.md`**
   - Change `CODER_OAUTH2_GITHUB_ALLOWED_ORGS=ddev` to `CODER_OAUTH2_GITHUB_ALLOWED_ORGS=ddev,coder-ddev-com`
   - Add a staging OAuth App sub-section (separate app with staging callback URL)
   - Add a note explaining the `coder-ddev-com` org purpose and how to manage membership
   - Add a note explaining why two separate OAuth Apps are used (credential isolation between environments)

2. **Update `docs/admin/user-management.md`**
   - Add a new "Access Management" section covering:
     - How to add a user to the `coder-ddev-com` GitHub org (grants self-serve signup)
     - How to pre-create a password exception account (for users who cannot use GitHub OAuth)
     - Note: private org membership is sufficient — users do not need to publicize membership

3. **Write `coder-ddev-com` org README and access-request repo**
   - Draft content for the `coder-ddev-com` org README (`.github/profile/README.md` in the org): org purpose, who qualifies, how membership grants Coder access
   - Draft issue template for the access-request repo (e.g., `coder-ddev-com/access-requests`): name, GitHub username, reason for access
   - Draft README for the access-request repo explaining how to open a request and what to expect

4. **Resolve $100+ sponsor GitHub org names and update server-setup.md**
   - Identify which current $100+/month sponsors are GitHub organizations (vs. individuals): cross-reference the invoiced list (cps-it, Redfin Solutions, LetsTalk, Institute for Advanced Studies, Tag1, Upsun, B13, Lullabot, 8mylez, Cambrico, Centarro, Pixel & Tonic) against GitHub org slugs
   - Update `docs/admin/server-setup.md` to document the sponsor-org access policy and show the full example `ALLOWED_ORGS` value including sponsor org slugs
   - Update the sponsors-to-orgs mapping as a maintained comment or table in `docs/admin/server-setup.md` (since `invoiced-sponsorships.jsonc` has no GitHub org field)

5. **Update ddev.com blog post** (`ddev/ddev.com` repo — separate PR required)
   - Update the "Log In with GitHub" section: replace "No separate account needed" with an explanation that signups are restricted to `ddev` and `coder-ddev-com` org members
   - Add a paragraph explaining how users outside the `ddev` org can request access by opening an issue in the `coder-ddev-com/access-requests` repo
   - Add a link to the access-request repo

### Type B — Ops tasks (operator-executed, documented in runbook)

1. **Create `coder-ddev-com` GitHub org** — one-time action; org owner adds members as needed
2. **Register staging OAuth App** under `ddev` org with callback `https://staging-coder.ddev.com/api/v2/users/oauth2/github/callback`
3. **Register production OAuth App** under `ddev` org with callback `https://coder.ddev.com/api/v2/users/oauth2/github/callback`
4. **Apply config to staging**: update `/etc/coder.d/coder.env` with `ALLOWED_ORGS=ddev,coder-ddev-com,<sponsor-org-1>,...`, restart `coder` service, validate all scenarios from spec
5. **Apply config to production**: repeat after staging validation passes

### Staging validation scenarios (must all pass before production)

| # | Scenario | Expected |
| - | -------- | -------- |
| 1 | `ddev` org member signs in via GitHub | Account created, dashboard loads |
| 2 | `coder-ddev-com` org member signs in via GitHub | Account created, dashboard loads |
| 3 | Unauthorized GitHub user attempts sign-in | Error shown, no account created |
| 4 | Existing user (pre-existing account) logs in | Access unchanged |
| 5 | Exception account via password | Password login succeeds |
