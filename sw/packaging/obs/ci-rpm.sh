#!/usr/bin/env bash
# SPDX-FileCopyrightText: The IPDBG authors
# SPDX-License-Identifier: MPL-2.0
#
# Builds the RPM packages from ipdbg.spec in a Fedora or openSUSE container,
# like OBS would, installs them and checks that they work. Run as root from
# the top of the repository, e.g.
#
#   podman run --rm -v "$PWD":/src -w /src fedora:latest sw/packaging/obs/ci-rpm.sh out
#
# The packages go to OUTDIR (default out).

set -euo pipefail

OUT=${1:-out}
SPEC=sw/packaging/obs/ipdbg.spec
VERSION=$(cat sw/VERSION)

if command -v dnf >/dev/null; then
    install() { dnf -y install "$@"; }
else
    # --force-resolution: the openSUSE Tumbleweed image has busybox-gawk,
    # which conflicts with the gawk that rpm-build needs; replace it
    install() { zypper -n --no-gpg-checks install --force-resolution "$@"; }
fi

install rpm-build tar gzip

spec_version=$(rpmspec -q --srpm --qf '%{version}\n' "$SPEC")
[ "$spec_version" = "$VERSION" ] || { echo "ipdbg.spec has version $spec_version, sw/VERSION $VERSION"; exit 1; }

# build dependencies as listed in the spec, e.g. "wxWidgets-devel >= 3"
mapfile -t deps < <(rpmspec -q --buildrequires "$SPEC")
install "${deps[@]}"

# the source archive as GitHub creates it for the tag: top directory IPDBG-VERSION
top=$(rpm --eval %_topdir)
mkdir -p "$top/SOURCES"
tar -czf "$top/SOURCES/ipdbg-$VERSION.tar.gz" --exclude=./.git --exclude="./$OUT" \
    --transform "s,^\.,IPDBG-$VERSION," .
rpmbuild -ba "$SPEC"

mkdir -p "$OUT"
find "$top/RPMS" -name '*.rpm' ! -name '*-debug*' -exec cp {} "$OUT/" \;
ls -l "$OUT"
install "$OUT"/*.rpm

# the installed packages work
"$(dirname "$0")/ci-check.sh"
