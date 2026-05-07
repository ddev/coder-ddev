---
work_package_id: WP01
title: Update server-setup.md for Org-Gated Auth
dependencies: []
requirement_refs:
- C-003
- C-004
- C-005
- C-006
- C-007
- FR-001
- FR-005
- FR-006
- FR-007
- FR-008
- FR-009
- FR-013
- FR-014
planning_base_branch: 20260507_speckitty
merge_target_branch: 20260507_speckitty
branch_strategy: Planning artifacts for this feature were generated on 20260507_speckitty. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into 20260507_speckitty unless the human explicitly redirects the landing branch.
subtasks:
- T001
- T002
- T003
- T004
- T005
history:
- date: '2026-05-07'
  event: created
authoritative_surface: docs/admin/server-setup.md
execution_mode: code_change
owned_files:
- docs/admin/server-setup.md
tags: []
---

# WP01 — Update server-setup.md for Org-Gated Auth

## Branch Strategy

- **Planning base**: `20260507_speckitty`
- **Merge target**: `20260507_speckitty`
- Implement directly on `20260507_speckitty`. Run `spec-kitty agent action implement WP01 --agent claude`.

## Objective

Update `docs/admin/server-setup.md` to be the authoritative operator reference for the new GitHub org-gated authentication model. The current doc covers only a single `ddev`-org restriction; it needs to reflect:
- The full 27-org `ALLOWED_ORGS` list (sponsors + ddev + coder-ddev-com)
- Two separate OAuth Apps (staging vs. production)
- The purpose and management of the `coder-ddev-com` org
- The sponsor org access policy with the full mapping table
- A runbook for adding a new sponsor org

## Context

The Coder server is deployed via apt deb package on Ubuntu, managed by systemd. Runtime config lives in `/etc/coder.d/coder.env` on the host — not committed to this repo. `docs/admin/server-setup.md` is the operator's guide for setting up that file.

The current GitHub OAuth section (around line 660) shows only:
```bash
CODER_OAUTH2_GITHUB_ALLOWED_ORGS=ddev
```

This needs to become the full list, and the surrounding documentation needs to explain why so many orgs appear and how to manage them.

**Read the current file before editing**: `docs/admin/server-setup.md`. The GitHub OAuth section spans approximately lines 660–710. All changes are within that section unless adding a new sub-section.

## Subtask T001 — Update `ALLOWED_ORGS` to Full 27-Org List

**Purpose**: Change the example env var block to include all approved orgs.

**Location**: `docs/admin/server-setup.md`, inside the env var code block in "Step 2: Add to `/etc/coder.d/coder.env`".

**Current value**:
```bash
CODER_OAUTH2_GITHUB_ALLOWED_ORGS=ddev
```

**New value**:
```bash
# Access control: ddev org members, coder-ddev-com managed list, and $100+/month sponsor orgs
CODER_OAUTH2_GITHUB_ALLOWED_ORGS=ddev,coder-ddev-com,tag1consulting,upsun,platformsh,Institute-for-Advanced-Studies,CPS-IT,redfinsolutions,Lullabot,b13,pixelandtonic,Cambrico,centarro,8mylez,dkd,liip,i-gelb,FameHelsinki,Gizra,mobilistics,OPTASY,passbolt,vaersaagod,affinitybridge,AGILEDROP,NPO-Applications-GmbH,AtenDesignGroup
```

**Note**: `Institute-for-Advanced-Studies` is included but flagged for operator verification — the GitHub org exists but has no public name/description confirming identity. Add an inline comment noting this.

**Validation**:
- [ ] The code block compiles as valid bash (no stray characters)
- [ ] All 27 org slugs are present (count them)
- [ ] The comment above the var explains the three access tiers

---

## Subtask T002 — Add Staging OAuth App Sub-section

**Purpose**: The current doc only documents the production OAuth App. Operators need to know they must register a *separate* app for staging, with a different callback URL, before testing on staging-coder.ddev.com.

**Location**: Add a new sub-section immediately after the "Create a GitHub OAuth App" step (currently "Step 1"), before or as part of the env var step.

**Content to add** (adapt prose as needed, keep the tone of the existing doc):

```markdown
#### Two OAuth Apps: staging and production

Register **two separate OAuth Apps** — one for staging, one for production. Separate apps isolate credentials between environments so that a staging secret compromise cannot affect production, and secret rotation on one environment does not require touching the other.

**Staging app settings:**
- **Application name**: `Coder (staging-coder.ddev.com)`
- **Homepage URL**: `https://staging-coder.ddev.com`
- **Authorization callback URL**: `https://staging-coder.ddev.com/api/v2/users/oauth2/github/callback`
- **Enable Device Flow**: leave unchecked

**Production app settings** (unchanged from above):
- **Application name**: `Coder (coder.ddev.com)`
- **Homepage URL**: `https://coder.ddev.com`
- **Authorization callback URL**: `https://coder.ddev.com/api/v2/users/oauth2/github/callback`
- **Enable Device Flow**: leave unchecked

Use the staging app's Client ID and Client Secret in `/etc/coder.d/coder.env` on staging-coder.ddev.com, and the production app's credentials on coder.ddev.com.
```

**Validation**:
- [ ] Both callback URLs are present and correct
- [ ] Device Flow warning is clear
- [ ] Staging section appears before the env var block it feeds into

---

## Subtask T003 — Document `coder-ddev-com` Org Purpose

**Purpose**: Explain to operators what `coder-ddev-com` is for — the managed access list for individuals who are not members of the `ddev` org or a sponsor org.

**Location**: Add a new sub-section after the env var block, titled "### Managing individual access via `coder-ddev-com`".

**Content to add**:

```markdown
### Managing individual access via `coder-ddev-com`

The `coder-ddev-com` GitHub organization is the managed access list for individuals who do not belong to the `ddev` org or one of the sponsor orgs. Adding someone to `coder-ddev-com` grants them signup access to coder.ddev.com without requiring a Coder server restart.

**To grant access to an individual:**
1. Go to [github.com/coder-ddev-com](https://github.com/coder-ddev-com) → **People** → **Invite member**
2. Enter the person's GitHub username and send the invitation
3. Once they accept, they can log in to coder.ddev.com via GitHub OAuth

**Initial members** (add these when creating the org):
- `dougvann` — individual $100/month GitHub Sponsor
- `claudiu-cristea` — Webikon sponsor (linked as individual on ddev.com)
- Add LetsTalk, Amedick Sommer, and Pottkinder GmbH contacts when their GitHub usernames are confirmed

**Note on private membership**: Users do not need to make their `coder-ddev-com` membership public. Private membership is sufficient — the `read:org` OAuth scope allows Coder to verify membership regardless of visibility setting.
```

**Validation**:
- [ ] The "initial members" list matches research.md
- [ ] The privacy note is present
- [ ] The section is placed logically after the env var block

---

## Subtask T004 — Add Sponsor Org Access Table

**Purpose**: Document the full list of approved sponsor org slugs so operators know what's in `ALLOWED_ORGS` and why.

**Location**: Add a sub-section "### Sponsor org access policy" after the `coder-ddev-com` section from T003.

**Content to add**:

```markdown
### Sponsor org access policy

All $100+/month DDEV sponsors receive access as an org-level benefit: every member of a sponsor's GitHub org can sign in to coder.ddev.com without individual enrollment. MacStadium and JetBrains are excluded (in-kind, not cash sponsors).

| Company | GitHub org | Source |
| ------- | ---------- | ------ |
| Tag1 | `tag1consulting` | invoiced |
| Upsun | `upsun` | invoiced |
| Platform.sh (Upsun predecessor) | `platformsh` | invoiced |
| Institute for Advanced Studies | `Institute-for-Advanced-Studies` ⚠️ | invoiced |
| CPS-IT | `CPS-IT` | invoiced |
| Redfin Solutions | `redfinsolutions` | invoiced + featured |
| Lullabot | `Lullabot` | invoiced |
| B13 | `b13` | invoiced + featured |
| Pixel & Tonic (Craft CMS) | `pixelandtonic` | invoiced + featured |
| Cambrico | `Cambrico` | invoiced + featured |
| Centarro | `centarro` | invoiced + featured |
| 8mylez | `8mylez` | invoiced |
| dkd Internet Service GmbH | `dkd` | GitHub Sponsors |
| Liip | `liip` | GitHub Sponsors |
| i-gelb GmbH | `i-gelb` | featured |
| Fame Helsinki | `FameHelsinki` | featured |
| Gizra | `Gizra` | featured |
| mobilistics GmbH | `mobilistics` | featured |
| OPTASY | `OPTASY` | featured |
| Passbolt | `passbolt` | featured |
| Værsågod | `vaersaagod` | featured |
| Affinity Bridge | `affinitybridge` | featured |
| Agiledrop | `AGILEDROP` | featured |
| NPO Applications GmbH | `NPO-Applications-GmbH` | featured |
| Aten Design Group | `AtenDesignGroup` | featured |

⚠️ `Institute-for-Advanced-Studies` — GitHub org exists but has no public name/description. Confirm with operator before deployment that this is the correct org.

Sponsors with no GitHub org (access via `coder-ddev-com` individual membership instead): LetsTalk, Amedick Sommer, Pottkinder GmbH.
```

**Validation**:
- [ ] Table has 25 rows (all confirmed sponsor orgs)
- [ ] IAS warning note is present
- [ ] Excluded and unresolved sponsors are noted

---

## Subtask T005 — Add "Adding a New Sponsor Org" Runbook

**Purpose**: When a new organization becomes a $100+/month sponsor, an operator needs to know exactly how to grant them access. This runbook is the process.

**Location**: Add after the sponsor org table, as "#### Adding a new sponsor org".

**Content to add**:

```markdown
#### Adding a new sponsor org

When a new organization reaches the $100+/month sponsorship level:

1. **Find their GitHub org slug**: Check the sponsor's GitHub profile or ask them directly. Verify with `gh api orgs/<slug> --jq '.login'` — if the command returns the slug, the org exists.

2. **Add the slug to `ALLOWED_ORGS`** on both staging and production:
   ```bash
   # On the server, edit /etc/coder.d/coder.env
   # Append the new slug to CODER_OAUTH2_GITHUB_ALLOWED_ORGS (comma-separated, no spaces)
   sudo systemctl restart coder
   ```

3. **Test on staging first**: Ask someone from the org to attempt login on staging-coder.ddev.com before updating production.

4. **Update this table**: Add the org to the sponsor org table above so the list stays accurate.

5. **Notify the sponsor**: Send the sponsor notification (see `docs/admin/coder-ddev-com/sponsor-notification.md`) letting them know their org members now have access.

**If the sponsor has no GitHub org**: Add their individual GitHub username to the `coder-ddev-com` org instead (see "Managing individual access" above). No server restart needed.
```

**Validation**:
- [ ] The five-step process is present
- [ ] The "no GitHub org" fallback path is documented
- [ ] References to staging-first are consistent with C-004

---

## Definition of Done

- [ ] `docs/admin/server-setup.md` contains the full 27-org `ALLOWED_ORGS` value
- [ ] A staging OAuth App sub-section is present with correct callback URL
- [ ] `coder-ddev-com` org purpose and management is documented
- [ ] Sponsor org table is present with all 25 sponsor orgs
- [ ] "Adding a new sponsor org" runbook is present
- [ ] `terraform fmt` is not applicable (Markdown only — run `git diff docs/admin/server-setup.md` to review)
- [ ] No broken Markdown links

## Risks

- The `ALLOWED_ORGS` value is long; a typo in a slug silently excludes that org's members. Verify the slug list against `kitty-specs/github-org-gated-signup-01KR1P4G/research.md` before committing.
- `Institute-for-Advanced-Studies` is unverified — note this clearly in the doc.
