#!/bin/bash
# update-drupal-cache.sh
#
# Refreshes the drupal-core seed cache used by the ddev-drupal-core Coder template.
# Run this script on the Coder host server as the user who owns the seed directory.
#
# The seed cache is a pre-built drupal-core project containing:
#   - repos/drupal/        Drupal core git clone
#   - vendor/              Composer packages
#   - .tarballs/db.sql.gz  Installed demo_umami database snapshot
#
# New workspaces copy from this cache (rsync + git fetch + ddev import-db)
# instead of running a full composer create + site install, saving ~8-12 minutes.
#
# Usage:
#   ./update-drupal-cache.sh [--seed-dir PATH]
#
# Options:
#   --seed-dir PATH   Absolute path to the seed directory.
#                     Default: /home/coder/cache/drupal-core-seed
#                     Override this if the cache lives under a different user's home,
#                     e.g.: --seed-dir /home/rfay/cache/drupal-core-seed
#                     The Coder template's cache_path variable must be set to the same path.
#
# Note: when run via the systemd timer, the seed directory is taken from the default
# or from the ExecStart line in drupal-cache-updater.service — edit that file to pass
# --seed-dir if your seed directory differs from the default.

set -euo pipefail

SEED_DIR="/home/coder/cache/drupal-core-seed"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --seed-dir)
      SEED_DIR="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [ ! -d "$SEED_DIR" ]; then
  echo "Error: Seed directory not found: $SEED_DIR" >&2
  echo "Run the initial setup first. See docs/admin/server-setup.md." >&2
  exit 1
fi

if [ ! -f "$SEED_DIR/composer.json" ]; then
  echo "Error: composer.json not found in $SEED_DIR — seed not initialized." >&2
  echo "Run the initial setup first. See docs/admin/server-setup.md." >&2
  exit 1
fi

echo "=== Updating drupal-core seed cache ==="
echo "Seed directory: $SEED_DIR"
echo "Started: $(date)"
echo ""

cd "$SEED_DIR"

# Ensure DDEV project is running
if ! ddev describe 2>/dev/null | grep -q "OK"; then
  echo "Starting DDEV seed project..."
  ddev start
fi

# Update composer dependencies (also updates repos/drupal git checkout via path repo)
echo "Running composer update..."
ddev composer update --with-all-dependencies

# Fresh site install so the exported snapshot matches the updated codebase
echo "Running site install..."
ddev drush si -y demo_umami --account-pass=admin

# Export the database snapshot for fast import into new workspaces
echo "Exporting database snapshot..."
mkdir -p .tarballs
ddev export-db --file=.tarballs/db.sql.gz

echo ""
echo "=== Seed cache updated successfully ==="
echo "Completed: $(date)"
echo ""
echo "New workspaces will use this cache automatically."
echo "Cache contents:"
echo "  composer.json/lock: $(stat -c '%y' composer.lock 2>/dev/null | cut -d. -f1 || echo 'unknown')"
echo "  db.sql.gz:          $(stat -c '%y' .tarballs/db.sql.gz 2>/dev/null | cut -d. -f1 || echo 'unknown')"
echo "  Drupal HEAD:        $(git -C repos/drupal log -1 --format='%h %s' 2>/dev/null || echo 'unknown')"
