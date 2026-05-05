#!/usr/bin/env bash
# test-freeform-start.sh — Create and start two trivial PHP projects for freeform routing tests.
# Run inside a freeform workspace (requires ddev and Coder agent environment).
#
# Usage: bash test-freeform-start.sh [suffix]
#   suffix  string appended to project names (default: current PID)
#           In CI: pass github.run_id. Manually: any unique string.
#
# Creates: ci-site1-<suffix> and ci-site2-<suffix> in /tmp/

set -euo pipefail

SUFFIX="${1:-$$}"

for N in 1 2; do
  PROJ="ci-site${N}-${SUFFIX}"
  TESTDIR="/tmp/${PROJ}"
  echo "--- Creating project ${PROJ} ---"
  mkdir -p "${TESTDIR}/web"
  cd "${TESTDIR}"
  ddev config --project-type=php --docroot=web --project-name="${PROJ}"
  ddev coder-setup
  ddev start -y
  echo "--- ${PROJ} started ---"
done
