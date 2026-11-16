#!/bin/bash
# Build the RPM from this directory. Output: ./rpmbuild/RPMS/noarch/
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
name=linux-backup; ver=1.0.0
top="$here/rpmbuild"
rm -rf "$top"; mkdir -p "$top"/{SOURCES,SPECS,BUILD,RPMS,SRPMS}
stage="$(mktemp -d)"; mkdir "$stage/$name-$ver"
cp "$here"/{backup.sh,linux-backup,linux-backup.conf,linux-backup.logrotate,linux-backup.8,LICENSE,README.md} "$stage/$name-$ver/"
tar -C "$stage" -czf "$top/SOURCES/$name-$ver.tar.gz" "$name-$ver"
rm -rf "$stage"
cp "$here/$name.spec" "$top/SPECS/"
rpmbuild --define "_topdir $top" -ba "$top/SPECS/$name.spec"
ls -l "$top"/RPMS/noarch/*.rpm
