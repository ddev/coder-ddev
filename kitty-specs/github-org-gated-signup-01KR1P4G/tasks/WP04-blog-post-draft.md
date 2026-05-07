---
work_package_id: WP04
title: Blog Post Update Draft
dependencies:
- WP03
requirement_refs:
- FR-012
planning_base_branch: 20260507_speckitty
merge_target_branch: 20260507_speckitty
branch_strategy: Planning artifacts for this feature were generated on 20260507_speckitty. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into 20260507_speckitty unless the human explicitly redirects the landing branch.
subtasks:
- T014
- T015
- T016
agent: "claude"
shell_pid: "32508"
history:
- date: '2026-05-07'
  event: created
authoritative_surface: docs/admin/blog-post-draft.md
execution_mode: planning_artifact
owned_files:
- docs/admin/blog-post-draft.md
tags: []
---

# WP04 — Blog Post Update Draft

## Branch Strategy

- **Planning base**: `20260507_speckitty`
- **Merge target**: `20260507_speckitty`
- **Depends on WP03** — needs the `coder-ddev-com/access-requests` repo URL established in WP03.
- Implement directly on `20260507_speckitty`. Run `spec-kitty agent action implement WP04 --agent claude`.

## Objective

Produce a ready-to-apply patch for `ddev/ddev.com/src/content/blog/coder-ddev-com-announcement.md` that updates the auth description to reflect the org-gated signup model. The patch is committed to `docs/admin/blog-post-draft.md` in this repo; an operator applies it to the `ddev/ddev.com` repo as a separate PR.

The existing blog post implies open signup ("No separate account needed"). That must be replaced with accurate language explaining:
- Signups are now restricted to org members
- How access works (ddev org, sponsor orgs, coder-ddev-com org)
- Where to request access (access-requests repo)

## Context

The blog post lives in a separate repo (`ddev/ddev.com`) and requires its own PR. This WP does not modify that repo directly — it produces a draft that the operator applies.

**WP03 dependency**: The `coder-ddev-com/access-requests` URL (`https://github.com/coder-ddev-com/access-requests`) is used in the draft. WP03 establishes the content for that repo. Confirm WP03 is complete before finalizing this draft.

**Target file in `ddev/ddev.com`**: `src/content/blog/coder-ddev-com-announcement.md`

The draft format in `docs/admin/blog-post-draft.md` should be written so an operator can:
1. Open the file
2. Identify exactly what sections to change in the original blog post
3. Apply the changes with minimal effort (ideally a diff or annotated replacement blocks)

---

## Subtask T014 — Update "Log In with GitHub" Section

**Purpose**: The current blog post has a section explaining GitHub login ("No separate account needed"). This must be updated to explain that signups are now restricted.

**File to create**: `docs/admin/blog-post-draft.md`

**Operator instruction**: Apply the changes in this file to `ddev/ddev.com/src/content/blog/coder-ddev-com-announcement.md` and open a PR to `ddev/ddev.com`.

First, create the file with a header explaining what this file is and how to use it, followed by the draft content.

**Content structure for the file**:

```markdown
# Blog Post Update Draft: coder.ddev.com Org-Gated Signup

**Target file**: `ddev/ddev.com/src/content/blog/coder-ddev-com-announcement.md`
**Action**: Apply these section replacements to the blog post, then open a PR to `ddev/ddev.com`

---

## Section: "Log In with GitHub" — Replace existing content

Find the section in the blog post that explains GitHub login. Replace the existing content of that section with the following:

---

### Log In with GitHub

Access to coder.ddev.com requires a GitHub account. Sign in using the **Sign in with GitHub** button — no separate Coder account registration is needed.

**Who has access:**

- Members of the [ddev](https://github.com/ddev) GitHub organization
- Members of organizations that sponsor DDEV at $100+/month (see the [DDEV sponsors page](https://ddev.com/support-ddev/))
- Individuals approved by the DDEV maintainers

If you are a `ddev` org member or your organization is a $100+/month sponsor, you can sign in immediately — no request needed.

---
```

**Validation**:
- [ ] File is created at `docs/admin/blog-post-draft.md`
- [ ] Operator instruction (target file + how to apply) is at the top
- [ ] "Who has access" lists all three tiers
- [ ] The old "No separate account needed" language is replaced (not just appended)

---

## Subtask T015 — Add Access Restriction Paragraph and Access Paths

**Purpose**: Add a paragraph explaining that signups are restricted and describing the two paths to access: already-in-an-org, or request access.

**Location**: In `docs/admin/blog-post-draft.md`, append to the section started in T014.

**Content to append to the draft**:

```markdown
## Section: Access Restriction and Request Path — Add after "Log In with GitHub"

Add the following as a new paragraph or subsection immediately after the "Log In with GitHub" section:

---

### Requesting Access

If you do not have access through one of the paths above, you can request it by opening an issue in the [coder-ddev-com/access-requests](https://github.com/coder-ddev-com/access-requests) repository on GitHub. Include your GitHub username and a brief description of how you plan to use the environment.

The DDEV maintainers review requests and add approved users to the `coder-ddev-com` GitHub organization. Once added, you can sign in immediately — no server restart needed on our end.

---
```

**Validation**:
- [ ] Link to `https://github.com/coder-ddev-com/access-requests` is present and correct
- [ ] The process (open issue → review → org invite → sign in) is explained
- [ ] The section is clearly marked as "add after" the previous section

---

## Subtask T016 — Add Sponsor Org Access Benefit Mention

**Purpose**: Sponsor organizations may not know their members can now log in. Adding a mention in the blog post (and the sponsor notification in WP03) covers the announcement angle.

**Location**: In `docs/admin/blog-post-draft.md`, append a final section.

**Content to append to the draft**:

```markdown
## Section: Sponsor Org Access — Add to "Sponsors" or "Support DDEV" section

If the blog post has a section mentioning DDEV sponsors, add the following sentence or short paragraph. If no such section exists, add it as a standalone callout near the end of the post:

---

**Sponsor org access**: Organizations that sponsor DDEV at $100+/month receive access as an org-level benefit — all members of a sponsor's GitHub organization can sign in to coder.ddev.com without individual enrollment. See the [DDEV sponsors page](https://ddev.com/support-ddev/) if your organization is interested in sponsoring.

---

**Note for operator**: If the blog post already has a sponsors callout, integrate this sentence rather than adding a duplicate section.
```

**Validation**:
- [ ] The sponsor benefit (org-level, all members) is stated clearly
- [ ] Link to ddev.com/support-ddev/ is present
- [ ] Operator note about avoiding duplicates is present

---

## Definition of Done

- [ ] `docs/admin/blog-post-draft.md` exists and has three clearly delineated sections:
  1. Updated "Log In with GitHub" content
  2. New "Requesting Access" paragraph with link to access-requests repo
  3. Sponsor org access benefit mention
- [ ] Operator instructions at the top of the file explain the target file and how to apply changes
- [ ] All three access tiers are mentioned somewhere in the draft
- [ ] The `coder-ddev-com/access-requests` URL is correct
- [ ] No broken Markdown links

## Risks

- The actual blog post content is in a separate repo (`ddev/ddev.com`) that this agent does not have direct access to. The draft is produced without reading the original post, so section names in "Find and replace" instructions are approximate. The operator will need to locate the correct sections by reading the original.
- If the blog post structure has changed significantly since the announcement, the operator may need to adapt the draft rather than apply it verbatim.

## Activity Log

- 2026-05-07T19:01:42Z – claude – shell_pid=32508 – Started implementation via action command
- 2026-05-07T19:02:14Z – claude – shell_pid=32508 – Ready for review: blog-post-draft.md created with 3 sections
