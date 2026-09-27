## IPDBG demo for the Digilent Cmod S7 (XC7S25-1CSGA225C)
## Pins from the Digilent master XDC (Cmod-S7-25-Master.xdc)

## 12 MHz board clock. The clock itself is constrained by clk_wiz_0.
set_property -dict { PACKAGE_PIN M9 IOSTANDARD LVCMOS33 } [get_ports { clk_pin }]
create_clock -add -name sys_clk_pin -period 83.333 -waveform {0 41.667} [get_ports { clk_pin }]

## LEDs, driven by the IoView outputs
set_property -dict { PACKAGE_PIN E2    IOSTANDARD LVCMOS33 } [get_ports { leds[0] }]; #IO_L8P_T1_34 Sch=led[1]
set_property -dict { PACKAGE_PIN K1    IOSTANDARD LVCMOS33 } [get_ports { leds[1] }]; #IO_L16P_T2_34 Sch=led[2]
set_property -dict { PACKAGE_PIN J1    IOSTANDARD LVCMOS33 } [get_ports { leds[2] }]; #IO_L16N_T2_34 Sch=led[3]
set_property -dict { PACKAGE_PIN E1    IOSTANDARD LVCMOS33 } [get_ports { leds[3] }]; #IO_L8N_T1_34 Sch=led[4]

## Buttons, read by the IoView inputs 9..8
set_property -dict { PACKAGE_PIN D2 IOSTANDARD LVCMOS33 } [get_ports { buttons[0] }]; #IO_L6P_T0_34 Sch=btn[0]
set_property -dict { PACKAGE_PIN D1 IOSTANDARD LVCMOS33 } [get_ports { buttons[1] }]; #IO_L6N_T0_VREF_34 Sch=btn[1]

## JTAG clock of the BSCANE2 primitive in the JTAG hub
create_clock -add -name drck -period 50 -waveform {0 25} [get_pins { jtag_hub_i/TT/BSCAN_7Series_inst/DRCK }]

## Configuration
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
