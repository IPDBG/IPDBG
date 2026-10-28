#!/usr/bin/env bash
# SPDX-FileCopyrightText: The IPDBG authors
# SPDX-License-Identifier: MPL-2.0
#
# Starts CoSim and OpenOCD and checks the four cores of the demo design with
# the host tools:
#   la-wfg     the Waveform Generator plays a ramp, sigrok-cli captures it
#              with the Logic Analyzer (trigger on 0), compared with
#              la_ramp.golden
#   ioprobe    the IoProbe inputs show the outputs twice
#   busaccess  the register behind the Wishbone master, with sel
#
# Needs CoSim built (make), OpenOCD, sigrok-cli and the Python modules
# BusAccess and WaveformGenerator, from the source tree (make python) or
# installed (pip install ipdbg).
#
#   sw/CoSim/test.sh
#   OPENOCD=/path/to/openocd SIGROK_CLI=/path/to/sigrok-cli sw/CoSim/test.sh
#
# Exit status 0 if all checks passed.

set -u
cd "$(dirname "$0")"

OPENOCD=${OPENOCD:-openocd}
SIGROK_CLI=${SIGROK_CLI:-sigrok-cli}
SW=$(cd .. && pwd)
export PYTHONPATH=$SW/BusAccess/python:$SW/WaveformGenerator/python${PYTHONPATH:+:$PYTHONPATH}
export LD_LIBRARY_PATH=$SW/BusAccess/bin/Release:$SW/WaveformGenerator/bin/Release${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}

WORK=$(mktemp -d)
pids=()
keep_work=false
cleanup() {
    [ ${#pids[@]} -eq 0 ] || kill "${pids[@]}" 2>/dev/null
    wait 2>/dev/null
    if $keep_work; then
        echo "logs and captures: $WORK"
    else
        rm -rf "$WORK"
    fi
}
trap cleanup EXIT

# wait_for SECONDS COMMAND...: runs COMMAND every second until it succeeds
wait_for() {
    local i
    for ((i = 0; i < $1; i++)); do
        "${@:2}" && return 0
        sleep 1
    done
    return 1
}

fail_start() {
    keep_work=true
    echo "FAIL  start: $1"
    for log in "$WORK"/*.log; do
        echo "      --- $(basename "$log")"
        sed 's/^/      /' "$log" | tail -20
    done
    exit 1
}

./CoSim > "$WORK/cosim.log" 2>&1 &
pids+=($!)
wait_for 10 sh -c 'ss -ltn | grep -q ":3421 "' || fail_start "CoSim does not listen on port 3421"

"$OPENOCD" -f ipdbg_JtagSim.cfg > "$WORK/openocd.log" 2>&1 &
pids+=($!)
wait_for 60 grep -qs "Listening on port 4245" "$WORK/openocd.log" || fail_start "OpenOCD does not serve the cores"

failed=()

# check NAME COMMAND...: runs COMMAND, shows its output if it fails
check() {
    local name=$1
    shift
    if "$@" > "$WORK/$name.out" 2>&1; then
        echo "PASS  $name"
    else
        echo "FAIL  $name"
        sed 's/^/      /' "$WORK/$name.out" | head -30
        failed+=("$name")
    fi
}

la_wfg() {
    python3 - <<'EOF' || return 1
import WaveformGenerator
wfg = WaveformGenerator.IpdbgWaveformGenerator()
wfg.open("127.0.0.1", "4243")
wfg.setTimeout(60000)
wfg.write(list(range(256)))
wfg.start()
wfg.close()
EOF
    "$SIGROK_CLI" --driver=ipdbg-la:conn=tcp-raw/127.0.0.1/4242 --samples 512 \
        --triggers CH0=0,CH1=0,CH2=0,CH3=0,CH4=0,CH5=0,CH6=0,CH7=0 \
        -O binary -o "$WORK/la.bin" || return 1
    [ -s "$WORK/la.bin" ] || { echo "sigrok-cli wrote no samples"; return 1; }
    od -An -v -tx2 -w2 "$WORK/la.bin" > "$WORK/la.txt"
    echo "$(wc -l < "$WORK/la.txt") samples"
    diff la_ramp.golden "$WORK/la.txt"
}

ioprobe() {
    python3 - <<'EOF'
import BusAccess
p = BusAccess.IpdbgBusAccess()
p.open("127.0.0.1", "4244")
p.setTimeout(60000)
assert p.getCoreType() == BusAccess.CORE_TYPE_IOPROBE, f"core type {p.getCoreType()}"
for v in (0x000, 0x1ff, 0x155, 0x0aa):
    p.write(0, v)
    r = p.read(0)
    assert r == (v << 9) | v, f"outputs {v:#05x}: inputs {r:#07x}, expected {(v << 9) | v:#07x}"
p.write(0, 0)
p.close()
EOF
}

busaccess() {
    python3 - <<'EOF'
import BusAccess
b = BusAccess.IpdbgBusAccess()
b.open("127.0.0.1", "4245")
b.setTimeout(60000)
def expect(address, value):
    r = b.read(address)
    assert r == value, f"read {address:#06x}: {r:#010x}, expected {value:#010x}"
b.setStrobe(0b11)
b.write(0x1234, 0xcafe1234)
expect(0x1234, 0xcafe1234)
b.setStrobe(0b01)
b.write(0x0000, 0xffffffff)
expect(0x0000, 0xcafeffff)
b.setStrobe(0b10)
b.write(0xffff, 0x5555aaee)  # 0x55 and 0xEE are escaped
expect(0xffff, 0x5555ffff)
b.setStrobe(0b11)
b.close()
EOF
}

check la-wfg la_wfg
check ioprobe ioprobe
check busaccess busaccess

if [ ${#failed[@]} -ne 0 ]; then
    keep_work=true
    echo "${#failed[@]} check(s) failed: ${failed[*]}"
    exit 1
fi
echo "all checks passed"
