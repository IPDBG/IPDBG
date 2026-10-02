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

# elaborate TOP [OPTIONS...]
elaborate() { local top=$1; shift; "$GHDL" -e "${FLAGS[@]}" "$@" "$top"; }

# simulate TOP EXPECTED [OPTIONS...]: runs TOP, fails on assertion failures
# and if EXPECTED is not reported
simulate() {
    local top=$1 expected=$2
    shift 2
    "$GHDL" --elab-run "${FLAGS[@]}" "$top" "$@" --assert-level=error | tee sim.log
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
    elaborate JtagHub -Paltera -Papa -gFLOW_CONTROL_ENABLE=0000001
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
    analyze "$C/ipdbg_interface_pkg.vhd" "${IURT[@]}" "$RTL/Iurt/test/tb_Iurt.vhd" &&
    simulate tb_Iurt "tb_Iurt: all tests passed" -gBUS_TYPE=wb -gASYNC_RESET=true &&
    simulate tb_Iurt "tb_Iurt: all tests passed" -gBUS_TYPE=ahb -gASYNC_RESET=false
}
check tb_Iurt tb_iurt

tb_uart() {
    analyze "$C/ipdbg_interface_pkg.vhd" "$C/dffpc_behav.vhd" "$C/IpdbgEscaping.vhd" \
        "$RTL/BusAccess/BusAccessStatemachine.vhd" "$RTL/BusAccess/BusAccessController.vhd" \
        "$RTL/IoProbe/IoProbeTop.vhd" "$RTL/Uart/IpdbgUartTx.vhd" "$RTL/Uart/IpdbgUartRx.vhd" \
        "$RTL/Uart/IpdbgUart.vhd" "$RTL/Uart/test/IpdbgUart_tb.vhd" &&
    simulate IpdbgUart_tb "IpdbgUart_tb: passed"
}
check IpdbgUart_tb tb_uart

# ------------------------------------------------------------------------------

if [ ${#failed[@]} -ne 0 ]; then
    echo "${#failed[@]} check(s) failed: ${failed[*]}"
    exit 1
fi
echo "all checks passed"
