---
work_package_id: WP03
title: coder-ddev-com Org Content Drafts
dependencies: []
requirement_refs:
- FR-002
- FR-010
- FR-011
- FR-015
planning_base_branch: 20260507_speckitty
merge_target_branch: 20260507_speckitty
branch_strategy: Planning artifacts for this feature were generated on 20260507_speckitty. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into 20260507_speckitty unless the human explicitly redirects the landing branch.
subtasks:
- T010
- T011
- T012
- T013
history:
- date: '2026-05-07'
  event: created
authoritative_surface: docs/admin/coder-ddev-com/
execution_mode: planning_artifact
owned_files:
- docs/admin/coder-ddev-com/**
tags: []
---

# WP03 — coder-ddev-com Org Content Drafts

## Branch Strategy

- **Planning base**: `20260507_speckitty`
- **Merge target**: `20260507_speckitty`
- Implement directly on `20260507_speckitty`. Run `spec-kitty agent action implement WP03 --agent claude`.

## Objective

Produce all content needed to stand up the `coder-ddev-com` GitHub organization:

1. **Org profile README** — displayed on the org's GitHub page; explains the org's purpose
2. **access-requests repo README** — explains how to open an access request
3. **Access request GitHub issue template** — the structured form prospective users fill out
4. **Sponsor notification message** — the message sent to newly-added sponsor orgs

All content is committed to `docs/admin/coder-ddev-com/` in this repo for operator use. The operator copies them to the appropriate GitHub locations when setting up the org.

## Context

The `coder-ddev-com` GitHub organization does not yet exist. When an operator creates it, they need ready-to-use content for:

- `.github/profile/README.md` in the org — the GitHub org profile (shown on the org's main page)
- `coder-ddev-com/access-requests` repo — a public repo where prospective users open issues requesting access
- The issue template in that repo (`.github/ISSUE_TEMPLATE/access-request.yml`)
- A short notification message to send to sponsor org owners/maintainers when their org is added to `ALLOWED_ORGS`

**Create new files** — none of these files exist yet. Create the `docs/admin/coder-ddev-com/` directory and write each file fresh.

---

## Subtask T010 — Write `coder-ddev-com` Org Profile README Draft

**Purpose**: The org profile README is the first thing visitors see when they visit `github.com/coder-ddev-com`. It must explain the org's purpose, who qualifies, and how membership grants coder.ddev.com access.

**File to create**: `docs/admin/coder-ddev-com/org-profile-README.md`

**Operator instruction**: Copy this file's content to `.github/profile/README.md` in the `coder-ddev-com` GitHub org (create a `.github` repo in the org if it does not exist, then add `profile/README.md`).

**Content to write**:

```markdown
# coder-ddev-com

This organization is the managed access list for [coder.ddev.com](https://coder.ddev.com) — a cloud-based DDEV development environment for web developers.

## What is coder.ddev.com?

[coder.ddev.com](https://coder.ddev.com) provides cloud-hosted workspaces running [DDEV](https://ddev.com), an open-source local development environment tool for PHP, Node.js, Python, and more projects. Workspaces include VS Code for Web, a terminal, Docker-in-Docker, and full DDEV support — no local setup required.

## How membership works

Members of this organization can sign in to coder.ddev.com using GitHub OAuth. Membership is granted by a coder-ddev-com org owner.

You do **not** need to make your membership public. Private membership is sufficient.

## Who qualifies?

Access is available to:

- Members of the [ddev](https://github.com/ddev) GitHub org
- Members of organizations that sponsor DDEV at $100+/month
- Individuals approved by the DDEV maintainers (this org)

## Requesting access

If you do not have access through one of the paths above, open an issue in the [access-requests](https://github.com/coder-ddev-com/access-requests) repository.

## Questions

Visit the [DDEV Discord](https://discord.ddev.com) or open an issue in [ddev/ddev](https://github.com/ddev/ddev/issues).
```

**Validation**:
- [ ] File is at `docs/admin/coder-ddev-com/org-profile-README.md`
- [ ] Operator instruction (where to copy it) is present as a comment or note at the top of the file
- [ ] Link to access-requests repo is present
- [ ] Private membership note is present
- [ ] The three access tiers (ddev org, sponsor orgs, approved individuals) are mentioned

---

## Subtask T011 — Write access-requests Repo README Draft

**Purpose**: The `coder-ddev-com/access-requests` repo is where prospective users open issues requesting access. Its README explains what the repo is for and how the process works.

**File to create**: `docs/admin/coder-ddev-com/access-requests-README.md`

**Operator instruction**: Create a public repo named `access-requests` in the `coder-ddev-com` GitHub org. Copy this file's content to `README.md` in that repo.

**Content to write**:

```markdown
# coder-ddev-com / access-requests

This repository is the access request tracker for [coder.ddev.com](https://coder.ddev.com).

## What is coder.ddev.com?

[coder.ddev.com](https://coder.ddev.com) is a cloud-hosted DDEV development environment for web developers. It provides workspaces running [DDEV](https://ddev.com) with VS Code for Web, a terminal, and full Docker support.

## Who already has access?

Access is automatically available (no request needed) if you are:

- A member of the [ddev](https://github.com/ddev) GitHub org
- A member of an organization that sponsors DDEV at $100+/month

See the [DDEV sponsors page](https://ddev.com/support-ddev/) for the current list of sponsors.

## Requesting access

If you do not have access through one of the above paths, open an issue in this repository using the **Access Request** template.

We will review your request and, if approved, add you to the `coder-ddev-com` org. You will receive a GitHub invitation — once you accept it, you can sign in to coder.ddev.com with your GitHub account.

**What to include in your request:**
- Your GitHub username
- Why you want access (brief description — DDEV user, contributor, etc.)

## Response time

We aim to respond to requests within a few business days. If you have not heard back in a week, feel free to ping the issue.

## Questions

Visit the [DDEV Discord](https://discord.ddev.com) or open an issue in [ddev/ddev](https://github.com/ddev/ddev/issues).
```

**Validation**:
- [ ] File is at `docs/admin/coder-ddev-com/access-requests-README.md`
- [ ] Operator instruction (where to copy it) is present
- [ ] "Who already has access" section explains automatic access tiers
- [ ] Clear instructions for opening a request are present
- [ ] Response time expectation is set

---

## Subtask T012 — Write Access Request GitHub Issue Template Draft

**Purpose**: The issue template structures the access request so reviewers get the information they need (GitHub username, reason for access) without back-and-forth.

**File to create**: `docs/admin/coder-ddev-com/access-request-issue-template.yml`

**Operator instruction**: In the `coder-ddev-com/access-requests` repo, create `.github/ISSUE_TEMPLATE/access-request.yml` with this content.

**Content to write**:

```yaml
name: Access Request
description: Request access to coder.ddev.com
title: "Access request: [your GitHub username]"
labels: ["access-request"]
body:
  - type: markdown
    attributes:
      value: |
        Thanks for your interest in coder.ddev.com! Please fill out the form below.

        **Already have access?** If you are a member of the [ddev](https://github.com/ddev) org
        or a $100+/month DDEV sponsor org, you should already have access — try signing in at
        [coder.ddev.com](https://coder.ddev.com) first.

  - type: input
    id: github_username
    attributes:
      label: GitHub username
      description: Your GitHub username (the one you will use to sign in)
      placeholder: "e.g. octocat"
    validations:
      required: true

  - type: textarea
    id: reason
    attributes:
      label: Why do you want access?
      description: Brief description — DDEV contributor, open-source developer, evaluating DDEV for a project, etc.
      placeholder: "I maintain a DDEV add-on and want to test it in a cloud workspace..."
    validations:
      required: true

  - type: checkboxes
    id: confirm
    attributes:
      label: Confirmation
      options:
        - label: I have checked that I do not already have access through the ddev org or a sponsor org
          required: true
        - label: I understand this is a shared resource and will use it responsibly
          required: true
```

**Validation**:
- [ ] File is at `docs/admin/coder-ddev-com/access-request-issue-template.yml`
- [ ] Operator instruction is present
- [ ] `github_username` field is required
- [ ] `reason` textarea is required
- [ ] Confirmation checkboxes are present
- [ ] The pre-check note (ddev org / sponsor org members already have access) is included

---

## Subtask T013 — Write Sponsor Notification Message Template

**Purpose**: When a new sponsor org is added to `ALLOWED_ORGS`, the DDEV maintainers should notify that org's owners/maintainers so they know their members have access. This template is the message to send.

**File to create**: `docs/admin/coder-ddev-com/sponsor-notification.md`

**Operator instruction**: Use this as the text of an email, GitHub issue, or direct message to the sponsor org's maintainer(s). Substitute `[ORG NAME]` and `[GITHUB ORG SLUG]` before sending.

**Content to write**:

```markdown
<!-- operator note: substitute [ORG NAME] and [GITHUB ORG SLUG] before sending -->

Subject: coder.ddev.com access for [ORG NAME] org members

Hi,

As a $100+/month sponsor of DDEV, all members of the **[ORG NAME]** GitHub organization ([github.com/[GITHUB ORG SLUG]](https://github.com/[GITHUB ORG SLUG])) now have access to **[coder.ddev.com](https://coder.ddev.com)** — a cloud-hosted DDEV development environment.

**What is coder.ddev.com?**

coder.ddev.com provides on-demand cloud workspaces running DDEV with:
- VS Code for Web (full IDE in the browser)
- A terminal
- Docker-in-Docker via Sysbox (full DDEV support, all project types)

No local setup required — spin up a workspace, start DDEV, and get coding.

**How to access:**

1. Visit [coder.ddev.com](https://coder.ddev.com)
2. Click **Sign in with GitHub**
3. Authorize the DDEV Coder app
4. You're in — create a workspace from the Drupal Core, Drupal Contrib, or Freeform template

All members of the [ORG NAME] GitHub org can sign in. They do not need to be added individually. Org membership does not need to be public.

**Questions or issues?**

- [DDEV Discord](https://discord.ddev.com) — `#coder-ddev-com` channel (or any channel)
- [ddev/ddev issues](https://github.com/ddev/ddev/issues)

Thank you for supporting DDEV!

— The DDEV maintainers
```

**Validation**:
- [ ] File is at `docs/admin/coder-ddev-com/sponsor-notification.md`
- [ ] `[ORG NAME]` and `[GITHUB ORG SLUG]` placeholders are present and clearly marked
- [ ] Operator substitution note is at the top
- [ ] What coder.ddev.com is and how to access it are both explained
- [ ] Contact options (Discord, issues) are present

---

## Definition of Done

- [ ] `docs/admin/coder-ddev-com/` directory exists with four files:
  - `org-profile-README.md`
  - `access-requests-README.md`
  - `access-request-issue-template.yml`
  - `sponsor-notification.md`
- [ ] Each file has an operator instruction note explaining where to copy it
- [ ] Org profile README mentions all three access tiers and links to access-requests repo
- [ ] Issue template is valid YAML with required fields
- [ ] Sponsor notification has clearly marked placeholders

## Risks

- The `coder-ddev-com/access-requests` repo URL is referenced in T011 and the org profile README — the repo does not exist yet. Use the anticipated URL `https://github.com/coder-ddev-com/access-requests` in drafts; operator creates the repo before publishing.
- The issue template YAML syntax must be valid. The `type` values (`input`, `textarea`, `checkboxes`, `markdown`) are the standard GitHub issue form types.
