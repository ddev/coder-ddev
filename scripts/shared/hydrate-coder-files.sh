#!/usr/bin/env bash
# scripts/shared/hydrate-coder-files.sh
# Function library: hydrate the persistent /home/coder volume from the
# image-embedded /home/coder-files/ skeleton. Sourced; defines
# hydrate_coder_files(). DEFINITION-ONLY — sourcing has no side effects.
# Per-template startup scripts MAY adopt this as a follow-up; current callers
# still run their original inline bash. See AUDIT.md.
#
# Background: the /home/coder volume mount masks image content on first boot,
# so files baked into the image at /home/coder-files/ must be copied across.
#
# Required env vars: none.
# Optional env vars:
#   CODER_FILES_DIR - source dir (default /home/coder-files)
#   CODER_HOME      - destination home (default $HOME, then /home/coder)
#
# Exit codes (when invoked):
#   0 - hydration succeeded or source dir absent (no-op)
#   1 - copy failure
#
# Idempotency: yes — only copies files when the destination is missing.

if [ -n "${__CODER_DDEV_HELPER_HYDRATE_CODER_FILES_SOURCED:-}" ]; then
  return 0 2>/dev/null || exit 0
fi
__CODER_DDEV_HELPER_HYDRATE_CODER_FILES_SOURCED=1

hydrate_coder_files() {
  : "${CODER_FILES_DIR:=/home/coder-files}"
  : "${CODER_HOME:=${HOME:-/home/coder}}"

  if [ ! -d "${CODER_FILES_DIR}" ]; then
    return 0
  fi

  # WELCOME.txt
  if [ ! -f "${CODER_HOME}/WELCOME.txt" ] && [ -f "${CODER_FILES_DIR}/WELCOME.txt" ]; then
    cp "${CODER_FILES_DIR}/WELCOME.txt" "${CODER_HOME}/WELCOME.txt" || return 1
  fi

  # VS Code settings
  if [ -d "${CODER_FILES_DIR}/.vscode" ]; then
    mkdir -p "${CODER_HOME}/.vscode"
    if [ -f "${CODER_FILES_DIR}/.vscode/settings.json" ] && [ ! -f "${CODER_HOME}/.vscode/settings.json" ]; then
      cp "${CODER_FILES_DIR}/.vscode/settings.json" "${CODER_HOME}/.vscode/settings.json" || return 1
    fi
  fi

  # gitconfig + gitignore_global — only seed when absent (do not clobber user state)
  if [ ! -f "${CODER_HOME}/.gitconfig" ] && [ -f "${CODER_FILES_DIR}/.gitconfig" ]; then
    cp "${CODER_FILES_DIR}/.gitconfig" "${CODER_HOME}/.gitconfig" || return 1
  fi
  if [ ! -f "${CODER_HOME}/.gitignore_global" ] && [ -f "${CODER_FILES_DIR}/.gitignore_global" ]; then
    cp "${CODER_FILES_DIR}/.gitignore_global" "${CODER_HOME}/.gitignore_global" || return 1
  fi

  return 0
}
