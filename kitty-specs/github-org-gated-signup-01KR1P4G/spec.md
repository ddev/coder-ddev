# GitHub Org-Gated Signup

## Summary

Currently, anyone with a GitHub account can create a Coder account on coder.ddev.com and spin up unlimited workspaces. This is unsustainable and represents a direct cost and security risk to the service. This feature restricts new account signups to members of two GitHub organizations — the existing `ddev` org and a new `coder-ddev-com` org created specifically as a managed access list — while keeping existing user accounts and password authentication intact.

**Related issues:** [#64 User creation and authentication control](https://github.com/ddev/coder-ddev/issues/64), [#54 Offer additional login options](https://github.com/ddev/coder-ddev/issues/54)

---

## Goals

- Prevent arbitrary GitHub users from self-registering on coder.ddev.com or staging-coder.ddev.com.
- Allow all members of the `ddev` GitHub org to sign in and create workspaces.
- Allow all members of the `coder-ddev-com` GitHub org to sign in and create workspaces.
- Preserve access for users who already have accounts on coder.ddev.com.
- Maintain an emergency escape hatch: manually-provisioned accounts using password authentication must remain usable.
- Retain full DDEV ownership of OAuth credentials (no data sharing with Coder the company).

## Non-Goals

- No password authentication is added for new users. The existing password auth path is preserved only for pre-created exception accounts.
- No OIDC, GitLab, or other providers are added as part of this change.
- No changes to workspace templates, Docker images, or resource limits.

---

## User Scenarios & Testing

**Scenario 1 — ddev org member signs up (happy path):**
A developer who is a public member of the `ddev` GitHub org visits coder.ddev.com, clicks "Sign in with GitHub," authorizes the OAuth app, and lands on the Coder dashboard. Account is created automatically.

**Scenario 2 — coder-ddev-com org member signs up:**
A developer who has been added to the `coder-ddev-com` GitHub org visits coder.ddev.com, clicks "Sign in with GitHub," and successfully creates an account.

**Scenario 3 — unauthorized GitHub user is rejected:**
A GitHub user who is not a member of either `ddev` or `coder-ddev-com` attempts to sign in. They see an error message indicating they are not authorized. No account is created.

**Scenario 4 — existing user retains access:**
A user who already has a coder.ddev.com account (created before this change) logs in via GitHub OAuth or password auth and accesses their workspaces without disruption.

**Scenario 5 — exception account via password:**
An admin pre-creates a user account with a password credential. That user logs in without GitHub OAuth. This path continues to work because `CODER_DISABLE_PASSWORD_AUTH` is never set to `true`.

**Scenario 6 — staging parity:**
The same org-restriction configuration is applied to staging-coder.ddev.com, so staging behavior accurately reflects production before promotion.

---

## Functional Requirements

| ID | Requirement | Status |
| ---- | ------------- | -------- |
| FR-001 | New GitHub OAuth signups are restricted to members of the `ddev` GitHub org and the `coder-ddev-com` GitHub org. Users outside both orgs cannot create accounts. | Approved |
| FR-002 | The `coder-ddev-com` GitHub org exists and can have members added to grant access without requiring `ddev` org membership. | Approved |
| FR-003 | Existing user accounts on coder.ddev.com remain active and accessible after the restriction is applied. | Approved |
| FR-004 | Password-based login remains available for manually-provisioned accounts. Password auth is never globally disabled. | Approved |
| FR-005 | Both staging-coder.ddev.com and coder.ddev.com have identical org-restriction configuration. | Approved |
| FR-006 | A custom DDEV-owned GitHub OAuth App is registered and used for authentication, replacing the default Coder-provided app. | Approved |
| FR-007 | The OAuth App is registered under the `ddev` GitHub organization so credentials are DDEV-controlled, not held by an individual account. | Approved |
| FR-008 | Authorized users from both orgs can create and use workspaces on both environments. | Approved |
| FR-009 | An operator runbook documents how to add a user to the `coder-ddev-com` org and how to pre-create exception accounts with password credentials. | Approved |
| FR-010 | The `coder-ddev-com` GitHub org has a README (in its `.github` or dedicated `about` repo) explaining the org's purpose, who it is for, and how access works. | Approved |
| FR-011 | A public repository in the `coder-ddev-com` org provides an issue tracker where prospective users can request access by opening a GitHub issue. | Approved |
| FR-012 | The ddev.com blog post announcing coder.ddev.com is updated to explain that signups are now restricted, how the `coder-ddev-com` org works, and where to open an access request. | Approved |
| FR-013 | GitHub organizations that sponsor DDEV at $100+/month (via GitHub Sponsors or invoiced billing) are eligible for access: all members of those orgs can sign in to coder.ddev.com without individual `coder-ddev-com` membership. | Approved |
| FR-014 | A runbook documents how to identify the GitHub org name for a new $100+ sponsor and add it to the allowed-orgs list on both environments. | Approved |
| FR-015 | Each sponsor org that has been granted access is notified about the benefit — what access they have, how to use it, and who to contact if they need help. | Approved |

---

## Non-Functional Requirements

| ID | Requirement | Threshold | Status |
| ---- | ------------- | ----------- | -------- |
| NFR-001 | Authorized users experience no increase in login time after the change. | Sign-in round-trip completes within the same time as before (under 10 seconds on a normal connection). | Approved |
| NFR-002 | The org membership check does not require users to make their org membership public. | Private `ddev` or `coder-ddev-com` org membership must be sufficient for login. | Approved |
| NFR-003 | Applying the configuration change causes zero downtime for existing active sessions. | No active workspace sessions are interrupted during config rollout. | Approved |

---

## Constraints

| ID | Constraint | Status |
| ---- | ---------- | -------- |
| C-001 | `CODER_DISABLE_PASSWORD_AUTH` must never be set to `true`. Password auth must remain available for exception accounts. | Approved |
| C-002 | The `coder-ddev-com` GitHub org must be a real GitHub organization (not a personal account) so membership can be managed by multiple org owners. | Approved |
| C-003 | The custom GitHub OAuth App must request at minimum: `read:user`, `user:email`, and `read:org` scopes. The `read:org` scope is required for Coder to verify org membership. | Approved |
| C-004 | The change must be applied to staging first and validated before applying to production. | Approved |
| C-005 | OAuth App credentials (client ID and client secret) must be stored as server-level secrets, not committed to the repository. | Approved |
| C-006 | Sponsor orgs are added to `CODER_OAUTH2_GITHUB_ALLOWED_ORGS` directly (not proxied via `coder-ddev-com` membership), so all members of a sponsor org benefit automatically without individual enrollment. | Approved |
| C-007 | The `invoiced-sponsorships.jsonc` data file does not contain GitHub org names; a manual or scripted mapping from company name to GitHub org name is required before any sponsor org can be added. | Approved |

---

## Success Criteria

1. A GitHub user who is not in `ddev` or `coder-ddev-com` cannot create an account on coder.ddev.com.
2. All current members of the `ddev` org can sign in to coder.ddev.com without any manual step beyond GitHub OAuth.
3. An admin can grant access to a new non-ddev-org user by adding them to `coder-ddev-com`, with no Coder server change required.
4. At least one pre-existing user account continues to function after the rollout (no accounts locked out).
5. Staging-coder.ddev.com and coder.ddev.com enforce the same restriction after both are reconfigured.
6. A prospective user who is not in `ddev` or `coder-ddev-com` can find the access-request issue tracker without assistance.
7. The ddev.com blog post no longer implies open signup; it accurately describes the access model and links to the access-request repo.
8. Members of at least one confirmed $100+/month sponsor org can sign in to coder.ddev.com without being explicitly added to `coder-ddev-com`.
9. Each sponsor org listed in `ALLOWED_ORGS` has been notified of the access benefit before or shortly after the production rollout.

---

## Assumptions

- The `coder-ddev-com` GitHub organization does not yet exist and must be created before configuration is applied.
- The current Coder server deployment on both environments exposes environment variables that can be updated without rebuilding images.
- Coder's org membership check works with private org membership when the `read:org` scope is granted — users do not need to publicize their org membership.
- The GitHub OAuth App will be registered under the `ddev` org (not a personal account), so ownership is institutional.

---

## Out of Scope

- Automating `coder-ddev-com` membership management (e.g., via a bot or form).
- Removing or migrating existing user accounts.
- Implementing GitLab, OIDC, or any other auth provider.
- Rate limiting, abuse prevention, or workspace quota enforcement (separate concern from issue #64's unlimited workspace problem).
