#!/usr/bin/env bash
# Back up Coder's PostgreSQL database and the host configuration to S3,
# encrypted with duplicity. Runs nightly from coder-backup.timer as root.
#
# Without these, a lost system drive means recreating every user, template
# and workspace record by hand, and rebuilding the host config from the docs.
# Workspace home directories in /coder-workspaces are not included.
#
# Environment (from /etc/coder-backup.env):
#   BACKUP_TARGET          duplicity URL, e.g. s3://bucket-name/coder.ddev.com
#   PASSPHRASE             duplicity encryption passphrase
#   AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_DEFAULT_REGION
#   KEEP                   how long to keep backups (default: 90D)
#   FULL_EVERY             interval between full backups (default: 30D)
set -euo pipefail

: "${BACKUP_TARGET:?BACKUP_TARGET must be set}"
: "${PASSPHRASE:?PASSPHRASE must be set}"
export PASSPHRASE
KEEP=${KEEP:-90D}
FULL_EVERY=${FULL_EVERY:-30D}

DUMP_DIR=/var/backups/coder
STAMP=/var/lib/coder-backup/last-success
install -d -m 700 "$DUMP_DIR"
# Readable by Icinga's check_file_age, which runs as nagios.
install -d -m 755 "$(dirname "$STAMP")"

runuser -u postgres -- pg_dump -Fc coder > "$DUMP_DIR/coder.dump.tmp"
mv "$DUMP_DIR/coder.dump.tmp" "$DUMP_DIR/coder.dump"

# Paths that do not exist on this host are skipped by duplicity.
duplicity backup --full-if-older-than "$FULL_EVERY" \
  --include "$DUMP_DIR" \
  --include /etc/coder.d \
  --include /etc/letsencrypt \
  --include /etc/systemd/system \
  --include /etc/sudoers.d \
  --include /etc/docker/daemon.json \
  --include /etc/containerd/config.toml \
  --include /etc/fstab \
  --include /opt/registry/config.yml \
  --include /etc/workspace-lifecycle-cleanup.env \
  --include /var/lib/workspace-lifecycle-cleanup \
  --include /etc/coder-discord-relay.env \
  --include /etc/icinga2 \
  --include /var/lib/icinga2/certs \
  --include /root/coder-pg-password \
  --exclude '**' \
  / "$BACKUP_TARGET"

duplicity remove-older-than "$KEEP" --force "$BACKUP_TARGET"
duplicity cleanup --force "$BACKUP_TARGET"

date +%s > "$STAMP"
