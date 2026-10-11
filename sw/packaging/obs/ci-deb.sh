#!/usr/bin/env bash
# SPDX-FileCopyrightText: The IPDBG authors
# SPDX-License-Identifier: MPL-2.0
#
# Builds the Debian packages from the debian.* files in a Debian or Ubuntu
# container, like OBS would (debian.X becomes debian/X), installs them and
# checks that they work. Run as root from the top of the repository, e.g.
#
#   podman run --rm -v "$PWD":/src -w /src debian:trixie sw/packaging/obs/ci-deb.sh out
#
# The packages go to OUTDIR (default out).

set -euo pipefail

OUT=${1:-out}
HERE=sw/packaging/obs
VERSION=$(cat sw/VERSION)

# the version in all files that OBS uses
grep -q "^Version: $VERSION-" "$HERE/ipdbg.dsc"
grep -q "^DEBTRANSFORM-TAR: ipdbg-$VERSION.tar.gz" "$HERE/ipdbg.dsc"
head -1 "$HERE/debian.changelog" | grep -q "^ipdbg ($VERSION-"
grep -q "v$VERSION.tar.gz" "$HERE/_service"

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends build-essential devscripts equivs

work=$(mktemp -d)
src=$work/ipdbg-$VERSION
mkdir -p "$src/debian"
tar -c --exclude=./.git --exclude="./$OUT" . | tar -x -C "$src"
for f in "$HERE"/debian.*; do
    cp "$f" "$src/debian/${f##*/debian.}"
done
chmod +x "$src/debian/rules"

(cd "$work" && mk-build-deps -i -r -t "apt-get -y --no-install-recommends" "$src/debian/control")
(cd "$src" && dpkg-buildpackage -b -us -uc)

mkdir -p "$OUT"
cp "$work"/*.deb "$OUT/"
ls -l "$OUT"
apt-get install -y "$(realpath "$OUT")"/*.deb

# the installed packages work
"$HERE/ci-check.sh"
