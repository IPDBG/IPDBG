#!/usr/bin/env bash
# SPDX-FileCopyrightText: The IPDBG authors
# SPDX-License-Identifier: MPL-2.0
#
# Builds the Windows ZIP of the host software in an MSYS2 shell (UCRT64):
# IoView and UartBridge with all DLLs they need, the libraries for own
# programs (DLLs, import libraries, headers, pkg-config files), the licenses.
# Locally and in GitHub Actions (.github/workflows/sw.yml).
#
#   sw/packaging/windows/make-zip.sh OUTDIR [SUFFIX]
#
# creates OUTDIR/ipdbg-VERSION[-SUFFIX]-windows-x86_64.zip, VERSION from
# sw/VERSION. Needs the packages listed in .github/workflows/sw.yml.

set -euo pipefail

[ $# -ge 1 ] || { echo "usage: $0 OUTDIR [SUFFIX]" >&2; exit 2; }
HERE=$(cd "$(dirname "$0")" && pwd)
SW=$(cd "$HERE/../.." && pwd)
mkdir -p "$1"
OUT=$(cd "$1" && pwd)
VERSION=$(cat "$SW/VERSION")
NAME=ipdbg-$VERSION${2:+-$2}-windows-x86_64
STAGE=$OUT/stage
ROOT=$STAGE/$NAME
MINGW=${MINGW_PREFIX:?run this in an MSYS2 UCRT64 shell}
OBJDUMP=${OBJDUMP:-objdump}
SYSDIR=$(cygpath -u "${SYSTEMROOT:-C:\\Windows}")/System32

rm -rf "$STAGE" "$OUT/$NAME.zip"

# --- build and install into the staging directory ---------------------------
# prefix /NAME: the pkg-config files are relocatable, pkgconf finds the
# directories relative to the .pc file
make -C "$SW" -j"$(nproc)" install PREFIX="/$NAME" DESTDIR="$STAGE"

# --- DLLs --------------------------------------------------------------------
# Copies the DLLs that the programs and DLLs in bin import from MINGW/bin,
# recursively. A DLL found neither there nor in Windows is an error.
find_dll() { find "$1" -maxdepth 1 -iname "$2" -print -quit 2>/dev/null; }
imports() { "$OBJDUMP" -p "$1" | sed -n 's/^[[:space:]]*DLL Name: //p' | tr -d '\r'; }

BIN=$ROOT/bin
shopt -s nullglob
queue=("$BIN"/*.exe "$BIN"/*.dll)
copied=()
declare -A seen
missing=0
while [ ${#queue[@]} -gt 0 ]; do
    file=${queue[0]}
    queue=("${queue[@]:1}")
    deps=$(imports "$file")     # fails the script if objdump fails
    for dll in $deps; do
        key=${dll,,}
        [ -z "${seen[$key]:-}" ] || continue
        seen[$key]=1
        case $key in api-ms-win-*|ext-ms-*) continue ;; esac   # API sets of Windows
        if [ -n "$(find_dll "$BIN" "$dll")" ]; then
            continue                                           # our own DLLs
        elif src=$(find_dll "$MINGW/bin" "$dll") && [ -n "$src" ]; then
            cp "$src" "$BIN/"
            copied+=("$src")
            queue+=("$BIN/$(basename "$src")")
        elif [ -z "$(find_dll "$SYSDIR" "$dll")" ]; then
            echo "missing DLL: $dll (needed by $(basename "$file"))" >&2
            missing=1
        fi
    done
done
[ $missing -eq 0 ] || exit 1

# --- licenses ----------------------------------------------------------------
# the license files of the MSYS2 packages the copied DLLs come from, and a
# list with package versions and where to get the sources
mkdir -p "$ROOT/LICENSES" "$ROOT/licenses"
cp "$SW/../LICENSES/MPL-2.0.txt" "$ROOT/LICENSES/"
{
    echo "Third-party DLLs in bin, from the MSYS2 (https://www.msys2.org) UCRT64"
    echo "packages below. License texts: licenses/<package>."
    echo "Sources: https://packages.msys2.org/packages/<package>"
    echo
    printf '%-36s %-48s %-20s %s\n' DLL Package Version License
} > "$ROOT/THIRD-PARTY.txt"
for src in "${copied[@]}"; do
    pkg=$(pacman -Qqo "$src")
    ver=$(pacman -Q "$pkg" | cut -d' ' -f2)
    lic=$(pacman -Qi "$pkg" | sed -n 's/^Licenses *: //p')
    printf '%-36s %-48s %-20s %s\n' "$(basename "$src")" "$pkg" "$ver" "$lic" >> "$ROOT/THIRD-PARTY.txt"
    # the license files the package installs, e.g. MINGW/share/licenses/zlib/LICENSE
    if [ ! -d "$ROOT/licenses/$pkg" ]; then
        mkdir -p "$ROOT/licenses/$pkg"
        pacman -Qlq "$pkg" | grep "^$MINGW/share/licenses/.*[^/]$" | while read -r f; do
            rel=${f#"$MINGW/share/licenses/"}
            mkdir -p "$ROOT/licenses/$pkg/$(dirname "$rel")"
            cp "$f" "$ROOT/licenses/$pkg/$rel"
        done || true
    fi
done

# --- README and ZIP ----------------------------------------------------------
sed "s/@VERSION@/$VERSION/" "$HERE/README.txt" > "$ROOT/README.txt"
(cd "$STAGE" && zip -q -r -9 "$OUT/$NAME.zip" "$NAME")
echo "$OUT/$NAME.zip"
