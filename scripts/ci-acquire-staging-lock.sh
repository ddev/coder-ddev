#!/usr/bin/env bash
# Claim one of N fixed-name "lock slot" workspaces before creating a real
# workspace on the shared staging box, bounding how many heavy (Sysbox +
# Docker-in-Docker) CI workspaces can run there at once.
#
# Why this exists:
#   The box-busy check this replaces (ci-wait-for-staging-box.sh) polled
#   `coder list` for a zero count, then created its own workspace -- a
#   check-then-act race. Jobs come from different workflow files and from
#   both self-hosted `sysbox` runners and GitHub-hosted `ubuntu-latest`
#   runners, all reaching the same remote Coder server, so multiple jobs
#   could observe "0 workspaces" in the same ~30s poll window and all create
#   at once. This happened in production: three ci-bot workspaces existed
#   simultaneously on a box sized for about two, and the job racing into that
#   window failed its agent connection.
#
#   Coder enforces a unique workspace name per owner, so `coder create
#   ci-slot-<i>` is a genuine atomic compare-and-swap: exactly one concurrent
#   caller can win for a given <i>. Trying each of N slots in turn gives a
#   real bounded semaphore instead of a racy poll. The ci-lock template
#   (see ci-lock/template.tf) that these slots are provisioned from has no
#   Docker/Sysbox/agent, so claiming a slot is near-instant.
#
#   The box can comfortably run several workspaces at once once they're up --
#   the resource spike is the *start* of each one (Docker image builds,
#   composer installs). So on top of the slot count, STAGGER_SECONDS enforces
#   a minimum gap between successive workspace starts even when slots are
#   free, so simultaneous starts don't all hit their heaviest work together.
#
# Usage:
#   ci-acquire-staging-lock.sh
#   # on success, prints the acquired slot name and (if $GITHUB_ENV is set)
#   # writes CI_LOCK_SLOT=<slot> there for the matching release step to use.
#
# Environment:
#   CI_LOCK_SLOTS      Number of concurrent slots (default: 2)
#   CI_OWNER           Coder username that owns CI workspaces (default: ci-bot)
#   MAX_WAIT_SECONDS   Give up and fail after this long (default: 2700 = 45m)
#   POLL_SECONDS       Delay between full passes over all slots (default: 30)
#   STALE_MINUTES      Force-reclaim a held slot older than this (default: 30)
#   STAGGER_SECONDS    Minimum gap enforced between two workspace starts, even
#                      when slots are available (default: 90)

set -uo pipefail

CI_LOCK_SLOTS="${CI_LOCK_SLOTS:-2}"
CI_OWNER="${CI_OWNER:-ci-bot}"
MAX_WAIT_SECONDS="${MAX_WAIT_SECONDS:-2700}"
POLL_SECONDS="${POLL_SECONDS:-30}"
STALE_MINUTES="${STALE_MINUTES:-30}"
STAGGER_SECONDS="${STAGGER_SECONDS:-90}"

acquired=""
last_err=""

# Fisher-Yates-ish shuffle of 1..N so contenders don't all hammer slot 1 first.
shuffled_slots() {
  seq 1 "$CI_LOCK_SLOTS" | shuf
}

try_acquire_pass() {
  local i name out
  for i in $(shuffled_slots); do
    name="ci-slot-$i"
    if out=$(coder create "$name" --template ci-lock --yes 2>&1); then
      acquired="$name"
      return 0
    fi
    last_err="$out"
  done
  return 1
}

# Echoes the number of slots it force-reclaimed, so the caller can retry
# immediately instead of sleeping a full poll interval on a freed slot.
reclaim_stale_slots() {
  local slots_json now cutoff reclaimed
  reclaimed=0
  if ! slots_json=$(coder list --all --output json 2>/dev/null); then
    echo 0
    return
  fi
  now=$(date +%s)
  cutoff=$((now - STALE_MINUTES * 60))
  while IFS=$'\t' read -r name build_created; do
    [[ -z "$name" ]] && continue
    build_epoch=$(date -d "$build_created" +%s 2>/dev/null || echo 0)
    if [[ "$build_epoch" -gt 0 && "$build_epoch" -lt "$cutoff" ]]; then
      echo "Reclaiming stale lock slot: $name (build older than ${STALE_MINUTES}m)" >&2
      coder delete "$name" --yes >&2 || echo "  WARN: delete failed for $name" >&2
      reclaimed=$((reclaimed + 1))
    fi
  done < <(echo "$slots_json" |
    jq -r --arg owner "$CI_OWNER" \
      '.[] | select(.owner_name==$owner) | select(.name | startswith("ci-slot-")) | [.name, .latest_build.created_at] | @tsv')
  echo "$reclaimed"
}

# Sleeps out the remainder of STAGGER_SECONDS since the most recently created
# *other* lock slot, if any, so this job's workspace create doesn't land in
# the same CPU spike as one that just started. A no-op when no other slot was
# created recently (the common case outside a start burst).
stagger_if_needed() {
  local slots_json newest_other_created other_epoch now gap sleep_for
  slots_json=$(coder list --all --output json 2>/dev/null) || return
  newest_other_created=$(echo "$slots_json" |
    jq -r --arg owner "$CI_OWNER" --arg mine "$acquired" \
      '[.[] | select(.owner_name==$owner) | select(.name | startswith("ci-slot-")) | select(.name != $mine) | .latest_build.created_at] | max // empty')
  [[ -z "$newest_other_created" ]] && return
  other_epoch=$(date -d "$newest_other_created" +%s 2>/dev/null || echo 0)
  [[ "$other_epoch" -eq 0 ]] && return
  now=$(date +%s)
  gap=$((now - other_epoch))
  if [[ "$gap" -lt "$STAGGER_SECONDS" ]]; then
    sleep_for=$((STAGGER_SECONDS - gap))
    echo "Staggering start: another job's slot started ${gap}s ago; waiting ${sleep_for}s more"
    sleep "$sleep_for"
  fi
}

# Fail fast if the ci-lock template itself is missing (e.g. never pushed to
# this Coder deployment) rather than retrying a doomed `coder create` for the
# full MAX_WAIT_SECONDS -- that failure mode wastes 45 minutes per job with no
# indication of the real problem. See docs/admin/server-setup.md for the
# one-time `make push-all-templates` setup step.
if ! templates_json=$(coder templates list --output json 2>&1); then
  echo "ERROR: 'coder templates list' failed; cannot verify ci-lock template exists:" >&2
  echo "$templates_json" >&2
  exit 1
fi
if ! echo "$templates_json" | jq -e '[.[] | select(.Template.name=="ci-lock")] | length > 0' >/dev/null 2>&1; then
  echo "ERROR: no 'ci-lock' template found on this Coder deployment." >&2
  echo "Run 'make push-all-templates' against it once (see docs/admin/server-setup.md)." >&2
  exit 1
fi

# Jitter so contenders that all started in the same instant don't all sample
# slot state at the exact same moment.
sleep "$((RANDOM % 15))"

waited=0
while true; do
  if try_acquire_pass; then
    echo "Acquired staging box lock slot: $acquired"
    stagger_if_needed
    if [[ -n "${GITHUB_ENV:-}" ]]; then
      echo "CI_LOCK_SLOT=$acquired" >>"$GITHUB_ENV"
    fi
    exit 0
  fi

  if [[ "$(reclaim_stale_slots)" -gt 0 ]]; then
    continue # a slot just freed up -- retry now instead of sleeping
  fi

  if [[ "$waited" -ge "$MAX_WAIT_SECONDS" ]]; then
    echo "ERROR: all $CI_LOCK_SLOTS staging box lock slot(s) still busy after ${MAX_WAIT_SECONDS}s -- giving up" >&2
    echo "Last error: $last_err" >&2
    exit 1
  fi

  echo "All $CI_LOCK_SLOTS staging box lock slot(s) busy; waiting ${POLL_SECONDS}s (${waited}s/${MAX_WAIT_SECONDS}s so far)..."
  sleep "$POLL_SECONDS"
  waited=$((waited + POLL_SECONDS))
done
