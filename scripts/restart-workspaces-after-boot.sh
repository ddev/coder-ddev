#!/usr/bin/env bash
# Restart every running Coder workspace once, after the host boots.
#
# After a host reboot Docker restarts each workspace container itself
# (restart = "unless-stopped"), but Sysbox does not redo the container's
# user-namespace ID mapping: files from the image are owned by nobody (65534)
# inside, sudo refuses to run, and the startup script fails (start_error).
# A plain `docker restart` without a reboot does not cause this.
# `coder restart` destroys and recreates the container, which fixes it.
#
# Dry run by default; pass --force to restart.
#
# Environment:
#   CODER_URL            Coder deployment
#   CODER_SESSION_TOKEN  Token with the owner role (the workspace-janitor token
#                        in /etc/workspace-lifecycle-cleanup.env works)
#   WAIT_SECONDS         How long to wait for Coder to come up (default: 600)
set -euo pipefail

FORCE=false
if [ "${1:-}" = "--force" ]; then
  FORCE=true
fi
: "${CODER_URL:?CODER_URL must be set}"
WAIT_SECONDS=${WAIT_SECONDS:-600}

deadline=$((SECONDS + WAIT_SECONDS))
until curl -fsS -o /dev/null "$CODER_URL/healthz"; do
  if [ "$SECONDS" -ge "$deadline" ]; then
    echo "Coder at $CODER_URL is not healthy after ${WAIT_SECONDS}s" >&2
    exit 1
  fi
  sleep 5
done

mapfile -t workspaces < <(coder list -a -o json |
  jq -r '.[] | select(.latest_build.status == "running") | "\(.owner_name)/\(.name)"')

echo "Running workspaces: ${#workspaces[@]}"
failed=0
for ws in "${workspaces[@]}"; do
  if [ "$FORCE" != true ]; then
    echo "would restart $ws"
    continue
  fi
  echo "restarting $ws"
  if ! out=$(coder restart "$ws" --yes 2>&1); then
    echo "restart of $ws failed: $out"
    failed=$((failed + 1))
  fi
done

if [ "$FORCE" != true ]; then
  echo "Dry run. Pass --force to restart."
fi
[ "$failed" -eq 0 ]
