#!/usr/bin/env bash
# Check that every Coder workspace-creation deep-link parameter used in the docs
# (`param.<name>` in docs/*.html, docs/*.js and docs/content/**/*.md) names a
# coder_parameter that actually exists in one of the templates or shared modules.
#
# Why: these deep links are not exercised by terraform test, so renaming or
# removing a parameter silently breaks them (see AGENTS.md, "Coder Parameter
# Gotchas"). This catches renames and removals; it does not check values or
# which template a link targets.
set -euo pipefail
cd "$(dirname "$0")/.."

defined=$(
  awk '
    /^data "coder_parameter"/ { inblock = 1; next }
    inblock && /^[[:space:]]*name[[:space:]]*=/ {
      match($0, /"[^"]+"/); print substr($0, RSTART + 1, RLENGTH - 2); inblock = 0
    }
    /^}/ { inblock = 0 }
  ' drupal-core/template.tf drupal-contrib/template.tf freeform/template.tf modules/*/main.tf | sort -u
)

used=$(grep -rhoE 'param\.[a-z0-9_]+' docs/*.html docs/*.js docs/content 2>/dev/null | sed 's/^param\.//' | sort -u)

missing=$(comm -23 <(echo "$used") <(echo "$defined"))
if [ -n "$missing" ]; then
  echo "Docs use deep-link parameters that no template defines:"
  for p in $missing; do
    echo "  param.$p:"
    grep -rnE "param\.$p\b" docs/*.html docs/*.js docs/content | sed 's/^/    /'
  done
  exit 1
fi
echo "All $(echo "$used" | grep -c .) deep-link parameters in the docs exist in the templates."
