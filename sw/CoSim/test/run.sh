#!/usr/bin/env bash
# SPDX-FileCopyrightText: The IPDBG authors
# SPDX-License-Identifier: MPL-2.0
#
# Starts CoSim and OpenOCD and runs the checks in this directory, one
# Python script per check. With CoSim and OpenOCD running, each check can
# also be run on its own: python3 la_rle.py
#
# Needs CoSim built (make in sw/CoSim), OpenOCD, sigrok-cli with the
# ipdbg-la and ipdbg-awg drivers, and the Python modules BusAccess and
# WaveformGenerator, from the source tree (make python in sw) or installed
# (pip install ipdbg).
#
#   sw/CoSim/test/run.sh
#   OPENOCD=/path/to/openocd SIGROK_CLI=/path/to/sigrok-cli sw/CoSim/test/run.sh
#
# Exit status 0 if all checks passed.

set -u
cd "$(dirname "$0")"

CHECKS=(la_trigger la_rle awg ioprobe busaccess)

OPENOCD=${OPENOCD:-openocd}
export SIGROK_CLI=${SIGROK_CLI:-sigrok-cli}
SW=$(cd ../.. && pwd)
export PYTHONPATH=$SW/BusAccess/python:$SW/WaveformGenerator/python${PYTHONPATH:+:$PYTHONPATH}
export LD_LIBRARY_PATH=$SW/BusAccess/bin/Release:$SW/WaveformGenerator/bin/Release${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
export PYTHONDONTWRITEBYTECODE=1

export COSIM_WORK=$(mktemp -d)
WORK=$COSIM_WORK
pids=()
keep_work=false
cleanup() {
    local i
    # in reverse order: OpenOCD before CoSim
    for ((i = ${#pids[@]} - 1; i >= 0; i--)); do
        kill "${pids[i]}" 2>/dev/null
        wait "${pids[i]}" 2>/dev/null
    done
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

# listening PORT: a TCP socket listens on PORT (state 0A in /proc/net/tcp)
listening() {
    grep -qs "^ *[0-9]*: [0-9A-F]*:$(printf %04X "$1") [0-9A-F]*:[0-9A-F]* 0A " /proc/net/tcp /proc/net/tcp6
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

../CoSim > "$WORK/cosim.log" 2>&1 &
pids+=($!)
wait_for 10 listening 3421 || fail_start "CoSim does not listen on port 3421"

(cd .. && exec "$OPENOCD" -f ipdbg_JtagSim.cfg) > "$WORK/openocd.log" 2>&1 &
pids+=($!)
wait_for 60 grep -qs "Listening on port 4246" "$WORK/openocd.log" || fail_start "OpenOCD does not serve the cores"

failed=()
for name in "${CHECKS[@]}"; do
    if python3 "$name.py" > "$WORK/$name.out" 2>&1; then
        echo "PASS  $name"
    else
        echo "FAIL  $name"
        sed 's/^/      /' "$WORK/$name.out" | head -30
        failed+=("$name")
    fi
done

if [ ${#failed[@]} -ne 0 ]; then
    keep_work=true
    echo "${#failed[@]} check(s) failed: ${failed[*]}"
    exit 1
fi
echo "all checks passed"
