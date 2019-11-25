`define LATTICE_FAMILY "EC"
`define LATTICE_FAMILY_EC
`define LATTICE_DEVICE "All"
`ifndef SYSTEM_CONF
`define SYSTEM_CONF
`timescale 1ns / 100 ps
`define CFG_EBA_RESET 32'h0
`define CFG_DEBUG_ENABLED
`define LM32_SINGLE_STEP_ENABLED
`define CFG_WATCHPOINTS 0
`define CFG_BREAKPOINTS 0
`define CFG_DEBA_RESET 32'h8000
`define CFG_EXTERNAL_BREAK_ENABLED
`define CFG_DISTRAM_POSEDGE_REGISTER_FILE
`define MULT_ENABLE
`define CFG_PL_MULTIPLY_ENABLED
`define SHIFT_ENABLE
`define CFG_PL_BARREL_SHIFT_ENABLED
`define CFG_MC_DIVIDE_ENABLED
`define CFG_SIGN_EXTEND_ENABLED
`define LM32_I_PC_WIDTH 22
`define ebrEBR_WB_DAT_WIDTH 32
`define ebrINIT_FILE_NAME "D:/LM32/LM32_xilinx/lm32_code/bin/Release/testProject.vmem"
`define ebrINIT_FILE_FORMAT "hex"
`define gdbstubEBR_WB_DAT_WIDTH 32
`define gdbstubINIT_FILE_NAME "D:/LM32/IPDBG/sw/lm32gdbstub/bin/Release/lm32gdbstub.vmem"
`define gdbstubINIT_FILE_FORMAT "hex"
`define slave_passthruS_WB_DAT_WIDTH 32
`define S_WB_SEL_WIDTH 4
`define slave_passthruS_WB_ADR_WIDTH 32
`endif // SYSTEM_CONF
