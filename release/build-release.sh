#!/bin/bash
# Usage: ./build-release.sh <baseurl> <public-key-file>
# Example: ./build-release.sh https://YOURUSER.github.io/linux-backup-repo/ ~/RPM-GPG-KEY-linux-backup
set -euo pipefail
[ $# -eq 2 ] || { echo "usage: $0 <baseurl> <public-key-file>"; exit 1; }
baseurl="${1%/}/"; key="$2"
[ -r "$key" ] || { echo "cannot read $key"; exit 1; }
grep -q 'BEGIN PGP PUBLIC KEY BLOCK' "$key" || { echo "$key is not a public key"; exit 1; }
here="$(cd "$(dirname "$0")" && pwd)"; top="$here/rpmbuild"
rm -rf "$top"; mkdir -p "$top"/{SOURCES,SPECS,BUILD,RPMS,SRPMS}
cp "$key" "$top/SOURCES/RPM-GPG-KEY-linux-backup"
cat > "$top/SOURCES/linux-backup.repo" <<REPO
[linux-backup]
name=Linux Backup
baseurl=${baseurl}
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-linux-backup
REPO
cp "$here/linux-backup-release.spec" "$top/SPECS/"
rpmbuild --define "_topdir $top" --define "baseurl ${baseurl}" -bb "$top/SPECS/linux-backup-release.spec" >/dev/null
ls "$top"/RPMS/noarch/*.rpm
