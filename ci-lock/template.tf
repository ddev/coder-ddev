# CI-internal mutex, not a development environment.
#
# Integration-test CI jobs create real, resource-heavy (Sysbox + Docker-in-Docker)
# workspaces on a single shared staging Coder box, from both self-hosted runners
# and GitHub-hosted runners. To bound how many of those run at once without a
# check-then-act race, jobs claim one of N fixed-name workspaces provisioned from
# THIS template (ci-slot-1..N) before creating their real workspace, and delete it
# when done. Coder enforces a unique workspace name per owner, so `coder create
# ci-slot-<i>` is an atomic compare-and-swap: only one concurrent caller can win
# for a given <i>. See scripts/ci-acquire-staging-lock.sh /
# scripts/ci-release-staging-lock.sh for the protocol. A git-ref lock
# (`git push origin HEAD:refs/heads/ci-slot-N`) was rejected: it needs
# `contents: write` on GITHUB_TOKEN and its own stale-lock reaper, while
# ci-bot-owned slot workspaces are already reaped by scripts/ci-reap-staging.sh.
#
# Deliberately has no coder_agent: a lock slot is never connected to, only
# created and deleted, so it provisions and tears down in a second or two.

terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = ">= 2.13"
    }
  }
}

resource "terraform_data" "lock" {}
