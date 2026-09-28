# SPDX-FileCopyrightText: The IPDBG authors
# SPDX-License-Identifier: CERN-OHL-W-2.0

# Builds the IPDBG demo for the Digilent Cmod S7.
#
#   vivado -mode batch -source build.tcl
#
# Creates the Vivado project in build/ (can be opened in the GUI) and
# copies the bitstream to top.bit next to this script.

set here [file dirname [file normalize [info script]]]
set rtl  [file normalize $here/../..]
set part xc7s25csga225-1

create_project -force cmod-s7 $here/build -part $part
set_property target_language VHDL [current_project]

add_files [list \
    $rtl/common/ipdbg_interface_pkg.vhd \
    $rtl/common/IpdbgEscaping.vhd \
    $rtl/common/dffpc_xc7.vhd \
    $rtl/common/pdpRam.vhd \
    $rtl/JtagHub/IpdbgTap_xc7.vhd \
    $rtl/JtagHub/JtagCdc.vhd \
    $rtl/JtagHub/JtagHub.vhd \
    $rtl/LogicAnalyser/LogicAnalyserController.vhd \
    $rtl/LogicAnalyser/LogicAnalyserMemory.vhd \
    $rtl/LogicAnalyser/LogicAnalyserRunLengthCoder.vhd \
    $rtl/LogicAnalyser/LogicAnalyserTop.vhd \
    $rtl/LogicAnalyser/LogicAnalyserTrigger.vhd \
    $rtl/WaveformGenerator/WaveformGeneratorController.vhd \
    $rtl/WaveformGenerator/WaveformGeneratorMemory.vhd \
    $rtl/WaveformGenerator/WaveformGeneratorTop.vhd \
    $rtl/IoView/IoViewController.vhd \
    $rtl/IoView/IoViewTop.vhd \
    $rtl/BusAccess/BusAccessController.vhd \
    $rtl/BusAccess/BusAccessStatemachine.vhd \
    $rtl/BusAccess/WbMaster.vhd \
    $here/top.vhd ]
set_property top top [current_fileset]
add_files -fileset constrs_1 $here/cmod-s7.xdc

# CDC constraints of the JTAG hub: implementation only, and after the XDC,
# because the script reads the periods of the clocks defined there.
set cdc [add_files -fileset constrs_1 $rtl/JtagHub/JtagHubCdc.tcl]
set_property USED_IN_SYNTHESIS      false $cdc
set_property USED_IN_IMPLEMENTATION true  $cdc
set_property PROCESSING_ORDER       LATE  $cdc

launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
    error "implementation failed, see build/cmod-s7.runs/impl_1"
}

open_run impl_1
report_timing_summary -file $here/build/timing_summary.rpt
set wns [get_property SLACK [get_timing_paths -max_paths 1 -setup]]
set whs [get_property SLACK [get_timing_paths -max_paths 1 -hold]]
puts "WNS $wns ns, WHS $whs ns (details: build/timing_summary.rpt)"
if {$wns < 0 || $whs < 0} {
    puts "WARNING: timing not met"
}

file copy -force $here/build/cmod-s7.runs/impl_1/top.bit $here/top.bit
puts "bitstream: $here/top.bit"
