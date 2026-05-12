#!/usr/bin/env bash
# scripts/shared/lib.sh — shared prelude for template startup scripts.
#
# Source this from each per-template startup.sh:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   . "${SCRIPT_DIR}/../../shared/lib.sh"
#
# Required env vars: none.
# Optional env vars:
#   LIB_LOG_PREFIX  - prefix for log lines (default: $(basename "$0"))
#
# Exit codes:
#   die() exits 1 by default; die <code> <msg> uses <code>.
#
# Idempotency: sourcing twice is a no-op.

# Guard against double-sourcing.
if [ -n "${__CODER_DDEV_LIB_SOURCED:-}" ]; then
  return 0 2>/dev/null || exit 0
fi
__CODER_DDEV_LIB_SOURCED=1

set -euo pipefail

: "${LIB_LOG_PREFIX:=$(basename "${0:-startup.sh}")}"

log()  { printf '[%s] %s\n'       "${LIB_LOG_PREFIX}" "$*"; }
warn() { printf '[%s] WARN: %s\n' "${LIB_LOG_PREFIX}" "$*" >&2; }
die() {
  local code=1
  if [[ "${1:-}" =~ ^[0-9]+$ ]]; then code="$1"; shift; fi
  printf '[%s] FATAL: %s\n' "${LIB_LOG_PREFIX}" "$*" >&2
  exit "${code}"
}

trap 'die "line ${LINENO}: command failed: ${BASH_COMMAND}"' ERR
