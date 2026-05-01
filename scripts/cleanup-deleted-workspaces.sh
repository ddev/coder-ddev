#!/usr/bin/env bash
# Remove host directories and Docker volumes left behind by deleted Coder workspaces.
#
# New workspaces clean up automatically on deletion via the null_resource destroy
# provisioner in each template. This script handles directories that were orphaned
# before that provisioner existed, or in any case where the provisioner didn't run.
#
# By default runs in dry-run mode (prints what would be deleted).
# Pass --force to actually delete.
#
# Requires: coder CLI (authenticated as admin), docker (in docker group), sudo access
#
# Usage:
#   ./scripts/cleanup-deleted-workspaces.sh                          # dry run
#   ./scripts/cleanup-deleted-workspaces.sh --force                  # delete orphaned data
#   WORKSPACES_DIR=/custom/path ./scripts/cleanup-deleted-workspaces.sh  # override base dir

set -euo pipefail

WORKSPACES_DIR="${WORKSPACES_DIR:-/coder-workspaces}"
FORCE=false

for arg in "$@"; do
  case "$arg" in
    --force) FORCE=true ;;
    --help|-h)
      sed -n '2,10p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

if [[ "$FORCE" == false ]]; then
  echo "DRY RUN — pass --force to actually delete"
  echo
fi

# Build a set of active workspace directory names: "<owner>-<workspace>"
if ! active_json=$(coder list --all --output json 2>/dev/null); then
  echo "ERROR: 'coder list --all --output json' failed. Is the coder CLI authenticated?" >&2
  exit 1
fi

declare -A active_dirs
while IFS= read -r entry; do
  active_dirs["$entry"]=1
done < <(echo "$active_json" | jq -r '.[] | "\(.owner_name)-\(.name)"')

if [[ ${#active_dirs[@]} -eq 0 ]]; then
  echo "WARNING: No active workspaces found. Refusing to delete anything to avoid wiping data if coder CLI is misconfigured." >&2
  exit 1
fi

echo "Active workspaces: ${!active_dirs[*]}"
echo

# --- Host directories ---
orphan_dirs=()
if [[ -d "$WORKSPACES_DIR" ]]; then
  while IFS= read -r dir; do
    base=$(basename "$dir")
    if [[ -z "${active_dirs[$base]+_}" ]]; then
      orphan_dirs+=("$dir")
    fi
  done < <(find "$WORKSPACES_DIR" -mindepth 1 -maxdepth 1 -type d | sort)
fi

if [[ ${#orphan_dirs[@]} -eq 0 ]]; then
  echo "No orphaned host directories found in $WORKSPACES_DIR"
else
  echo "Orphaned host directories:"
  for dir in "${orphan_dirs[@]}"; do
    size=$(du -sh "$dir" 2>/dev/null | cut -f1 || echo "?")
    echo "  $dir  ($size)"
    if [[ "$FORCE" == true ]]; then
      sudo -u '#1000' /usr/local/bin/coder-delete-workspace-dir "$dir"
      echo "  -> deleted"
    fi
  done
fi

echo

# --- Docker volumes ---
orphan_volumes=()
while IFS= read -r vol; do
  # Volume names look like: coder-<owner>-<workspace>-dind-cache
  if [[ "$vol" =~ ^coder-(.+)-dind-cache$ ]]; then
    owner_workspace="${BASH_REMATCH[1]}"
    if [[ -z "${active_dirs[$owner_workspace]+_}" ]]; then
      orphan_volumes+=("$vol")
    fi
  fi
done < <(docker volume ls --format '{{.Name}}' | grep '^coder-' | sort)

if [[ ${#orphan_volumes[@]} -eq 0 ]]; then
  echo "No orphaned Docker volumes found"
else
  echo "Orphaned Docker volumes:"
  for vol in "${orphan_volumes[@]}"; do
    size=$(docker system df -v 2>/dev/null | awk -v v="$vol" '$1==v {print $3}' || echo "?")
    echo "  $vol  ($size)"
    if [[ "$FORCE" == true ]]; then
      docker volume rm "$vol"
      echo "  -> deleted"
    fi
  done
fi

echo
if [[ "$FORCE" == false && ( ${#orphan_dirs[@]} -gt 0 || ${#orphan_volumes[@]} -gt 0 ) ]]; then
  echo "Re-run with --force to delete the items listed above."
fi
