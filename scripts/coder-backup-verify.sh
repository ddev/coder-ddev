#!/usr/bin/env bash
# Download the latest Coder backup from S3 and load its database dump into a
# scratch PostgreSQL, on any machine with Docker. Use it to practice recovery
# without the server: it needs only the backup secrets, not the server itself.
#
# Usage: coder-backup-verify.sh <env-file>
#   The env file sets BACKUP_TARGET, PASSPHRASE, AWS_ACCESS_KEY_ID,
#   AWS_SECRET_ACCESS_KEY and AWS_DEFAULT_REGION, like /etc/coder-backup.env.
#   The restored files contain secrets, so they are deleted on exit.
set -euo pipefail

ENVFILE=${1:?usage: coder-backup-verify.sh <env-file>}
WORK=$(mktemp -d "${TMPDIR:-/tmp}/coder-backup-verify.XXXX")
PG=coder-backup-verify-pg

cleanup() {
  docker rm -f "$PG" >/dev/null 2>&1 || true
  # Files restored in the container are owned by root, so delete them there.
  docker run --rm -v "$WORK:/restore" ubuntu:24.04 rm -rf /restore/files >/dev/null 2>&1 || true
  rmdir "$WORK" 2>/dev/null || true
}
trap cleanup EXIT

echo "== Downloading the latest backup"
docker run --rm --env-file "$ENVFILE" -v "$WORK:/restore" ubuntu:24.04 bash -c '
  set -e
  apt-get update -qq >/dev/null
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq duplicity python3-boto3 >/dev/null 2>&1
  duplicity collection-status "$BACKUP_TARGET" | grep -E "Last full backup date|Chain end time|Number of contained backup sets"
  duplicity restore "$BACKUP_TARGET" /restore/files >/dev/null
  chmod -R a+rX /restore/files
'
for f in var/backups/coder/coder.dump root/coder-pg-password etc/coder.d/coder.env; do
  [ -s "$WORK/files/$f" ] && echo "present  /$f" || echo "MISSING  /$f"
done

echo "== Loading the dump into a scratch PostgreSQL 16"
docker run -d --name "$PG" -e POSTGRES_PASSWORD=verify \
  -v "$WORK/files/var/backups/coder:/dump:ro" postgres:16 >/dev/null
until docker exec "$PG" pg_isready -U postgres -q; do sleep 1; done
sleep 2
docker exec "$PG" createdb -U postgres coder
docker exec "$PG" pg_restore -U postgres --no-owner --dbname coder /dump/coder.dump

q() { docker exec "$PG" psql -U postgres -d coder -tA -F ' ' -c "$1"; }
echo "== Users"
q "select username, login_type, created_at::date from users where not deleted order by created_at"
echo "== Templates and version counts"
q "select name, (select count(*) from template_versions v where v.template_id = t.id) from templates t where not deleted order by name"
echo "== Workspaces"
q "select u.username || '/' || w.name from workspaces w join users u on u.id = w.owner_id where not w.deleted order by 1"
echo "== Newest audit log entry"
q "select max(time) from audit_logs"
