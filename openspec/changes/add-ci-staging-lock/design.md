# Design: CI Staging-Box Concurrency Lock

## Context
Three integration-test workflows create real, resource-heavy (Sysbox + Docker-in-Docker) workspaces on one shared staging Coder deployment. Jobs originate from a mix of self-hosted runners (which happen to run on the staging box itself) and GitHub-hosted `ubuntu-latest` runners (ephemeral VMs with no shared filesystem with anything). Any lock mechanism must therefore be reachable over the network by every contender — a local `flock`/`mkdir` lock on the staging box would not see GitHub-hosted contenders at all.

## Goals / Non-Goals
- Goal: bound the number of concurrently-provisioning/running `ci-bot` workspaces to a configurable `N`, closing the check-then-act race that let it go unbounded.
- Goal: self-heal if a job dies mid-hold without releasing its slot (crashed job, cancelled run, killed runner).
- Non-goal: fine-grained resource accounting (summing actual CPU/RAM requests). A fixed slot count is a coarse but sufficient proxy, tunable as real headroom is learned.
- Non-goal: unifying self-hosted vs. GitHub-hosted execution for these jobs. That's a plausible future simplification (run everything on self-hosted runners on the staging box itself, since a local lock would then suffice) but out of scope here.

## Decision: Coder-workspace-slot CAS, not a git-ref lock
Two network-reachable atomic primitives were considered:

1. **Chosen: N fixed-name Coder workspaces** (`ci-slot-1`..`ci-slot-N`), created from a new minimal `ci-lock` template. Coder enforces a unique workspace name per owner — confirmed behavior, not an assumption (it's how `ci-reap-family.sh` already identifies workspace "families" and how `coder create` collisions are known to fail today). Attempting `coder create ci-slot-<i>` is therefore a genuine atomic compare-and-swap: exactly one concurrent caller can win for a given `i`. Releasing is `coder delete ci-slot-<i>`. Because the slot workspaces are owned by `ci-bot` like every other CI workspace, the existing `scripts/ci-reap-staging.sh` janitor (runs every 15 minutes, reaps `ci-bot`-owned workspaces by state/age) already self-heals abandoned slots with zero changes to that script.

2. **Rejected: N fixed git branch names**, claimed via `git push origin HEAD:refs/heads/ci-slot-N` (atomic ref creation) and released by deleting the branch. This avoids adding a new Coder template, but: (a) none of the three workflow files currently set a `permissions:` block, so the default `GITHUB_TOKEN` likely lacks `contents: write` — this option requires explicitly granting that; (b) it needs its own bespoke stale-lock reaper (age-check a branch's last-commit timestamp, force-delete), duplicating logic that already exists for Coder workspaces rather than reusing it.

3. **Considered and discarded without enough confidence: named Coder API tokens** (`coder tokens create --name ci-slot-N`) as the CAS, avoiding a Terraform template entirely. Whether token names are enforced unique per user (and thus safe as a CAS) could not be confirmed from the CLI help text or public docs in the time available. Workspace-name uniqueness, by contrast, is directly evidenced in this repo's existing scripts and is a well-known Coder invariant. Given a broken CAS would silently reintroduce the exact race this change exists to fix, the better-evidenced primitive was chosen.

## Mechanism
- `ci-lock/template.tf`: minimal template, no `coder_agent`, just the `coder` provider and a single no-op resource (`terraform_data`). Provisions/destroys in ~1-2s, touches no Docker/Sysbox.
- `scripts/ci-acquire-staging-lock.sh`:
  - `N` from `CI_LOCK_SLOTS` (default 2), `MAX_WAIT_SECONDS` / `POLL_SECONDS` matching the old script's conventions.
  - Loop: for `i` in a randomized order over `1..N`, attempt `coder create ci-slot-<i> --template ci-lock --yes`. Success = lock acquired; print which slot for the release step to reuse (write to `$GITHUB_ENV` as `CI_LOCK_SLOT`).
  - If all `N` slots are taken: check each slot's build age; if older than `STALE_MINUTES` (default 30 — comfortably longer than any real job), force `coder delete` it and retry immediately (self-heal). Otherwise sleep `POLL_SECONDS` + jitter and retry, up to `MAX_WAIT_SECONDS`.
- `scripts/ci-release-staging-lock.sh`: `coder delete "$CI_LOCK_SLOT" --yes`. Called in an `if: always()` step so normal completion, test failure, and most cancellations all release; the staleness check above is the backstop for the remaining case (hard-killed runner, no steps execute at all).

## Rollout
`N` starts at 2 (default), given the staging box's 4-core/8-thread/64GB spec and each workspace's default 4-CPU/8GB request. Adjust via the `CI_LOCK_SLOTS` env/repo variable as real utilization data comes in — no code change needed to retune.
