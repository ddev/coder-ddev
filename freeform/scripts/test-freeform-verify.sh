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

for N in 1 2; do
  PROJ="ci-site${N}-${SUFFIX}"
  # Each project's coder_app slug matches the DDEV project name.
  WEB_URL="https://${PROJ}--${WORKSPACE}--${OWNER}.${DOMAIN}"
  MAILPIT_URL="https://mailpit--${WORKSPACE}--${OWNER}.${DOMAIN}"

  echo "--- ${PROJ}: ddev launch ---"
  cd "/tmp/${PROJ}"
  LAUNCH=$(ddev launch 2>&1)
  echo "${LAUNCH}"
  echo "${LAUNCH}" | grep -qF "${WEB_URL}" || {
    echo "ERROR: expected ${WEB_URL} not found in ddev launch output" >&2
    exit 1
  }
  echo "  OK: ddev launch shows correct Web URL"
  echo "${LAUNCH}" | grep -qF "${MAILPIT_URL}" || {
    echo "ERROR: expected ${MAILPIT_URL} not found in ddev launch output" >&2
    exit 1
  }
  echo "  OK: ddev launch shows correct Mailpit URL"

  # docker-compose.coder-describe.yaml is written by the post-start hook (coder-routes)
  # during ddev start, so ddev describe picks it up immediately — no restart needed.
  echo "--- ${PROJ}: ddev describe ---"
  DESCRIBE=$(ddev describe 2>&1)
  echo "${DESCRIBE}"
  echo "${DESCRIBE}" | grep -qiE "running|OK" || {
    echo "ERROR: ddev describe did not show running status" >&2
    exit 1
  }
  echo "  OK: ddev describe shows project running"
  echo "${DESCRIBE}" | grep -qF "${WEB_URL}" || {
    echo "ERROR: Web URL ${WEB_URL} not found in ddev describe output" >&2
    exit 1
  }
  echo "  OK: ddev describe shows Web URL"
  echo "${DESCRIBE}" | grep -qF "${MAILPIT_URL}" || {
    echo "ERROR: Mailpit URL ${MAILPIT_URL} not found in ddev describe output" >&2
    exit 1
  }
  echo "  OK: ddev describe shows Mailpit URL"
done
