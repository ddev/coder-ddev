# Tasks: GitHub Org-Gated Signup

**Mission**: github-org-gated-signup-01KR1P4G
**Branch**: `20260507_speckitty` → merge target `20260507_speckitty`
**Created**: 2026-05-07

---

## Subtask Index

| ID | Description | WP | Parallel |
| -- | ----------- | -- | -------- |
| T001 | Update `CODER_OAUTH2_GITHUB_ALLOWED_ORGS` in server-setup.md to full 27-org list | WP01 | [P] |
| T002 | Add staging OAuth App sub-section to server-setup.md | WP01 | [P] |
| T003 | Document `coder-ddev-com` org purpose and membership management in server-setup.md | WP01 | [P] |
| T004 | Add sponsor org access table to server-setup.md | WP01 | [P] |
| T005 | Add "Adding a new sponsor org" runbook to server-setup.md | WP01 | |
| T006 | Add "Access Management" top-level section to user-management.md | WP02 | [P] |
| T007 | Document granting access via `coder-ddev-com` org membership | WP02 | [P] |
| T008 | Document pre-creating password exception accounts | WP02 | [P] |
| T009 | Add note about private org membership and list initial `coder-ddev-com` members | WP02 | |
| T010 | Write `coder-ddev-com` org profile README draft | WP03 | [P] |
| T011 | Write access-requests repo README draft | WP03 | [P] |
| T012 | Write access-request GitHub issue template draft | WP03 | [P] |
| T013 | Write sponsor notification message template | WP03 | |
| T014 | Update blog post "Log In with GitHub" section | WP04 | [P] |
| T015 | Add access restriction paragraph and access paths to blog post | WP04 | [P] |
| T016 | Add sponsor org access benefit mention to blog post | WP04 | |

---

## Work Packages

### WP01 — Update server-setup.md for Org-Gated Auth

**Priority**: High — all operator instructions depend on this doc
**Goal**: Make `docs/admin/server-setup.md` the authoritative reference for the new auth model: full org list, two-app strategy, coder-ddev-com purpose, sponsor mapping, and the runbook for adding new orgs.
**Dependencies**: none
**Estimated prompt size**: ~380 lines
**Prompt file**: [tasks/WP01-server-setup-update.md](tasks/WP01-server-setup-update.md)

- [ ] T001 Update `CODER_OAUTH2_GITHUB_ALLOWED_ORGS` to full 27-org list (WP01)
- [ ] T002 Add staging OAuth App sub-section (WP01)
- [ ] T003 Document `coder-ddev-com` org purpose and membership management (WP01)
- [ ] T004 Add sponsor org access table (WP01)
- [ ] T005 Add "Adding a new sponsor org" runbook (WP01)

---

### WP02 — Update user-management.md with Access Runbook

**Priority**: High — operators need this to grant access after deployment
**Goal**: Add a clear "Access Management" section to `docs/admin/user-management.md` covering individual access via `coder-ddev-com`, exception password accounts, private org membership behavior, and initial members.
**Dependencies**: none
**Estimated prompt size**: ~280 lines
**Prompt file**: [tasks/WP02-user-management-access-runbook.md](tasks/WP02-user-management-access-runbook.md)

- [ ] T006 Add "Access Management" section header and intro (WP02)
- [ ] T007 Document granting access via `coder-ddev-com` org membership (WP02)
- [ ] T008 Document pre-creating password exception accounts (WP02)
- [ ] T009 Note on private org membership + initial coder-ddev-com members (WP02)

---

### WP03 — coder-ddev-com Org Content Drafts

**Priority**: High — operators need these to set up the GitHub org and access-request repo
**Goal**: Produce all content needed to stand up the `coder-ddev-com` GitHub org: org profile README, access-requests repo README, issue template, and sponsor notification message. Content committed to `docs/admin/coder-ddev-com/` in this repo for operator use.
**Dependencies**: none
**Estimated prompt size**: ~320 lines
**Prompt file**: [tasks/WP03-coder-ddev-com-org-content.md](tasks/WP03-coder-ddev-com-org-content.md)

- [ ] T010 Write org profile README draft (WP03)
- [ ] T011 Write access-requests repo README draft (WP03)
- [ ] T012 Write access-request GitHub issue template draft (WP03)
- [ ] T013 Write sponsor notification message template (WP03)

---

### WP04 — Blog Post Update Draft

**Priority**: Medium — needed before or shortly after production rollout
**Goal**: Produce a ready-to-apply diff for `ddev/ddev.com/src/content/blog/coder-ddev-com-announcement.md` updating the auth description. Draft committed to `docs/admin/blog-post-draft.md` in this repo for operator to PR to ddev.com.
**Dependencies**: WP03 (needs access-requests repo URL)
**Estimated prompt size**: ~220 lines
**Prompt file**: [tasks/WP04-blog-post-draft.md](tasks/WP04-blog-post-draft.md)

- [ ] T014 Update "Log In with GitHub" section (WP04)
- [ ] T015 Add access restriction paragraph and access paths (WP04)
- [ ] T016 Add sponsor org access benefit mention (WP04)
