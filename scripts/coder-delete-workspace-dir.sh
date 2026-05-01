#!/usr/bin/env bash
# Safely delete a single workspace host directory.
# Intended to be called via sudo by the coder service user at workspace deletion time.
# Validates the path strictly before deleting to prevent path traversal attacks.
#
# Usage: sudo /usr/local/bin/coder-delete-workspace-dir <path>
#   e.g. sudo /usr/local/bin/coder-delete-workspace-dir /coder-workspaces/rfay-myworkspace
#
# Install: sudo install -m 755 scripts/coder-delete-workspace-dir.sh /usr/local/bin/coder-delete-workspace-dir

set -euo pipefail

path="${1:-}"

if [[ -z "$path" ]]; then
  echo "Usage: $0 <workspace-dir>" >&2
  exit 1
fi

# Require exactly /coder-workspaces/<name> where <name> is alphanumeric + hyphens/underscores.
# No slashes, no .., no empty name. This prevents path traversal.
if [[ ! "$path" =~ ^/coder-workspaces/[a-zA-Z0-9][a-zA-Z0-9_-]+$ ]]; then
  echo "Refusing to delete invalid path: $path" >&2
  exit 1
fi

[[ -d "$path" ]] || exit 0

# Files may be owned by a different UID than the process running rm.
# Reset permissions on the directory so rm can remove everything.
chmod -R u+rwX "$path" 2>/dev/null || true

exec rm -rf -- "$path"
