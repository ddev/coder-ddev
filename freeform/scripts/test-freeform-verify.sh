#!/usr/bin/env bash
# test-freeform-verify.sh — Verify ddev launch and ddev describe URLs for two PHP test projects.
# Run inside a freeform workspace after test-freeform-start.sh.
#
# Usage: bash test-freeform-verify.sh [suffix] [workspace] [owner] [domain]
#   suffix     same suffix used with test-freeform-start.sh (default: current PID)
#   workspace  Coder workspace name (default: $CODER_WORKSPACE_NAME)
#   owner      Coder workspace owner (default: $CODER_WORKSPACE_OWNER_NAME)
#   domain     Coder proxy domain, e.g. staging-coder.ddev.com
#              (default: derived from $VSCODE_PROXY_URI or $CODER_AGENT_URL)

set -euo pipefail

SUFFIX="${1:-$$}"
WORKSPACE="${2:-${CODER_WORKSPACE_NAME:-}}"
OWNER="${3:-${CODER_WORKSPACE_OWNER_NAME:-}}"
DOMAIN="${4:-}"

if [ -z "${DOMAIN}" ]; then
  if [ -n "${VSCODE_PROXY_URI:-}" ]; then
    DOMAIN=$(echo "${VSCODE_PROXY_URI}" | sed -E 's|https?://[^.]+\.(.+?)(/.*)?$|\1|')
  elif [ -n "${CODER_AGENT_URL:-}" ]; then
    DOMAIN=$(echo "${CODER_AGENT_URL}" | sed -E 's|https?://(.+?)(/.*)?$|\1|')
  fi
fi

if [ -z "${WORKSPACE}" ] || [ -z "${OWNER}" ] || [ -z "${DOMAIN}" ]; then
  echo "Error: cannot determine workspace/owner/domain." >&2
  echo "  Set CODER_WORKSPACE_NAME, CODER_WORKSPACE_OWNER_NAME, and VSCODE_PROXY_URI/CODER_AGENT_URL," >&2
  echo "  or pass them as positional arguments." >&2
  exit 1
fi

# The coder_app slug is the workspace name, so all projects in this workspace
# share the same Coder subdomain URL (workspace--workspace--owner.domain).
EXPECTED_URL="https://${WORKSPACE}--${WORKSPACE}--${OWNER}.${DOMAIN}"

for N in 1 2; do
  PROJ="ci-site${N}-${SUFFIX}"

  echo "--- ${PROJ}: ddev launch ---"
  cd "/tmp/${PROJ}"
  LAUNCH=$(ddev launch 2>&1)
  echo "${LAUNCH}"
  echo "${LAUNCH}" | grep -qF "${EXPECTED_URL}" || {
    echo "ERROR: expected ${EXPECTED_URL} not found in ddev launch output" >&2
    exit 1
  }
  echo "  OK: ddev launch shows correct URL"

  echo "--- ${PROJ}: ddev describe ---"
  DESCRIBE=$(ddev describe 2>&1)
  echo "${DESCRIBE}"
  echo "${DESCRIBE}" | grep -qiE "running|OK" || {
    echo "ERROR: ddev describe did not show running status" >&2
    exit 1
  }
  echo "  OK: ddev describe shows project running"
done
