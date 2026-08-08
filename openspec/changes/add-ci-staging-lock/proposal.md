# Change: Add CI Staging-Box Concurrency Lock

## Why
Integration-test CI jobs that create real workspaces on the shared staging Coder box (`staging-coder.ddev.com`) currently serialize via `scripts/ci-wait-for-staging-box.sh`, which polls `coder list` for a zero count of `ci-bot`-owned workspaces before proceeding to `coder create`. This is a check-then-act race: multiple jobs — from different workflow files, and from both self-hosted `sysbox` runners and GitHub-hosted `ubuntu-latest` runners, all reaching the same remote Coder server — can observe "0 workspaces" within the same ~30s poll window and all create at once.

This was observed directly in production: on 2026-08-08, three `ci-bot` workspaces existed simultaneously on staging (the count jumped from 1 to 3 within one poll interval — see `Contrib skipto D12 (plain, GH)`'s log in run 31230219543), and the job racing into that window (`Contrib token issue fork (GH)`) failed its `coder ssh --wait=yes` connection with "Agent doesn't exist with that id" — a symptom of the box being oversubscribed (each workspace defaults to 4 CPU / 8GB against a single 4-core/8-thread, 64GB host).

The intent was never strict one-at-a-time serialization — jobs that don't compete for the same real resources are fine running concurrently — it was to cap concurrent *heavy* workspaces at whatever the box can actually sustain. The current mechanism achieves neither: it's racy, and (at its effective N=1) stricter than the box's real headroom requires.

## What Changes
- Replace the racy poll-then-create check with a true atomic semaphore of size `N` (repo variable, default 2), implemented via a new minimal `ci-lock` Coder template (no Docker/Sysbox, provisions in ~1-2s) whose only purpose is to let jobs claim one of `N` fixed-name lock-slot workspaces (`ci-slot-1`..`ci-slot-N`) using Coder's existing per-owner unique-workspace-name constraint as the atomic compare-and-swap.
- Add `scripts/ci-acquire-staging-lock.sh` (claim a free slot; retry with backoff + jitter up to a timeout; self-heal by force-releasing a slot whose holder is stale) and `scripts/ci-release-staging-lock.sh` (delete the claimed slot workspace).
- Replace all call sites of `scripts/ci-wait-for-staging-box.sh` across `integration-test.yml`, `drupal-integration-test.yml`, and `drupal-contrib-integration-test.yml` with the new acquire script, and add a matching `if: always()` release step alongside each job's existing "Delete workspace" cleanup.
- Remove `scripts/ci-wait-for-staging-box.sh` (superseded).
- No changes needed to `scripts/ci-reap-staging.sh` — it already reaps any stale `ci-bot`-owned workspace by age, which covers abandoned lock-slot workspaces for free.

## Impact
- Affected specs: `ci-staging-concurrency` (new capability)
- Affected code: new `ci-lock/template.tf` (+ Makefile wiring to validate/push it alongside the other three templates), `scripts/ci-wait-for-staging-box.sh` (removed), `scripts/ci-acquire-staging-lock.sh` (new), `scripts/ci-release-staging-lock.sh` (new), `.github/workflows/integration-test.yml`, `.github/workflows/drupal-integration-test.yml`, `.github/workflows/drupal-contrib-integration-test.yml`
