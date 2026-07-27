#!/usr/bin/env bash
# Wait until no other CI workspace exists on the shared staging box before this
# job creates its own workspace.
#
# Why this exists:
#   GitHub Actions' `concurrency:` keyword only keeps one job running plus one
#   pending per group -- any additional job that tries to join while one is
#   already pending gets CANCELLED outright, not queued behind it. A single PR
#   push (or push to main) triggers up to five box-provisioning jobs across
#   integration-test.yml, drupal-integration-test.yml, and
#   drupal-contrib-integration-test.yml at nearly the same instant, so sharing
#   one concurrency group silently dropped most of them instead of running
#   them in turn. Polling the box's actual ci-bot workspace count avoids that:
#   every contender waits and none are cancelled.
#
# Usage:
#   ci-wait-for-staging-box.sh
#
# Environment:
#   CI_OWNER          Coder username that owns CI workspaces (default: ci-bot)
#   MAX_WAIT_SECONDS  Give up and fail after this long (default: 2700 = 45m)
#   POLL_SECONDS      Delay between checks (default: 30)

set -uo pipefail

CI_OWNER="${CI_OWNER:-ci-bot}"
MAX_WAIT_SECONDS="${MAX_WAIT_SECONDS:-2700}"
POLL_SECONDS="${POLL_SECONDS:-30}"

# Jitter so jobs that all started in the same instant don't all sample the
# workspace count (and all see "clear") at the exact same moment.
sleep "$((RANDOM % 15))"

waited=0
while true; do
  if ! workspaces_json=$(coder list --all --output json 2>/dev/null); then
    echo "WARN: 'coder list' failed; proceeding without the box-busy check" >&2
    exit 0
  fi

  count=$(echo "$workspaces_json" | jq -r --arg owner "$CI_OWNER" \
    '[.[] | select(.owner_name==$owner)] | length')

  if [[ "$count" -eq 0 ]]; then
    echo "Staging box is free (0 ci-bot workspaces) -- proceeding"
    exit 0
  fi

  if [[ "$waited" -ge "$MAX_WAIT_SECONDS" ]]; then
    echo "ERROR: staging box still busy ($count ci-bot workspace(s)) after ${MAX_WAIT_SECONDS}s -- giving up" >&2
    exit 1
  fi

  echo "Staging box busy ($count ci-bot workspace(s)); waiting ${POLL_SECONDS}s (${waited}s/${MAX_WAIT_SECONDS}s so far)..."
  sleep "$POLL_SECONDS"
  waited=$((waited + POLL_SECONDS))
done
