#!/usr/bin/env bash
# Release the staging box lock slot claimed by ci-acquire-staging-lock.sh.
#
# Usage:
#   ci-release-staging-lock.sh
#   # reads $CI_LOCK_SLOT (set by the acquire script, normally via
#   # $GITHUB_ENV so it survives into this later step)
#
# Always exits 0 -- releasing is best-effort and must never fail a run. If a
# job dies before this step runs at all, the slot is reclaimed automatically:
# either by a later contender's staleness check in ci-acquire-staging-lock.sh,
# or by the existing scripts/ci-reap-staging.sh janitor, which already reaps
# any stale ci-bot-owned workspace by age.

set -uo pipefail

if [[ -z "${CI_LOCK_SLOT:-}" ]]; then
  echo "No CI_LOCK_SLOT set; nothing to release"
  exit 0
fi

echo "Releasing staging box lock slot: $CI_LOCK_SLOT"
coder delete "$CI_LOCK_SLOT" --yes || echo "WARN: delete failed for $CI_LOCK_SLOT" >&2
exit 0
