#!/bin/bash
# Sandbox tests: run with the repo's linux-backup and backup.sh against temp files.
set -uo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/cron" "$T/backup" "$T/src"
echo hello > "$T/src/a.txt"
cat > "$T/conf" <<EOF
ENABLED="yes"
SCHEDULE="0 2 * * *"
SOURCES="$T/src"
BACKUP_DIR="$T/backup"
LOG_FILE="$T/backup.log"
RETENTION_DAYS="7"
EOF
export LINUX_BACKUP_CONF="$T/conf" LINUX_BACKUP_CRON="$T/cron/linux-backup" LINUX_BACKUP_SCRIPT="$here/backup.sh"
LB="$here/linux-backup"
pass=0; fail=0
ok()   { echo "PASS $1"; pass=$((pass+1)); }
bad()  { echo "FAIL $1"; fail=$((fail+1)); }
expect_ok()   { local n=$1; shift; if "$@" >/dev/null 2>&1; then ok "$n"; else bad "$n"; fi; }
expect_fail() { local n=$1; shift; if "$@" >/dev/null 2>&1; then bad "$n"; else ok "$n"; fi; }
cronline() { grep -v '^#' "$T/cron/linux-backup" | grep root || true; }

expect_ok  "apply"            "$LB" apply
[[ $(cronline) == "0 2 * * * root $here/backup.sh" ]] && ok "cron active after apply" || bad "cron active after apply"
expect_ok  "disable"          "$LB" disable
[[ -z $(cronline) ]] && ok "no active cron when disabled" || bad "no active cron when disabled"
grep -q 'ENABLED="no"' "$T/conf" && ok "conf says no" || bad "conf says no"
expect_ok  "enable"           "$LB" enable
[[ -n $(cronline) ]] && ok "cron active after enable" || bad "cron active after enable"
expect_ok  "schedule cron"    "$LB" schedule "30 3 * * *"
[[ $("$LB" schedule) == "30 3 * * *" ]] && ok "schedule persisted" || bad "schedule persisted"
[[ $(cronline) == "30 3 * * * root $here/backup.sh" ]] && ok "cron updated" || bad "cron updated"
expect_ok  "schedule --daily" "$LB" schedule --daily 04:05
[[ $("$LB" schedule) == "5 4 * * *" ]] && ok "daily 04:05" || bad "daily 04:05"
expect_ok  "weekdays range"   "$LB" schedule "0 2 * * 1-5"
expect_ok  "list and step"    "$LB" schedule "0 */6 * * *"
expect_fail "too few fields"  "$LB" schedule "0 2 * *"
expect_fail "minute 60"       "$LB" schedule "60 2 * * *"
expect_fail "hour 24"         "$LB" schedule "0 24 * * *"
expect_fail "letters"         "$LB" schedule "a b c d e"
expect_fail "injection"       "$LB" schedule "0 2 * * * ; rm -rf /"
expect_fail "newline inject"  "$LB" schedule $'0 2 * * *\n* * * * * root evil'
expect_fail "bad daily"       "$LB" schedule --daily 25:00
expect_fail "every minute"    "$LB" schedule "* * * * *"
expect_ok   "every minute forced" "$LB" schedule "* * * * *" --force
expect_ok   "restore"         "$LB" schedule "0 2 * * *"
expect_ok   "disabled keeps schedule" bash -c "'$LB' disable && '$LB' schedule '15 1 * * *'"
[[ -z $(cronline) ]] && ok "still disabled after schedule change" || bad "still disabled after schedule change"
grep -q '^#15 1 \* \* \* root' "$T/cron/linux-backup" && ok "commented entry has new time" || bad "commented entry has new time"
expect_ok   "enable again"    "$LB" enable
expect_ok   "run"             "$LB" run
ls "$T/backup"/backup_*.tar.gz >/dev/null 2>&1 && ok "archive created" || bad "archive created"
[[ $(stat -c %a "$T/backup"/backup_*.tar.gz) == 600 ]] && ok "archive mode 600" || bad "archive mode 600"
tar -tzf "$T/backup"/backup_*.tar.gz | grep -q a.txt && ok "archive has file" || bad "archive has file"
# retention
touch -d '10 days ago' "$T/backup/backup_old_2000-01-01_000000.tar.gz"
touch -d '6 days ago'  "$T/backup/backup_keep_2000-01-02_000000.tar.gz"
"$LB" run >/dev/null 2>&1
[[ ! -e $T/backup/backup_old_2000-01-01_000000.tar.gz ]] && ok "old archive deleted" || bad "old archive deleted"
[[ -e $T/backup/backup_keep_2000-01-02_000000.tar.gz ]] && ok "recent archive kept" || bad "recent archive kept"
expect_ok   "status"          "$LB" status
out="$("$LB" status 2>&1)"; grep -q 'Scheduled backups: *enabled' <<< "$out" && ok "status enabled" || bad "status enabled"
expect_ok   "list"            "$LB" list
expect_fail "unknown command" "$LB" bogus
# failure paths
sed -i "s|^SOURCES=.*|SOURCES=\"$T/missing\"|" "$T/conf"
expect_fail "missing source"  "$LB" run
sed -i "s|^SOURCES=.*|SOURCES=\"$T/src\"|; s|^RETENTION_DAYS=.*|RETENTION_DAYS=\"abc\"|" "$T/conf"
expect_fail "bad retention"   "$LB" run
echo; echo "passed=$pass failed=$fail"
exit $((fail>0))
