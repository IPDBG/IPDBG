

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

set srcs { CDC/function_clk.up.arbiter.up_transfer_data_reg[0]
           CDC/function_clk.up.arbiter.up_transfer_data_reg[1]
           CDC/function_clk.up.arbiter.up_transfer_data_reg[2]
           CDC/function_clk.up.arbiter.up_transfer_data_reg[3]
           CDC/function_clk.up.arbiter.up_transfer_data_reg[4]
           CDC/function_clk.up.arbiter.up_transfer_data_reg[5]
           CDC/function_clk.up.arbiter.up_transfer_data_reg[6]
           CDC/function_clk.up.arbiter.up_transfer_data_reg[7]
           CDC/function_clk.up.arbiter.up_transfer_function_number_reg[0]
           CDC/function_clk.up.arbiter.up_transfer_function_number_reg[1]
           CDC/function_clk.up.arbiter.up_transfer_function_number_reg[2]
           CDC/function_clk.down.xoff_mux.xoff_reg
           CDC/function_clk.up.up_transfer_register_valid_reg }

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
            lappend fromCells $fromCell

            var toCell $hier
            append toCell $dst
            lappend toCells $toCell

            append fromCell "/C"
            append toCell "/D"
            set_max_delay -datapath_only -from [get_pins $fromCell] -to [get_pins $toCell] [expr $dstPeriod / 2]
        }
        set_bus_skew -from [get_cells $fromCells] -to [get_cells $toCells] [expr $dstPeriod / 2]
    }
}


# TCK to function clock clk


foreach reg [get_cells -hier {function_clk.down.dwn_handshake_control.ctrl.xon_pending_reg} ] {
    set offset [string last CDC/function_clk.down.dwn_handshake_control.ctrl.xon_pending_reg $reg]
	
	if { $offset != -1 } {
		set toCells {}
		set fromCells {}
		
		set hier [string range $reg 0 [expr $offset - 1] ]

		
		var dstCkPin $reg
        append dstCkPin "/C"
		set dstPeriod [get_property PERIOD [get_clocks -of_objects [ get_pins $dstCkPin ]]]
		
			
		var fromPin $hier
		append fromPin "CDC/jtag_dr.up_transfer_register_valid_sent_reg/C"
		lappend fromCells [get_cell -of_object [get_pin $fromPin]]
		
		foreach toPinStr { "CDC/function_clk.up.up_transfer_register_valid_reg/D" "CDC/function_clk.up.data_up_buffer_empty_reg[*]/D" } {
			var toPin $hier
			append toPin $toPinStr
			lappend toCells [get_cell -of_object [get_pin $toPin]]
			set_max_delay -datapath_only -from [get_pins $fromPin] -to [get_pins $toPin]  [expr $dstPeriod / 2]
		}
		
		
		set fromPin $hier
		append fromPin "CDC/jtag_dr.shift_register.gen_ffs[*].dr_ffs/FF/C"
		lappend fromCells [get_cell -of_object [get_pin $fromPin]]
		
		foreach toPinStr {  "CDC/function_clk.down.xoff_mux.xoff_reg/D"
							"CDC/function_clk.down.xoff_mux.sel_reg[*]/D"
							"CDC/function_clk.down.outputs_stages[*].wo_hs.data_dwn_valid_reg[*]/D"
							"CDC/function_clk.down.outputs_stages[*].w_hs.valid_reg_inv/D"
							"CDC/function_clk.down.outputs_stages[*].w_hs.occupied_reg[*]/D"
							"CDC/function_clk.down.outputs_stages[*].w_hs.data_dwn_local_reg[*]/D"
							"CDC/function_clk.down.outputs_stages[*].w_hs.buf_reg[*][*]/D"
							"CDC/function_clk.down.outputs_stages[*].w_hs.buf_reg[*][*]/CE"
							"CDC/function_clk.down.outputs_stages[*].wo_hs.data_dwn_reg[*][*]/D"
							"CDC/function_clk.down.dwn_handshake_control.functions[*].w_hs_xoffstate.xoff_state_reg[1]/D"
							"CDC/function_clk.down.dwn_handshake_control.functions[*].w_hs_xoffstate.update_xoff_state_reg/D"
							"CDC/function_clk.down.dwn_handshake_control.ctrl.xon_pending_reg/D"
							"CDC/function_clk.down.dwn_handshake_control.ctrl.xon_data_reg[1]/D"
							"CDC/function_clk.down.clear_reg/D" } {
			var toPin $hier
			append toPin $toPinStr
			lappend toCells [get_cell -of_object [get_pin $toPin]]
			set_max_delay -datapath_only -from [get_pins $fromPin] -to [get_pins $toPin]  [expr $dstPeriod / 2]
		}
		
		set_bus_skew -from [get_cells $fromCells] -to [get_cells $toCells] [expr $dstPeriod / 2]
	}
}
