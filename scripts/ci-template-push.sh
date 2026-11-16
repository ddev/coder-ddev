#!/usr/bin/env bash
# Run `coder templates push` with the given arguments, retrying when Coder
# rate-limits the upload.
#
# Coder allows each user 12 file uploads per minute, and every CI push is one
# upload as ci-bot. Rebasing several PRs at once starts more pushes than that
# in the same minute, and the rejected ones would fail their jobs. A rejected
# upload creates nothing on the server, so retrying with the same --name is safe.
#
# Usage: ci-template-push.sh <template> [coder templates push flags...]
#
# Environment:
#   PUSH_ATTEMPTS   Total attempts before failing (default: 5)
#   PUSH_WAIT       Base wait between attempts, in seconds (default: 60);
#                   0-30s of random jitter is added so jobs don't retry together

set -uo pipefail

PUSH_ATTEMPTS="${PUSH_ATTEMPTS:-5}"
PUSH_WAIT="${PUSH_WAIT:-60}"

out=$(mktemp)
trap 'rm -f "$out"' EXIT

for attempt in $(seq 1 "$PUSH_ATTEMPTS"); do
  coder templates push "$@" 2>&1 | tee "$out"
  status=${PIPESTATUS[0]}
  if [ "$status" -eq 0 ]; then
    exit 0
  fi
  if ! grep -q "You've been rate limited" "$out"; then
    exit "$status"
  fi
  if [ "$attempt" -lt "$PUSH_ATTEMPTS" ]; then
    wait=$((PUSH_WAIT + RANDOM % 31))
    echo "Rate limited (attempt $attempt/$PUSH_ATTEMPTS); retrying in ${wait}s"
    sleep "$wait"
  fi
done

echo "::error::coder templates push still rate limited after $PUSH_ATTEMPTS attempts"
exit 1
