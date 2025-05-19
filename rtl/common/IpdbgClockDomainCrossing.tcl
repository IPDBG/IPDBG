

# host-clock to function-clock

set srcs { data_dwn_block.host_clock_domain.request_reg
           data_dwn_block.host_clock_domain.transfer_register_reg[*]
           data_up_block.host_clock_domain.acknowledge_reg }

set dsts { data_dwn_block.function_clock_domain.ff_clk.mff_flops[0].MFF/FF
           data_dwn_block.function_clock_domain.dn_lines_func_reg[dnlink_data][*]
           data_up_block.function_clock_domain.ff_clk1.mff_flops[0].MFF/FF }

foreach reg [get_cells -hier {FF} ] {
    set offset [string last [lindex $dsts 0] $reg]
    if { $offset != -1 } {
        set hier [string range $reg 0 [expr $offset - 1] ]
        #puts $hier

        var dstCkPin $reg
        append dstCkPin "/C"
        set dstPeriod [get_property PERIOD [get_clocks -of_objects [ get_pins $dstCkPin ]]]
        #puts $dstPeriod

        set toCells {}
        set fromCells {}

        foreach dst $dsts src $srcs {
            var fromCell $hier
            append fromCell $src
            var numNewFromCells [llength [get_cells $fromCell]]

            var toCell $hier
            append toCell $dst
            var numNewToCells [llength [get_cells $toCell]]
            if { $numNewToCells > 0 && $numNewFromCells > 0 } {
                lappend fromCells $fromCell
                lappend toCells $toCell

                append fromCell "/C"
                append toCell "/D"
                set_max_delay -datapath_only -from [get_pins $fromCell] -to [get_pins $toCell] [expr $dstPeriod / 2]
            }
        }
        set_bus_skew -from [get_cells $fromCells] -to [get_cells $toCells] [expr $dstPeriod / 2]
    }
}


# function-clock to host-clock

set srcs { data_dwn_block.function_clock_domain.acknowledge_reg
           data_up_block.function_clock_domain.request_reg
           data_up_block.function_clock_domain.transfer_register_reg[*]
}
set dsts { data_dwn_block.host_clock_domain.ff_jtag.mff_flops[0].MFF/FF
           data_up_block.host_clock_domain.ff_clkjtag.mff_flops[0].MFF/FF
           data_up_block.host_clock_domain.up_lines_host_reg[uplink_data][*]
}

foreach reg [get_cells -hier {FF} ] {
    set offset [string last [lindex $dsts 0] $reg]
    if { $offset != -1 } {
        set hier [string range $reg 0 [expr $offset - 1] ]
        #puts $hier

        var dstCkPin $reg
        append dstCkPin "/C"
        set dstPeriod [get_property PERIOD [get_clocks -of_objects [ get_pins $dstCkPin ]]]
        #puts $dstPeriod

        set toCells {}
        set fromCells {}

        foreach dst $dsts src $srcs {
            var fromCell $hier
            append fromCell $src
            var numNewFromCells [llength [get_cells $fromCell]]

            var toCell $hier
            append toCell $dst
            var numNewToCells [llength [get_cells $toCell]]
            if { $numNewToCells > 0 && $numNewFromCells > 0 } {
                lappend toCells $toCell
                lappend fromCells $fromCell

                append fromCell "/C"
                append toCell "/D"
                set_max_delay -datapath_only -from [get_pins $fromCell] -to [get_pins $toCell] [expr $dstPeriod / 2]
            }
        }
        set_bus_skew -from [get_cells $fromCells] -to [get_cells $toCells] [expr $dstPeriod / 2]
    }
}

