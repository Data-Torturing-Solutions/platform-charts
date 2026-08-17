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
# Heartbeat is optional and built in (not a separate script this image
# would need to carry an app-specific copy of): set META_HEARTBEAT_URL and
# this posts one fail-soft ping to meta-monitor after every run, success or
# failure, matching the job-name/status/exit_code contract every other
# CronJob's heartbeat uses. Unset means this app isn't wired to a monitor.
heartbeat() {
    code="$1"
    [ -n "${META_HEARTBEAT_URL:-}" ] || return 0
    [ "$code" = "0" ] && status=ok || status=exit-code
    curl -fsS --max-time 20 \
        -H 'content-type: application/json' \
        -d "{\"job\":\"${APP_NAME}-backup\",\"status\":\"$status\",\"attempt\":1,\"metrics\":{\"exit_code\":$code}}" \
        "$META_HEARTBEAT_URL" >/dev/null 2>&1 || true
}

run() {
    : "${DB_PATH:?DB_PATH required}"
    : "${APP_NAME:?APP_NAME required}"
    : "${RCLONE_REMOTE:?RCLONE_REMOTE required}"

    [ -f "$DB_PATH" ] || { echo "no database at $DB_PATH"; return 0; }

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
}

# run() must fail fast internally (a failed sqlite3 .backup should not be
# followed by gzip-ing and uploading garbage) but the script as a whole must
# not exit before the heartbeat fires. A subshell gets both: errexit inside
# it aborts run() on the first failing command without taking the parent
# shell down, so `code` below is always the real exit status.
set -u
( set -e; run )
code=$?
heartbeat "$code"
exit "$code"
