#!/usr/bin/env bash
# SPDX-FileCopyrightText: The IPDBG authors
# SPDX-License-Identifier: MPL-2.0
#
# Checks the installed packages (ci-rpm.sh, ci-deb.sh): the programs start or
# find all libraries, the Python and Octave modules load from the system
# directories.

set -euo pipefail

ipdbg-uartbridge --version
if ldd "$(command -v ipdbg-ioview)" | grep "not found"; then
    echo "ipdbg-ioview: missing libraries"
    exit 1
fi
test -f /usr/share/applications/ipdbg-ioview.desktop
test -f /usr/share/icons/hicolor/scalable/apps/ipdbg-ioview.svg
pkg-config --cflags --libs ipdbg-busaccess ipdbg-waveformgenerator

cd /
python3 -c "import BusAccess, WaveformGenerator; print(BusAccess.IpdbgBusAccess(), WaveformGenerator.IpdbgWaveformGenerator())"
octave-cli --norc --eval "BusAccess; WaveformGenerator; disp(class(BusAccess.IpdbgBusAccess())); disp(class(WaveformGenerator.IpdbgWaveformGenerator()))"
echo "packages ok"
