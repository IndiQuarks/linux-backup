# Built by build-release.sh, which passes baseurl and the key file
%{!?baseurl: %global baseurl https://example.github.io/linux-backup-repo/}

Name:           linux-backup-release
Version:        1
Release:        1%{?dist}
Summary:        Package repository configuration for linux-backup
License:        MIT
BuildArch:      noarch
Source0:        linux-backup.repo
Source1:        RPM-GPG-KEY-linux-backup

%description
Installs the dnf repository definition and the GPG public key for the
linux-backup repository. After installing this package, "dnf install
linux-backup" and "dnf upgrade" work like any other repository.

%prep
# nothing to unpack

%build
# nothing to build

%install
install -d %{buildroot}/etc/yum.repos.d
install -m 0644 %{SOURCE0} %{buildroot}/etc/yum.repos.d/linux-backup.repo
install -d %{buildroot}/etc/pki/rpm-gpg
install -m 0644 %{SOURCE1} %{buildroot}/etc/pki/rpm-gpg/RPM-GPG-KEY-linux-backup

%files
%config(noreplace) /etc/yum.repos.d/linux-backup.repo
/etc/pki/rpm-gpg/RPM-GPG-KEY-linux-backup

%changelog
* Wed Nov 11 2026 linux-backup authors <root@localhost> - 1-1
- Initial release package
