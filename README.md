# linux-backup

Scheduled, logged and verified backups of `/etc` and `/home` for RHEL-family systems.

## Install

    sudo dnf install ./linux-backup-1.0.0-1.noarch.rpm

## Use

    sudo linux-backup status                    # state, schedule, archives, last result
    sudo linux-backup disable                   # stop scheduled backups (archives kept)
    sudo linux-backup enable                    # start them again
    sudo linux-backup schedule "30 3 * * *"     # change when it runs (cron syntax)
    sudo linux-backup schedule --daily 03:30    # once a day at a time
    sudo linux-backup run                       # back up right now
    sudo linux-backup list                      # list archives

Default schedule is 02:00 daily. Settings live in `/etc/linux-backup.conf`
(sources, backup directory, retention days, log file). After editing it by hand,
run `sudo linux-backup apply`.

Archives are named `backup_<host>_<date>_<time>.tar.gz`, stored in `/backup`
(mode 700, archives mode 600) and logged to `/var/log/backup.log`.

## Limits

Cron only runs while the machine is on. A machine that is off at the scheduled
time skips that backup; schedule a time the machine is normally up, or run
`linux-backup run` manually.

## Build

    ./build-rpm.sh
