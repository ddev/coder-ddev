---
work_package_id: WP02
title: Update user-management.md with Access Runbook
dependencies: []
requirement_refs:
- C-001
- FR-001
- FR-002
- FR-003
- FR-004
- FR-009
planning_base_branch: 20260507_speckitty
merge_target_branch: 20260507_speckitty
branch_strategy: Planning artifacts for this feature were generated on 20260507_speckitty. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into 20260507_speckitty unless the human explicitly redirects the landing branch.
subtasks:
- T006
- T007
- T008
- T009
history:
- date: '2026-05-07'
  event: created
authoritative_surface: docs/admin/user-management.md
execution_mode: code_change
owned_files:
- docs/admin/user-management.md
tags: []
---

# WP02 — Update user-management.md with Access Runbook

## Branch Strategy

- **Planning base**: `20260507_speckitty`
- **Merge target**: `20260507_speckitty`
- Implement directly on `20260507_speckitty`. Run `spec-kitty agent action implement WP02 --agent claude`.

## Objective

Add a clear "Access Management" section to `docs/admin/user-management.md` covering:
- How to grant individual access via the `coder-ddev-com` GitHub org
- How to pre-create password exception accounts for users who cannot use GitHub OAuth
- Notes on private org membership (private is sufficient — users need not publicize)
- The initial list of `coder-ddev-com` members to add when the org is created

## Context

With the org-gated signup model, access to coder.ddev.com is no longer open. Operators need a clear day-to-day runbook for the two ways to grant access:

1. **Add to `coder-ddev-com` org** — the normal path for individuals not in `ddev` or a sponsor org
2. **Pre-create a password account** — the escape hatch for users who cannot authenticate via GitHub OAuth

The existing `docs/admin/user-management.md` has good content on Coder user management but says nothing about the org-gated access model. This WP adds a new top-level section that operators can turn to immediately after deployment.

**Read the current file before editing**: `docs/admin/user-management.md`. The file is 496 lines. Add the new section after the existing "User Accounts" section (currently at the top of the file) — specifically, insert the new "## Access Management" section after line ~60 (after the User Roles subsection), before the existing section that follows it.

---

## Subtask T006 — Add "Access Management" Section Header and Intro

**Purpose**: Create the section that groups all access-granting procedures, so operators know where to look.

**Location**: `docs/admin/user-management.md`, as a new top-level `## Access Management` section. Insert it after the "User Roles" subsection (the block ending around line 60) and before the next major section that follows.

**Content to add**:

```markdown
## Access Management

coder.ddev.com restricts new GitHub OAuth signups to members of specific GitHub organizations. This section documents how to grant or revoke access for individuals who are not already in the `ddev` org or a $100+/month sponsor org.

**The two access paths:**

1. **`coder-ddev-com` org membership** — For individuals who should have ongoing access. Adding them to the `coder-ddev-com` GitHub org allows them to sign in immediately with no server change.

2. **Password exception account** — For individuals who cannot or will not use GitHub OAuth. An admin pre-creates their Coder account with a password credential.

See `docs/admin/server-setup.md` for the full `CODER_OAUTH2_GITHUB_ALLOWED_ORGS` configuration and sponsor org policy.
```

**Validation**:
- [ ] Section heading is `## Access Management` (top-level)
- [ ] Both access paths are mentioned
- [ ] Link to server-setup.md is present

---

## Subtask T007 — Document Granting Access via `coder-ddev-com` Org Membership

**Purpose**: Give operators the exact steps to add an individual to the `coder-ddev-com` GitHub org.

**Location**: Add a sub-section `### Granting access via coder-ddev-com org membership` immediately inside the "Access Management" section.

**Content to add**:

```markdown
### Granting access via `coder-ddev-com` org membership

Adding someone to the `coder-ddev-com` GitHub org grants them signup access to coder.ddev.com without requiring a Coder server restart.

**Steps:**
1. Go to [github.com/coder-ddev-com](https://github.com/coder-ddev-com) → **People** → **Invite member**
2. Enter the person's GitHub username and send the invitation
3. Once they accept, they can sign in to coder.ddev.com via GitHub OAuth

**Requirements:**
- You must be an owner of the `coder-ddev-com` GitHub org to send invitations
- The invitee must have a GitHub account
- They do **not** need to make their membership public — private membership is sufficient (see note on private membership below)

**Removing access:**
1. Go to [github.com/coder-ddev-com](https://github.com/coder-ddev-com) → **People**
2. Click the member's username → **Remove from organization**
3. Their Coder account remains (they can still log in if they are a `ddev` org member or a member of a sponsor org); their `coder-ddev-com` access path is removed

**Note**: Removing a user from `coder-ddev-com` does not delete their Coder workspace or account. If full account removal is needed, also delete the user account in Coder (see "Removing User Accounts" below).
```

**Validation**:
- [ ] Steps 1–3 for invitation are present
- [ ] Requirements (org owner, no public membership required) are listed
- [ ] Removal steps are present
- [ ] Note about account vs. org membership distinction is present

---

## Subtask T008 — Document Pre-Creating Password Exception Accounts

**Purpose**: Operators need to know how to create accounts for users who cannot use GitHub OAuth. This is the "escape hatch" path that keeps password auth viable.

**Location**: Add a sub-section `### Pre-creating password exception accounts` inside the "Access Management" section, after the `coder-ddev-com` sub-section.

**Content to add**:

```markdown
### Pre-creating password exception accounts

For users who cannot or will not authenticate via GitHub OAuth, an admin can pre-create their Coder account with a password credential. This path depends on password authentication being enabled — **`CODER_DISABLE_PASSWORD_AUTH` must never be set to `true`**.

**When to use this path:**
- The user does not have a GitHub account
- The user has a GitHub account but cannot authorize the OAuth app (e.g., corporate GitHub account with SSO restrictions)
- Emergency admin access is needed without GitHub

**Steps (via CLI):**
```bash
# Create a user account with email and password prompt
coder users create <username> --email <email@example.com> --set-password

# Or set a specific password (use a strong, random value — user should change it on first login)
coder users create <username> --email <email@example.com> --password "<strong-random-password>"
```

**After creating the account:**
1. Share the username and temporary password with the user via a secure channel (not email in plaintext)
2. Instruct the user to change their password on first login: **User Settings → Security → Update Password**
3. Confirm the user can log in at coder.ddev.com before closing the support request

**Roles:** Accounts created this way default to the "Member" role. If a higher role is needed:
```bash
coder users edit-roles <username> --roles template-admin
```

**Note**: Password accounts are exempt from the GitHub org membership check. They can log in regardless of GitHub org membership.
```

**Validation**:
- [ ] The `CODER_DISABLE_PASSWORD_AUTH` constraint is mentioned explicitly
- [ ] CLI commands for creating a user are correct
- [ ] The "when to use" list is present
- [ ] Password change instruction is included

---

## Subtask T009 — Add Private Membership Note and Initial `coder-ddev-com` Members

**Purpose**: Operators need to know that private GitHub org membership works (no extra action needed from users), and they need the initial member list to populate the org when it is created.

**Location**: Add a sub-section `### Private org membership` inside the "Access Management" section, after the password exception sub-section. Then add a sub-section `### Initial coder-ddev-com members` after it.

**Content to add**:

```markdown
### Private org membership

Users do **not** need to make their `coder-ddev-com` (or `ddev`) org membership public. The Coder server uses the `read:org` OAuth scope, which allows it to check org membership regardless of visibility. Private membership is sufficient.

If a user reports that they accepted the `coder-ddev-com` invitation but still cannot log in, check:
1. They accepted the invitation (invitation emails expire after 7 days)
2. They are signing in at the correct URL (coder.ddev.com, not an old bookmark to an open-signup URL)
3. Their Coder account exists — if they have never signed in before, they will be creating a new account on first GitHub OAuth login

### Initial `coder-ddev-com` members

When the `coder-ddev-com` GitHub org is created, add these initial members:

| GitHub username | Reason |
| --------------- | ------ |
| `dougvann` | Individual $100/month GitHub Sponsor (confirmed via [ddev/ddev.com#626](https://github.com/ddev/ddev.com/pull/626)) |
| `claudiu-cristea` | Webikon sponsor — ddev.com sponsor link points to individual, not org |

**Pending — add when GitHub usernames are confirmed:**
- LetsTalk — no GitHub org found; add individual username when known
- Amedick Sommer — no GitHub org found; add individual username when known
- Pottkinder GmbH — no GitHub org found; add individual username when known
```

**Validation**:
- [ ] Private membership note is present with explanation of `read:org` scope
- [ ] The troubleshooting checklist for "accepted invite but can't log in" is present
- [ ] `dougvann` and `claudiu-cristea` are in the initial members table
- [ ] Pending members (LetsTalk, Amedick Sommer, Pottkinder) are listed

---

## Definition of Done

- [ ] `docs/admin/user-management.md` has a `## Access Management` top-level section
- [ ] `coder-ddev-com` org invitation process is documented step-by-step
- [ ] Password exception account creation is documented with CLI commands
- [ ] `CODER_DISABLE_PASSWORD_AUTH` constraint is mentioned
- [ ] Private org membership behavior is explained
- [ ] Initial `coder-ddev-com` member list is present with `dougvann` and `claudiu-cristea`
- [ ] No broken Markdown links

## Risks

- The `coder users create` CLI syntax should be verified against the current Coder CLI (`coder users create --help`) before committing — flags may differ across Coder versions.
- Avoid adding the "Access Management" section in a location that breaks the existing document flow. Insert it after the "User Roles" content, not at the very end.
