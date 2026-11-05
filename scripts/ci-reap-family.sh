#!/usr/bin/env bash
# Delete predecessor CI workspaces in the same name "family" before a test job
# creates its own workspace.
#
# Why this exists:
#   cancel-in-progress cancels the GitHub run on a new push to a PR, but the
#   workspace that the cancelled run created keeps running on staging (the
#   cancelled job's `coder delete` step never reaches the server). The
#   replacement run is the natural place to clean up its predecessor: it knows
#   its own family and can delete any older sibling before creating its own.
#
#   Workspace names are <family>-<run_number>-<run_attempt> (e.g.
#   gc-pathauto-d11-pr212-152-1). The family is the stable part shared across
#   runs of the same matrix cell ON THE SAME REF. Passing the family prefix here
#   deletes every ci-bot workspace that starts with it EXCEPT the one this run
#   is about to create.
#
#   The family MUST include a ref tag (pr<N> for pull requests, main for
#   push/schedule/dispatch on main, x<run_number> elsewhere). Runs on different
#   refs are in different concurrency groups and legitimately overlap; without
#   the ref tag, a PR run's reap would delete main's in-flight workspace (this
#   happened on main run 407, deleted by PR run 408). Callers derive the family
#   from WORKSPACE_NAME as "${WORKSPACE_NAME%-*-*}-" so the two cannot drift.
#
# Usage:
#   ci-reap-family.sh <family-prefix> [keep-name]
#     <family-prefix>  e.g. "gc-pathauto-d11-"  (trailing dash recommended)
#     [keep-name]      workspace name to NOT delete (this run's own); optional
#
# Environment:
#   CI_OWNER   Coder username that owns CI workspaces (default: ci-bot)
#
# Always exits 0 — predecessor cleanup is best-effort and must never fail a run.

set -uo pipefail

FAMILY="${1:?usage: ci-reap-family.sh <family-prefix> [keep-name]}"
KEEP="${2:-}"
CI_OWNER="${CI_OWNER:-ci-bot}"

if ! workspaces_json=$(coder list --all --output json 2>/dev/null); then
  echo "WARN: 'coder list' failed; skipping predecessor reap" >&2
  exit 0
fi

mapfile -t victims < <(echo "$workspaces_json" |
  jq -r --arg owner "$CI_OWNER" --arg fam "$FAMILY" --arg keep "$KEEP" \
    '.[] | select(.owner_name==$owner) | .name
       | select(startswith($fam)) | select(. != $keep)')

if [[ ${#victims[@]} -eq 0 ]]; then
  echo "No predecessor workspaces for family '$FAMILY'"
  exit 0
fi

for name in "${victims[@]}"; do
  echo "Reaping predecessor: $name"
  coder delete "$name" --yes || echo "  WARN: delete failed for $name" >&2
done

exit 0
