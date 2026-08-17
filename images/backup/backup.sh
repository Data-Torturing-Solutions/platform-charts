#!/bin/sh
# Generic SQLite-to-R2 backup, shared by every app's backup CronJob.
#
# Adapted from vertical-pasty/deploy/cornwall_hair-backup.sh with one
# deliberate behavior change: that script treated the offsite push as
# secondary and failed soft, because a local 14-day retention was the real
# safety net. There is no local retention here by design (see
# platform-charts' cost/storage notes) — R2 IS the backup now, not a
# belt-and-braces extra, so a failed push fails the job loudly (non-zero
# exit, visible in `kubectl get cronjob`) instead of silently producing no
# usable backup. The one local copy kept below is a same-night rollback
# convenience, not retention.
set -eu

: "${DB_PATH:?DB_PATH required}"
: "${APP_NAME:?APP_NAME required}"
: "${RCLONE_REMOTE:?RCLONE_REMOTE required}"

[ -f "$DB_PATH" ] || { echo "no database at $DB_PATH"; exit 0; }

STAMP=$(date -u +%Y%m%dT%H%M%SZ)
OUT="/tmp/${APP_NAME}-${STAMP}.sqlite"

sqlite3 "$DB_PATH" ".backup '$OUT'"
gzip -f "$OUT"

PREFIX=droplets-daily
[ "$(date -u +%d)" = "01" ] && PREFIX=droplets-monthly

rclone copyto "$OUT.gz" \
    "$RCLONE_REMOTE/$PREFIX/$APP_NAME/$APP_NAME-$STAMP.sqlite.gz" \
    --s3-no-check-bucket --retries 3 --low-level-retries 5
echo "offsite copy: $PREFIX/$APP_NAME/$APP_NAME-$STAMP.sqlite.gz"

# Same-night local rollback copy, alongside the live DB on the same PVC.
LOCAL_DIR="$(dirname "$DB_PATH")/backups"
mkdir -p "$LOCAL_DIR"
cp "$OUT.gz" "$LOCAL_DIR/${APP_NAME}-latest.sqlite.gz"
echo "local rollback copy: $LOCAL_DIR/${APP_NAME}-latest.sqlite.gz"
