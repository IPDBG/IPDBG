# function clock to jtag clock TCK:

set dsts { CDC/jtag_dr.shift_register.gen_ffs[0].dr_ffs/FF
           CDC/jtag_dr.shift_register.gen_ffs[1].dr_ffs/FF
           CDC/jtag_dr.shift_register.gen_ffs[2].dr_ffs/FF
           CDC/jtag_dr.shift_register.gen_ffs[3].dr_ffs/FF
           CDC/jtag_dr.shift_register.gen_ffs[4].dr_ffs/FF
           CDC/jtag_dr.shift_register.gen_ffs[5].dr_ffs/FF
           CDC/jtag_dr.shift_register.gen_ffs[6].dr_ffs/FF
           CDC/jtag_dr.shift_register.gen_ffs[7].dr_ffs/FF
           CDC/jtag_dr.shift_register.gen_ffs[8].dr_ffs/FF
           CDC/jtag_dr.shift_register.gen_ffs[9].dr_ffs/FF
           CDC/jtag_dr.shift_register.gen_ffs[10].dr_ffs/FF
           CDC/jtag_dr.shift_register.gen_ffs[11].dr_ffs/FF
           CDC/jtag_dr.shift_register.gen_ffs[12].dr_ffs/FF }

set srcs { CDC/function_clk.up.arbiter.*.up_transfer_data_reg[0]
           CDC/function_clk.up.arbiter.*.up_transfer_data_reg[1]
           CDC/function_clk.up.arbiter.*.up_transfer_data_reg[2]
           CDC/function_clk.up.arbiter.*.up_transfer_data_reg[3]
           CDC/function_clk.up.arbiter.*.up_transfer_data_reg[4]
           CDC/function_clk.up.arbiter.*.up_transfer_data_reg[5]
           CDC/function_clk.up.arbiter.*.up_transfer_data_reg[6]
           CDC/function_clk.up.arbiter.*.up_transfer_data_reg[7]
           CDC/function_clk.up.arbiter.*.up_transfer_function_number_reg[0]
           CDC/function_clk.up.arbiter.*.up_transfer_function_number_reg[1]
           CDC/function_clk.up.arbiter.*.up_transfer_function_number_reg[2]
           CDC/function_clk.down.fc_gen.xoff_mux.up_xoff_ffs/FF
           CDC/function_clk.up.arbiter.*.up_transfer_register_valid_reg }

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
        #puts [llength $fromCells]
        #puts [llength $toCells]
    }
}


# TCK to function clock clk


set srcs { CDC/jtag_dr.shift_register.gen_ffs[0].dr_ffs/FF
           CDC/jtag_dr.shift_register.gen_ffs[1].dr_ffs/FF
           CDC/jtag_dr.shift_register.gen_ffs[2].dr_ffs/FF
           CDC/jtag_dr.shift_register.gen_ffs[3].dr_ffs/FF
           CDC/jtag_dr.shift_register.gen_ffs[4].dr_ffs/FF
           CDC/jtag_dr.shift_register.gen_ffs[5].dr_ffs/FF
           CDC/jtag_dr.shift_register.gen_ffs[6].dr_ffs/FF
           CDC/jtag_dr.shift_register.gen_ffs[7].dr_ffs/FF
           CDC/jtag_dr.shift_register.gen_ffs[8].dr_ffs/FF
           CDC/jtag_dr.shift_register.gen_ffs[9].dr_ffs/FF
           CDC/jtag_dr.shift_register.gen_ffs[10].dr_ffs/FF
           CDC/jtag_dr.xoff_sent_ff/FF
           CDC/jtag_dr.up_transfer_register_valid_sent_ff/FF
           CDC/jtag_dr.shift_register.gen_ffs[12].dr_ffs/FF }

set dsts { CDC/function_clk.cdc.dwn_data_ffs[0].dd_ffs/FF
           CDC/function_clk.cdc.dwn_data_ffs[1].dd_ffs/FF
           CDC/function_clk.cdc.dwn_data_ffs[2].dd_ffs/FF
           CDC/function_clk.cdc.dwn_data_ffs[3].dd_ffs/FF
           CDC/function_clk.cdc.dwn_data_ffs[4].dd_ffs/FF
           CDC/function_clk.cdc.dwn_data_ffs[5].dd_ffs/FF
           CDC/function_clk.cdc.dwn_data_ffs[6].dd_ffs/FF
           CDC/function_clk.cdc.dwn_data_ffs[7].dd_ffs/FF
           CDC/function_clk.cdc.dwn_functions_ffs[0].df_ffs/FF
           CDC/function_clk.cdc.dwn_functions_ffs[1].df_ffs/FF
           CDC/function_clk.cdc.dwn_functions_ffs[2].df_ffs/FF
           CDC/function_clk.cdc.xoff_sent_ffs/FF
           CDC/function_clk.cdc.up_dv_sent_ffs/FF
           CDC/function_clk.cdc.dv_ffs/FF }

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
        #puts [llength $fromCells]
        #puts [llength $toCells]
    }
}
