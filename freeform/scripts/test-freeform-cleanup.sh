#!/usr/bin/env bash
# test-freeform-cleanup.sh — Delete PHP test projects created by test-freeform-start.sh.
# Run inside a freeform workspace.
#
# Usage: bash test-freeform-cleanup.sh [suffix]
#   suffix  same suffix used with test-freeform-start.sh (default: current PID)

set -euo pipefail

SUFFIX="${1:-$$}"

for N in 1 2; do
  PROJ="ci-site${N}-${SUFFIX}"
  ddev delete "${PROJ}" -Oy || true
  rm -rf "/tmp/${PROJ}" || true
done
