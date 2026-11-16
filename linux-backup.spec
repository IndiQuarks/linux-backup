Name:           linux-backup
Version:        1.0.0
Release:        1%{?dist}
Summary:        Scheduled, logged and verified backups of /etc and /home with on/off and schedule control
License:        MIT
BuildArch:      noarch
Source0:        %{name}-%{version}.tar.gz
Requires:       bash
Requires:       tar
Requires:       gzip
Requires:       findutils
Requires:       coreutils
Requires:       cronie
Requires:       logrotate

%description
linux-backup archives the configured directories (default /etc and /home) with
tar into date-stamped, compressed files in /backup, logs every step, verifies
each archive, and removes archives older than the retention period (default 7).

The linux-backup command turns scheduled backups on or off on demand and changes
the cron schedule without editing any file by hand.

%prep
%setup -q

%build
# nothing to build

%install
install -d %{buildroot}/usr/libexec/%{name}
install -m 0750 backup.sh %{buildroot}/usr/libexec/%{name}/backup.sh
install -d %{buildroot}/usr/sbin
install -m 0755 linux-backup %{buildroot}/usr/sbin/linux-backup
install -d %{buildroot}/etc/logrotate.d
install -m 0644 linux-backup.conf %{buildroot}/etc/linux-backup.conf
install -m 0644 linux-backup.logrotate %{buildroot}/etc/logrotate.d/linux-backup
install -d %{buildroot}/usr/share/man/man8
install -m 0644 linux-backup.8 %{buildroot}/usr/share/man/man8/linux-backup.8
install -d %{buildroot}/etc/cron.d
touch %{buildroot}/etc/cron.d/linux-backup
install -d %{buildroot}/backup

%post
# build the cron entry from the config (generated, not shipped, so enable/disable survives upgrades)
/usr/sbin/linux-backup apply >/dev/null 2>&1 || :
if [ "$1" -eq 1 ]; then
    systemctl enable --now crond.service >/dev/null 2>&1 || :
fi

%postun
# on removal, make sure no cron entry is left behind
if [ "$1" -eq 0 ]; then
    rm -f /etc/cron.d/linux-backup
fi

%files
%license LICENSE
%doc README.md
%dir /usr/libexec/%{name}
%attr(0750,root,root) /usr/libexec/%{name}/backup.sh
%attr(0755,root,root) /usr/sbin/linux-backup
%config(noreplace) /etc/linux-backup.conf
%config(noreplace) /etc/logrotate.d/linux-backup
%ghost %attr(0644,root,root) /etc/cron.d/linux-backup
%dir %attr(0700,root,root) /backup
/usr/share/man/man8/linux-backup.8*

%changelog
* Wed Nov 11 2026 linux-backup authors <root@localhost> - 1.0.0-1
- Initial package: enable/disable, schedule change, status, run, list
