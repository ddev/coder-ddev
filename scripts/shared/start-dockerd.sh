#!/usr/bin/env bash
# scripts/shared/start-dockerd.sh
# Function library: idempotent in-container dockerd bring-up.
# Sourced; defines start_dockerd(). DEFINITION-ONLY — sourcing has no side
# effects. Per-template startup scripts MAY adopt it as a follow-up; current
# callers still run their original inline bash. See AUDIT.md.
#
# Required env vars: none.
# Optional env vars:
#   DOCKER_SOCKET           - default /var/run/docker.sock
#   DOCKERD_TIMEOUT_SECONDS - default 60
#   DOCKERD_LOG             - default /tmp/dockerd.log
#
# Exit codes (when start_dockerd is invoked):
#   0 - docker daemon ready (already running, or started successfully)
#   2 - sysbox/dockerd binary missing
#   3 - dockerd failed to become ready within timeout
#
# Idempotency: yes — returns 0 immediately if the socket is already responsive.

# Guard against double-sourcing. Does NOT source lib.sh; per-template scripts
# are expected to have sourced lib.sh before us.
if [ -n "${__CODER_DDEV_HELPER_START_DOCKERD_SOURCED:-}" ]; then
  return 0 2>/dev/null || exit 0
fi
__CODER_DDEV_HELPER_START_DOCKERD_SOURCED=1

start_dockerd() {
  : "${DOCKER_SOCKET:=/var/run/docker.sock}"
  : "${DOCKERD_TIMEOUT_SECONDS:=60}"
  : "${DOCKERD_LOG:=/tmp/dockerd.log}"

  # Idempotency: if socket is already serving docker, we're done.
  if [ -S "${DOCKER_SOCKET}" ] && docker info >/dev/null 2>&1; then
    return 0
  fi

  if ! command -v dockerd >/dev/null 2>&1; then
    return 2
  fi

  # If dockerd is not already running, start it under sudo and detach.
  # SC2024: the redirect runs in the parent shell — the per-template scripts
  # have always written the log this way; sudo only needs to launch dockerd.
  if ! pgrep -x dockerd >/dev/null 2>&1; then
    # shellcheck disable=SC2024
    sudo dockerd >"${DOCKERD_LOG}" 2>&1 &
  fi

  # Wait for the socket to come up.
  local waited=0
  while [ "${waited}" -lt "${DOCKERD_TIMEOUT_SECONDS}" ]; do
    if [ -S "${DOCKER_SOCKET}" ] && docker info >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
    waited=$((waited + 1))
  done

  return 3
}
