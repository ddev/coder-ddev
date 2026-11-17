#!/usr/bin/env bash
# Restore the latest Coder database backup into a scratch database and count
# its users, to show the backup can be restored. Leaves the live database alone.
# Run as root with the same environment as coder-backup:
#   set -a; source /etc/coder-backup.env; set +a; coder-restore-test
set -euo pipefail

: "${BACKUP_TARGET:?BACKUP_TARGET must be set}"
: "${PASSPHRASE:?PASSPHRASE must be set}"
export PASSPHRASE
SCRATCH_DB=coder_restore_test

work=$(mktemp -d)
cleanup() {
  rm -rf "$work"
  runuser -u postgres -- dropdb --if-exists "$SCRATCH_DB"
}
trap cleanup EXIT

duplicity collection-status "$BACKUP_TARGET" | grep -E 'Last full backup date|Chain end time|Number of contained backup sets'
duplicity restore --path-to-restore var/backups/coder/coder.dump "$BACKUP_TARGET" "$work/coder.dump"
chmod 644 "$work/coder.dump"
chmod 755 "$work"

runuser -u postgres -- dropdb --if-exists "$SCRATCH_DB"
runuser -u postgres -- createdb "$SCRATCH_DB"
runuser -u postgres -- pg_restore --no-owner --dbname "$SCRATCH_DB" "$work/coder.dump"

users=$(runuser -u postgres -- psql -tA -d "$SCRATCH_DB" -c "select count(*) from users where deleted = false")
templates=$(runuser -u postgres -- psql -tA -d "$SCRATCH_DB" -c "select count(*) from templates where deleted = false")
echo "Restored dump: $users users, $templates templates"
