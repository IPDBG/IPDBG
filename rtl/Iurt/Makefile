# SPDX-FileCopyrightText: The IPDBG authors
# SPDX-License-Identifier: CERN-OHL-W-2.0

# Regenerates the register blocks in generated/ from iurt.rdl.
# Only needed after changing iurt.rdl; the generated files are part of the
# repository.
#
#   make regs     needs PeakRDL with the VHDL exporter:
#                 pip install peakrdl-cli==1.5.0 peakrdl-regblock-vhdl==1.3.1.1

PEAKRDL ?= peakrdl
OUT     := generated

# entity name : --cpuif
BUSES := IurtRegsWb:wishbone-flat \
         IurtRegsAxi4l:axi4-lite-flat \
         IurtRegsApb3:apb3-flat \
         IurtRegsApb4:apb4-flat \
         IurtRegsAvalon:avalon-mm-flat \
         IurtRegsObi:obi-flat \
         IurtRegsPassthrough:passthrough

.PHONY: regs

regs: iurt.rdl
	rm -rf $(OUT)
	$(foreach b,$(BUSES),$(PEAKRDL) regblock-vhdl $< -o $(OUT) \
	    --cpuif $(word 2,$(subst :, ,$(b))) --module-name $(word 1,$(subst :, ,$(b))) \
	    --copy-utils-pkg &&) true
