#!/usr/bin/env bash
# scripts/shared/install-ddev-config.sh
# Function library: install the DDEV global_config.yaml + host commands from
# the image skeleton into the user's ~/.ddev/ directory. Sourced; defines
# install_ddev_config(). DEFINITION-ONLY — sourcing has no side effects.
# Per-template startup scripts MAY adopt this as a follow-up; current callers
# still run their original inline bash. See AUDIT.md.
#
# Required env vars: none.
# Optional env vars:
#   CODER_FILES_DIR - source dir (default /home/coder-files)
#   CODER_HOME      - destination home (default $HOME, then /home/coder)
#
# Exit codes (when invoked):
#   0 - config installed or source absent
#   1 - copy failure
#
# Idempotency: yes — global_config.yaml is force-replaced (it is the canonical
# config); host commands are force-copied to pick up any updates.

if [ -n "${__CODER_DDEV_HELPER_INSTALL_DDEV_CONFIG_SOURCED:-}" ]; then
  return 0 2>/dev/null || exit 0
fi
__CODER_DDEV_HELPER_INSTALL_DDEV_CONFIG_SOURCED=1

install_ddev_config() {
  : "${CODER_FILES_DIR:=/home/coder-files}"
  : "${CODER_HOME:=${HOME:-/home/coder}}"

  if [ ! -d "${CODER_FILES_DIR}/.ddev" ]; then
    return 0
  fi

  mkdir -p "${CODER_HOME}/.ddev"

  if [ -f "${CODER_FILES_DIR}/.ddev/global_config.yaml" ]; then
    cp -f "${CODER_FILES_DIR}/.ddev/global_config.yaml" \
      "${CODER_HOME}/.ddev/global_config.yaml" || return 1
  fi

  if [ -d "${CODER_FILES_DIR}/.ddev/commands/host" ]; then
    mkdir -p "${CODER_HOME}/.ddev/commands/host"
    cp -f "${CODER_FILES_DIR}"/.ddev/commands/host/* \
      "${CODER_HOME}/.ddev/commands/host/" 2>/dev/null || true
  fi

  return 0
}
