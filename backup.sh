#!/bin/bash
# linux-backup: archive the configured directories with tar, log every step,
# verify the archive, and remove archives older than RETENTION_DAYS.
# Installed to /usr/libexec/linux-backup/backup.sh (root:root, mode 750).
# Settings are read from /etc/linux-backup.conf.

set -uo pipefail
umask 077   # archives and the log are created private (mode 600) from the first byte

CONF="${LINUX_BACKUP_CONF:-/etc/linux-backup.conf}"

# conf_get KEY DEFAULT: read KEY="value" from the config file without executing it
conf_get() {
    local line val
    line="$(grep -E "^[[:space:]]*$1=" "$CONF" 2>/dev/null | tail -n 1)" || true
    if [[ -z $line ]]; then printf '%s' "$2"; return; fi
    val="${line#*=}"
    val="${val#"${val%%[![:space:]]*}"}"
    val="${val%"${val##*[![:space:]]}"}"
    val="${val#\"}"; val="${val%\"}"
    printf '%s' "$val"
}

BACKUP_DIR="$(conf_get BACKUP_DIR /backup)"
LOG_FILE="$(conf_get LOG_FILE /var/log/backup.log)"
RETENTION_DAYS="$(conf_get RETENTION_DAYS 7)"
read -r -a SOURCES <<< "$(conf_get SOURCES '/etc /home')"
TIMESTAMP="$(date +%F_%H%M%S)"
ARCHIVE="${BACKUP_DIR}/backup_$(hostname -s)_${TIMESTAMP}.tar.gz"

log() {
    # usage: log LEVEL "message"
    echo "$(date '+%F %T') [$1] $2" >> "$LOG_FILE"
    echo "$(date '+%F %T') [$1] $2"
}

# --- Pre-flight checks ---
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root." >&2
    exit 1
fi

if [[ ! $RETENTION_DAYS =~ ^[0-9]+$ ]]; then
    log ERROR "RETENTION_DAYS must be a whole number, got '$RETENTION_DAYS'"
    exit 1
fi

if [[ ${#SOURCES[@]} -eq 0 ]]; then
    log ERROR "SOURCES is empty in $CONF"
    exit 1
fi

if [[ ! -d "$BACKUP_DIR" ]]; then
    log ERROR "Backup directory $BACKUP_DIR does not exist"
    exit 1
fi

for src in "${SOURCES[@]}"; do
    if [[ ! -d "$src" ]]; then
        log ERROR "Source directory $src not found"
        exit 1
    fi
done

# --- Create archive ---
log INFO "Backup started: ${SOURCES[*]} -> $ARCHIVE"

tar -czf "$ARCHIVE" "${SOURCES[@]}" 2>>"$LOG_FILE"
rc=$?

# tar exit codes: 0 = ok, 1 = some files changed while reading (non-fatal), 2+ = fatal
if [[ $rc -ge 2 ]]; then
    log ERROR "tar failed with exit code $rc"
    rm -f "$ARCHIVE"
    exit "$rc"
elif [[ $rc -eq 1 ]]; then
    log WARN "tar finished with warnings (files changed during backup)"
fi

# --- Verify archive is readable ---
if ! tar -tzf "$ARCHIVE" >/dev/null 2>&1; then
    log ERROR "Archive verification failed: $ARCHIVE"
    exit 1
fi

chmod 600 "$ARCHIVE"
log INFO "Backup completed: $(du -h "$ARCHIVE" | cut -f1) $ARCHIVE"

# --- Retention: delete backups older than N days ---
while IFS= read -r old; do
    log INFO "Retention: removing $old"
done < <(find "$BACKUP_DIR" -maxdepth 1 -type f -name 'backup_*.tar.gz' -mtime +"$RETENTION_DAYS")

find "$BACKUP_DIR" -maxdepth 1 -type f -name 'backup_*.tar.gz' -mtime +"$RETENTION_DAYS" -delete

log INFO "Backup run finished"
exit 0
