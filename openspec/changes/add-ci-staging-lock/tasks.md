## 1. `ci-lock` template
- [x] 1.1 Create `ci-lock/template.tf`: `coder` provider only, single no-op `terraform_data` resource, no `coder_agent` <!-- id: 1.1 -->
- [x] 1.2 Wire `ci-lock` into the Makefile's validate / test-templates / push-all-templates targets alongside the other three templates <!-- id: 1.2 -->
- [x] 1.3 `terraform fmt -recursive` and `make validate` pass for the new template <!-- id: 1.3 -->

## 2. Lock scripts
- [x] 2.1 Add `scripts/ci-acquire-staging-lock.sh`: randomized slot order over `1..N` (`CI_LOCK_SLOTS`, default 2), atomic `coder create ci-slot-<i>`, staleness self-heal (`STALE_MINUTES`, default 30), `MAX_WAIT_SECONDS`/`POLL_SECONDS` matching prior conventions, writes acquired slot name to `$GITHUB_ENV` <!-- id: 2.1 -->
- [x] 2.2 Add `scripts/ci-release-staging-lock.sh`: `coder delete "$CI_LOCK_SLOT" --yes`, best-effort (never fails the job) <!-- id: 2.2 -->
- [x] 2.3 Remove `scripts/ci-wait-for-staging-box.sh` (superseded) <!-- id: 2.3 -->

## 3. Workflow wiring
- [x] 3.1 Enumerate every job in `integration-test.yml`, `drupal-integration-test.yml`, `drupal-contrib-integration-test.yml` that currently calls `ci-wait-for-staging-box.sh` <!-- id: 3.1 -->
- [x] 3.2 Replace each with a call to `ci-acquire-staging-lock.sh` <!-- id: 3.2 -->
- [x] 3.3 Add an `if: always()` "Release staging box lock" step (calling `ci-release-staging-lock.sh`) to each of those jobs, ordered alongside the existing "Delete workspace" cleanup <!-- id: 3.3 -->
- [x] 3.4 Add the `CI_LOCK_SLOTS` repo variable reference (default fallback `2` if unset) <!-- id: 3.4 -->

## 4. Validation
- [x] 4.1 `make validate` and `make test-templates` pass repo-wide <!-- id: 4.1 -->
- [x] 4.2 `terraform fmt -check -recursive` clean <!-- id: 4.2 -->
- [x] 4.3 Update `docs/admin/server-setup.md` / any doc referencing `ci-wait-for-staging-box.sh` to reference the new scripts <!-- id: 4.3 -->
      (no such references existed; nothing to change)
