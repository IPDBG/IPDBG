=== JTAG-Hub ===

JtagHub_4ext.vhd: Lattice ecp2, ecp3, ecp5
                  Gowin gw1n, gw2n
JtagHub_efinix.vhd: Efinix Trion, Titanium
JtagHub_proasic3.vhd: Microsemi ProASIC3
JtagHub.vhd: AMD Spartan3, Spartan6, 7Series, Virtex6, Zynq7000


IpdbgTap_ecp2.vhd: Lattice ecp2
IpdbgTap_ecp3.vhd: Lattice ecp3
IpdbgTap_ecp5.vhd: Lattice ecp5
IpdbgTap_gowin.vhd:  Gowin gw1n, gw2n
IpdbgTap_MAX10.vhd: Intel Max10
IpdbgTap_proasic3.vhd: Microsemi ProASIC3
IpdbgTap_xc3s.vhd: AMD Spartan 3
IpdbgTap_xc6s.vhd: AMD Spartan 6
IpdbgTap_xc6v.vhd: AMD Virtex6
IpdbgTap_xc7.vhd: AMD 7Series, Zynq7000
JtagCdc.vhd: all
JtagHubCdc.tcl: tcp script to generate timing constraints for the JtagCDC



- AMD (Xilinx)
  - all families
    - JtagHub.vhd
    - JtagCdc.vhd
  - Spartan 3
    - IpdbgTap_xc3s.vhd
  - Spartan 6
    - IpdbgTap_xc6s.vhd
  - Virtex 6
    - IpdbgTap_xc6v.vhd
  - 7 Series & Zynq 7000
    - IpdbgTap_xc7.vhd
- Intel (altera)
  - all families
    - JtagHub.vhd
    - JtagCdc.vhd
    - IpdbgTap_intel.vhd
  - Cyclone III
    - IpdbgTapJtag_cycloneiii.vhd
  - Cyclone III LS
    - IpdbgTapJtag_cycloneiiils.vhd
  - Cyclone IV
    - IpdbgTapJtag_cycloneiv.vhd
  - Cyclone IV E
    - IpdbgTapJtag_cycloneive.vhd
  - Cyclone V
    - IpdbgTapJtag_cyclonev.vhd
  - Cyclone III
    - IpdbgTapJtag_cycloneiii.vhd
  - Cyclone III
    - IpdbgTapJtag_cycloneiii.vhd
  - Cyclone III
    - IpdbgTapJtag_cycloneiii.vhd
