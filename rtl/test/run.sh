#!/usr/bin/env bash
# SPDX-FileCopyrightText: The IPDBG authors
# SPDX-License-Identifier: CERN-OHL-W-2.0
#
# Runs the GHDL checks of rtl/: elaborates the hub variants and all cores,
# and runs the self-checking testbenches. Locally and in GitHub Actions.
#
#   rtl/test/run.sh            all checks
#   GHDL=/path/to/ghdl rtl/test/run.sh
#
# Exit status 0 if all checks passed.

set -u

GHDL=${GHDL:-ghdl}
RTL=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

FLAGS=(--std=08 -frelaxed)
failed=()

# check NAME COMMAND [ARGS...]: runs COMMAND (a function below) in a fresh
# directory, i.e. with a fresh work library
check() {
    local name=$1
    shift
    local dir="$WORK/$name"
    mkdir -p "$dir"
    if (cd "$dir" && "$@") > "$dir/log" 2>&1; then
        echo "PASS  $name"
    else
        echo "FAIL  $name"
        sed 's/^/      /' "$dir/log" | tail -20
        failed+=("$name")
    fi
}

analyze() { "$GHDL" -a "${FLAGS[@]}" "$@"; }

# elaborate TOP [OPTIONS...] [-- RUN OPTIONS...]: elaborates TOP and runs it
# for 0 ns. Generics (-gNAME=VALUE) are run options: with the GCC and LLVM
# backends of GHDL, -g at elaboration means debug information.
elaborate() {
    local top=$1 opts=()
    shift
    while [ $# -gt 0 ] && [ "$1" != "--" ]; do opts+=("$1"); shift; done
    [ $# -gt 0 ] && shift
    "$GHDL" --elab-run "${FLAGS[@]}" "${opts[@]}" "$top" "$@" --stop-time=0ns
}

# simulate TOP EXPECTED [OPTIONS...]: runs TOP for at most 1 ms, fails on
# assertion failures and if EXPECTED is not reported (e.g. a testbench that
# hangs)
simulate() {
    local top=$1 expected=$2
    shift 2
    "$GHDL" --elab-run "${FLAGS[@]}" "$top" "$@" --assert-level=error --stop-time=1ms | tee sim.log
    [ "${PIPESTATUS[0]}" -eq 0 ] || return 1
    [ -z "$expected" ] || grep -q "$expected" sim.log
}

# Vendor libraries that the TAP files reference. The TAPs used below declare
# their primitives as components, so empty libraries are enough.
vendor_libs() {
    echo "package altera_primitives_components is end package;" > altera.vhd &&
    "$GHDL" -a "${FLAGS[@]}" --work=altera altera.vhd &&
    echo "package apa_stub is end package;" > apa.vhd &&
    "$GHDL" -a "${FLAGS[@]}" --work=apa apa.vhd
}

C=$RTL/common
J=$RTL/JtagHub

# --- the four hub variants, each with JtagCdc -------------------------------

hub() {
    vendor_libs &&
    analyze -Paltera -Papa "$C/ipdbg_interface_pkg.vhd" "$C/dffpc_behav.vhd" "$J/JtagCdc.vhd" "$@" &&
    elaborate JtagHub -Paltera -Papa -- -gFLOW_CONTROL_ENABLE=0000001
}

check hub-JtagHub          hub "$J/IpdbgTap_intel_vjtag.vhd" "$J/JtagHub.vhd"
check hub-JtagHub_4ext     hub "$J/IpdbgTap_generic.vhd" "$J/JtagHub_4ext.vhd"
check hub-JtagHub_efinix   hub "$J/JtagHub_efinix.vhd"
check hub-JtagHub_proasic3 hub "$J/IpdbgTap_proasic3.vhd" "$J/JtagHub_proasic3.vhd"

# --- all cores, bus interfaces and transports --------------------------------

CORES=(
    "$C/ipdbg_interface_pkg.vhd" "$C/dffpc_behav.vhd" "$C/IpdbgEscaping.vhd" "$C/pdpRam.vhd"
    "$C/IpdbgClockDomainCrossing.vhd"
    "$J/JtagCdc.vhd" "$J/IpdbgTap_generic.vhd" "$J/JtagHub_4ext.vhd"
    "$RTL/LogicAnalyser/LogicAnalyserTrigger.vhd" "$RTL/LogicAnalyser/LogicAnalyserMemory.vhd"
    "$RTL/LogicAnalyser/LogicAnalyserRunLengthCoder.vhd" "$RTL/LogicAnalyser/LogicAnalyserController.vhd"
    "$RTL/LogicAnalyser/LogicAnalyserTop.vhd"
    "$RTL/WaveformGenerator/WaveformGeneratorController.vhd"
    "$RTL/WaveformGenerator/WaveformGeneratorMemory.vhd" "$RTL/WaveformGenerator/WaveformGeneratorTop.vhd"
    "$RTL/BusAccess/BusAccessStatemachine.vhd" "$RTL/BusAccess/BusAccessController.vhd"
    "$RTL/BusAccess/WbMaster.vhd" "$RTL/BusAccess/Axi4lMaster.vhd" "$RTL/BusAccess/AhbMaster.vhd"
    "$RTL/BusAccess/AvalonMaster.vhd" "$RTL/BusAccess/ApbMaster.vhd" "$RTL/BusAccess/RiscvDtm.vhd"
    "$RTL/IoProbe/IoProbeTop.vhd"
    "$RTL/Uart/IpdbgUartTx.vhd" "$RTL/Uart/IpdbgUartRx.vhd" "$RTL/Uart/IpdbgUart.vhd"
)
IURT=("$RTL/Iurt/generated/reg_utils.vhd")
for bus in Wb Axi4l Apb3 Apb4 Avalon Obi Passthrough; do
    IURT+=("$RTL/Iurt/generated/IurtRegs${bus}_pkg.vhd" "$RTL/Iurt/generated/IurtRegs${bus}.vhd")
done
IURT+=("$RTL/Iurt/IurtCore.vhd")
for bus in Wb Axi4l Apb3 Apb4 Avalon Obi Ahb; do
    IURT+=("$RTL/Iurt/Iurt${bus}.vhd")
done

cores() {
    analyze "${CORES[@]}" "${IURT[@]}" "$RTL/test/elab_cores.vhd" &&
    simulate elab_cores ""
}
check cores cores

# --- self-checking testbenches ------------------------------------------------

tb_iurt() {
    local bus reset
    analyze "$C/ipdbg_interface_pkg.vhd" "${IURT[@]}" "$RTL/Iurt/test/tb_Iurt.vhd" || return 1
    for bus in wb ahb axi4l apb3 apb4 avalon obi; do
        for reset in true false; do
            simulate tb_Iurt "tb_Iurt: all tests passed" -gBUS_TYPE=$bus -gASYNC_RESET=$reset || return 1
        done
    done
}
check tb_Iurt tb_iurt

tb_hub() {
    local ext
    analyze "$C/ipdbg_interface_pkg.vhd" "$C/dffpc_behav.vhd" "$J/JtagCdc.vhd" \
        "$C/IpdbgClockDomainCrossing.vhd" "$J/test/tb_JtagHub.vhd" || return 1
    for ext in false true; do
        simulate tb_JtagHub "tb_JtagHub: all tests passed" -gTDI_HAS_EXT_REGISTER=$ext || return 1
    done
}
check tb_JtagHub tb_hub

tb_uart() {
    analyze "$C/ipdbg_interface_pkg.vhd" "$C/dffpc_behav.vhd" "$C/IpdbgEscaping.vhd" \
        "$RTL/BusAccess/BusAccessStatemachine.vhd" "$RTL/BusAccess/BusAccessController.vhd" \
        "$RTL/IoProbe/IoProbeTop.vhd" "$RTL/Uart/IpdbgUartTx.vhd" "$RTL/Uart/IpdbgUartRx.vhd" \
        "$RTL/Uart/IpdbgUart.vhd" "$RTL/Uart/test/IpdbgUart_tb.vhd" &&
    simulate IpdbgUart_tb "IpdbgUart_tb: passed"
}
check IpdbgUart_tb tb_uart

# --- protocol testbenches of the cores, with the host model of ipdbg_test_pkg --

TEST_PKG=("$C/ipdbg_interface_pkg.vhd" "$RTL/test/ipdbg_test_pkg.vhd")
# back-pressure: idle clocks before the bytes to the core, clocks until the
# host is ready again for the next byte from the core; LAZY: the host is only
# ready after uplink_valid
FAST=(-gMAX_GAP=0 -gMAX_DELAY=0)
SLOW=(-gMAX_GAP=10 -gMAX_DELAY=25)
LAZY=(-gREADY_AFTER_VALID=true)

tb_escaping() {
    analyze "${TEST_PKG[@]}" "$C/IpdbgEscaping.vhd" "$C/test/tb_IpdbgEscaping.vhd" || return 1
    simulate tb_IpdbgEscaping "all tests passed" -gASYNC_RESET=true &&
    simulate tb_IpdbgEscaping "all tests passed" -gASYNC_RESET=false -gSEED=2 -gMAX_GAP=0 &&
    simulate tb_IpdbgEscaping "all tests passed" -gSEED=3 -gMAX_GAP=10
}
check tb_IpdbgEscaping tb_escaping

tb_cdc() {
    analyze "${TEST_PKG[@]}" "$C/dffpc_behav.vhd" "$C/IpdbgClockDomainCrossing.vhd" \
        "$C/test/tb_IpdbgClockDomainCrossing.vhd" || return 1
    simulate tb_IpdbgClockDomainCrossing "all tests passed" &&
    simulate tb_IpdbgClockDomainCrossing "all tests passed" -gASYNC_RESET=true -gT_FUNC_PS=3000 -gMAX_BUSY=0 \
        -gSEED=2 "${FAST[@]}" &&
    simulate tb_IpdbgClockDomainCrossing "all tests passed" -gT_FUNC_PS=47000 -gSEED=3 "${SLOW[@]}" "${LAZY[@]}"
}
check tb_IpdbgClockDomainCrossing tb_cdc

BUSACCESS=("$C/IpdbgEscaping.vhd" "$RTL/BusAccess/BusAccessStatemachine.vhd" "$RTL/BusAccess/BusAccessController.vhd")

tb_busaccess() {
    analyze "${TEST_PKG[@]}" "${BUSACCESS[@]}" "$RTL/BusAccess/test/tb_BusAccess.vhd" || return 1
    simulate tb_BusAccess "all tests passed" &&
    simulate tb_BusAccess "all tests passed" -gASYNC_RESET=false -gSEED=2 "${FAST[@]}" -gMAX_LATENCY=0 &&
    simulate tb_BusAccess "all tests passed" -gSEED=3 "${SLOW[@]}" -gMAX_LATENCY=40 &&
    simulate tb_BusAccess "all tests passed" -gSEED=6 "${FAST[@]}" "${LAZY[@]}" &&
    simulate tb_BusAccess "all tests passed" -gADDRESS_WIDTH=33 -gR_DATA_WIDTH=13 -gW_DATA_WIDTH=9 \
        -gSTROBE_WIDTH=0 -gMISC_WIDTH=0 -gSEED=4 &&
    simulate tb_BusAccess "all tests passed" -gADDRESS_WIDTH=4 -gR_DATA_WIDTH=5 -gW_DATA_WIDTH=64 \
        -gSTROBE_WIDTH=8 -gMISC_WIDTH=10 -gSEED=5 "${FAST[@]}"
}
check tb_BusAccess tb_busaccess

tb_ioprobe() {
    analyze "${TEST_PKG[@]}" "${BUSACCESS[@]}" "$RTL/IoProbe/IoProbeTop.vhd" "$RTL/IoProbe/test/tb_IoProbe.vhd" || return 1
    simulate tb_IoProbe "all tests passed" &&
    simulate tb_IoProbe "all tests passed" -gASYNC_RESET=false -gINPUT_WIDTH=1 -gOUTPUT_WIDTH=1 -gSEED=2 "${FAST[@]}" &&
    simulate tb_IoProbe "all tests passed" -gINPUT_WIDTH=8 -gOUTPUT_WIDTH=33 -gSEED=3 "${SLOW[@]}" "${LAZY[@]}"
}
check tb_IoProbe tb_ioprobe

tb_wfg() {
    local W=$RTL/WaveformGenerator
    analyze "${TEST_PKG[@]}" "$C/IpdbgEscaping.vhd" "$C/pdpRam.vhd" "$W/WaveformGeneratorController.vhd" \
        "$W/WaveformGeneratorMemory.vhd" "$W/WaveformGeneratorTop.vhd" "$W/test/tb_WaveformGenerator.vhd" || return 1
    simulate tb_WaveformGenerator "all tests passed" &&
    simulate tb_WaveformGenerator "all tests passed" -gDOUBLE_BUFFER=true -gSEED=2 "${FAST[@]}" &&
    simulate tb_WaveformGenerator "all tests passed" -gDOUBLE_BUFFER=true -gASYNC_RESET=false -gSAMPLE_EVERY=3 \
        -gDATA_WIDTH=1 -gADDR_WIDTH=8 -gSEED=3 &&
    simulate tb_WaveformGenerator "all tests passed" -gDATA_WIDTH=17 -gSEED=4 "${SLOW[@]}" &&
    simulate tb_WaveformGenerator "all tests passed" -gADDR_WIDTH=2 -gSEED=5 "${FAST[@]}" "${LAZY[@]}"
}
check tb_WaveformGenerator tb_wfg

tb_la() {
    local L=$RTL/LogicAnalyser
    analyze "${TEST_PKG[@]}" "$C/IpdbgEscaping.vhd" "$C/pdpRam.vhd" "$L/LogicAnalyserTrigger.vhd" \
        "$L/LogicAnalyserMemory.vhd" "$L/LogicAnalyserRunLengthCoder.vhd" "$L/LogicAnalyserController.vhd" \
        "$L/LogicAnalyserTop.vhd" "$L/test/tb_LogicAnalyser.vhd" || return 1
    simulate tb_LogicAnalyser "all tests passed" &&
    simulate tb_LogicAnalyser "all tests passed" -gASYNC_RESET=false -gSAMPLE_EVERY=2 -gSEED=2 "${FAST[@]}" &&
    simulate tb_LogicAnalyser "all tests passed" -gDATA_WIDTH=8 -gADDR_WIDTH=8 -gRUN=3 -gSEED=3 "${SLOW[@]}" &&
    simulate tb_LogicAnalyser "all tests passed" -gDATA_WIDTH=1 -gADDR_WIDTH=3 -gSEED=4 "${LAZY[@]}" &&
    simulate tb_LogicAnalyser "all tests passed" -gDATA_WIDTH=24 -gADDR_WIDTH=4 -gRUN_LENGTH_COMPRESSION=32 \
        -gRUN=2 -gSEED=7 "${FAST[@]}" &&
    simulate tb_LogicAnalyser "all tests passed" -gRUN_LENGTH_COMPRESSION=4 -gRUN=3 -gSEED=5 &&
    simulate tb_LogicAnalyser "all tests passed" -gRUN_LENGTH_COMPRESSION=2 -gRUN=4 -gDATA_WIDTH=6 \
        -gSAMPLE_EVERY=2 -gSEED=6 "${SLOW[@]}"
}
check tb_LogicAnalyser tb_la

# ------------------------------------------------------------------------------

if [ ${#failed[@]} -ne 0 ]; then
    echo "${#failed[@]} check(s) failed: ${failed[*]}"
    exit 1
fi
echo "all checks passed"
