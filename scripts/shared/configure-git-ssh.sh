#!/usr/bin/env bash
# scripts/shared/configure-git-ssh.sh
# Function library: wire Coder's GitSSH wrapper into GIT_SSH_COMMAND. Sourced;
# defines configure_git_ssh(). DEFINITION-ONLY — sourcing has no side effects.
# Per-template startup scripts MAY adopt this as a follow-up; current callers
# still run their original inline bash. See AUDIT.md.
#
# Required env vars: none.
# Optional env vars:
#   CODER_GITSSH - path to Coder agent's gitssh wrapper directory
#                  (default: detected from `coder agent` install layout)
#
# Exit codes (when invoked):
#   0 - GIT_SSH_COMMAND exported (or already set)
#   1 - no gitssh wrapper located
#
# Idempotency: yes — leaves GIT_SSH_COMMAND alone if already set.

if [ -n "${__CODER_DDEV_HELPER_CONFIGURE_GIT_SSH_SOURCED:-}" ]; then
  return 0 2>/dev/null || exit 0
fi
__CODER_DDEV_HELPER_CONFIGURE_GIT_SSH_SOURCED=1

configure_git_ssh() {
  if [ -n "${GIT_SSH_COMMAND:-}" ]; then
    return 0
  fi

  local gitssh_dir="${CODER_GITSSH:-}"
  if [ -z "${gitssh_dir}" ]; then
    # Common Coder agent install locations.
    for candidate in \
      "${HOME}/.config/coder" \
      "/tmp/coder" \
      "/var/tmp/coder"; do
      if [ -x "${candidate}/gitssh" ]; then
        gitssh_dir="${candidate}"
        break
      fi
    done
  fi

  if [ -n "${gitssh_dir}" ] && [ -x "${gitssh_dir}/gitssh" ]; then
    export GIT_SSH_COMMAND="${gitssh_dir}/gitssh"
    return 0
  fi

  return 1
}
