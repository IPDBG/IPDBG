#!/usr/bin/env bash
# SPDX-FileCopyrightText: The IPDBG authors
# SPDX-License-Identifier: MPL-2.0
#
# Builds the Arch packages from the PKGBUILD in an Arch Linux container,
# installs them and checks them with ci-check.sh. Run as root from
# the top of the repository, e.g.
#
#   podman run --rm -v "$PWD":/src -w /src archlinux sw/packaging/obs/ci-arch.sh out
#
# The packages and the .SRCINFO go to OUTDIR (default out).

set -euo pipefail

OUT=$(realpath -m "${1:-out}")
HERE=sw/packaging/obs
VERSION=$(cat sw/VERSION)

pkgver=$(source "$HERE/PKGBUILD" && echo "$pkgver")
[ "$pkgver" = "$VERSION" ] || { echo "PKGBUILD has version $pkgver, sw/VERSION $VERSION"; exit 1; }

pacman -Syu --noconfirm --needed base-devel sudo
# makepkg does not run as root
id builder >/dev/null 2>&1 || useradd -m builder
echo 'builder ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/builder

# the source archive as GitHub creates it for the tag: top directory IPDBG-VERSION
work=/home/builder/ipdbg
rm -rf "$work"
mkdir -p "$work"
cp "$HERE/PKGBUILD" "$work/"
tar -czf "$work/ipdbg-$VERSION.tar.gz" --exclude=./.git --exclude="./$(basename "$OUT")" \
    --transform "s,^\.,IPDBG-$VERSION," .
chown -R builder: "$work"

(cd "$work" && sudo -u builder makepkg --syncdeps --noconfirm --skipinteg)

mkdir -p "$OUT"
(cd "$work" && sudo -u builder makepkg --printsrcinfo) > "$OUT/.SRCINFO"
find "$work" -name '*.pkg.tar.zst' ! -name '*-debug-*' -exec cp {} "$OUT/" \;
ls -l "$OUT"
pacman -U --noconfirm "$OUT"/*.pkg.tar.zst

sw/packaging/obs/ci-check.sh
