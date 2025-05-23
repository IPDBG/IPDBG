

CXX=g++
CC=gcc
GHDL=ghdl
DEBUG=-g
OBJDIR=./obj
GHDLBINDFLAGS=--std=08 --workdir=$(OBJDIR)
GHDLFLAGS=-O3 $(DEBUG) $(GHDLBINDFLAGS)

LDFLAGS=-O3
LDLIBS=
CFLAGS = -Wall $(DEBUG) -O3 $(DEBUG)
CXXFLAGS = -Wall $(DEBUG) -O3 -std=c++11 $(DEBUG)
LFLAGS = -Wall $(DEBUG) -O3 $(DEBUG)


# Default target
all: directories CoSim

cleanall:
	@$(RM) -rf $(OBJDIR)
	@$(RM) CoSim
	@$(RM) e~tb_top.o
	@$(RM) e~tb_top.lst

directories:
	@mkdir -p $(OBJDIR)

CoSim: $(OBJDIR)/main.o e~tb_top.o
	$(CXX) $(LDFLAGS) -o CoSim $(OBJDIR)/main.o `$(GHDL) --list-link $(GHDLFLAGS) tb_top` $(LDLIBS)

# Targets to analyze/compile files
$(OBJDIR)/main.o: main.cpp
	$(CXX) $(CXXFLAGS) -c main.cpp -o $(OBJDIR)/main.o

#	$(OBJDIR)/JtagHub_sim.o

e~tb_top.o: $(OBJDIR)/tb_top.o \
    $(OBJDIR)/JtagAdapter.o $(OBJDIR)/JtagHub.o \
    $(OBJDIR)/LogicAnalyserTop.o $(OBJDIR)/LogicAnalyserMemory.o $(OBJDIR)/LogicAnalyserTrigger.o $(OBJDIR)/LogicAnalyserController.o $(OBJDIR)/LogicAnalyserRunLengthCoder.o \
    $(OBJDIR)/WaveformGeneratorController.o $(OBJDIR)/WaveformGeneratorMemory.o $(OBJDIR)/WaveformGeneratorTop.o \
    $(OBJDIR)/IoViewTop.o $(OBJDIR)/IoViewController.o \
    $(OBJDIR)/BusAccessController.o $(OBJDIR)/BusAccessStatemachine.o $(OBJDIR)/WbMaster.o \
    $(OBJDIR)/IpdbgEscaping.o $(OBJDIR)/pdpRam.o
	$(GHDL) --bind $(GHDLBINDFLAGS) tb_top

$(OBJDIR)/ipdbg_interface_pkg.o: ../../rtl/common/ipdbg_interface_pkg.vhd
	$(GHDL) -a $(GHDLFLAGS) $<
$(OBJDIR)/tb_top.o: tb_top.vhd $(OBJDIR)/ipdbg_interface_pkg.o
	$(GHDL) -a $(GHDLFLAGS) $<
#$(OBJDIR)/JtagHub_sim.o: JtagHub_sim.vhd $(OBJDIR)/ipdbg_interface_pkg.o
#	$(GHDL) -a $(GHDLFLAGS) $<
$(OBJDIR)/JtagAdapter.o: JtagAdapter.vhd
	$(GHDL) -a $(GHDLFLAGS) $<
$(OBJDIR)/JtagHub.o: ../../rtl/JtagHub/JtagHub_4ext.vhd $(OBJDIR)/ipdbg_interface_pkg.o $(OBJDIR)/JtagCdc.o $(OBJDIR)/IpdbgTap.o
	$(GHDL) -a $(GHDLFLAGS) $<
$(OBJDIR)/JtagCdc.o: ../../rtl/JtagHub/JtagCdc.vhd $(OBJDIR)/dffpc.o
	$(GHDL) -a $(GHDLFLAGS) $<
$(OBJDIR)/IpdbgTap.o: ../../rtl/JtagHub/IpdbgTap_generic.vhd
	$(GHDL) -a $(GHDLFLAGS) $<
$(OBJDIR)/LogicAnalyserTop.o: ../../rtl/LogicAnalyser/LogicAnalyserTop.vhd $(OBJDIR)/ipdbg_interface_pkg.o
	$(GHDL) -a $(GHDLFLAGS) $<
$(OBJDIR)/LogicAnalyserMemory.o: ../../rtl/LogicAnalyser/LogicAnalyserMemory.vhd
	$(GHDL) -a $(GHDLFLAGS) $<
$(OBJDIR)/LogicAnalyserTrigger.o: ../../rtl/LogicAnalyser/LogicAnalyserTrigger.vhd
	$(GHDL) -a $(GHDLFLAGS) $<
$(OBJDIR)/LogicAnalyserController.o: ../../rtl/LogicAnalyser/LogicAnalyserController.vhd
	$(GHDL) -a $(GHDLFLAGS) $<
$(OBJDIR)/LogicAnalyserRunLengthCoder.o: ../../rtl/LogicAnalyser/LogicAnalyserRunLengthCoder.vhd
	$(GHDL) -a $(GHDLFLAGS) $<
$(OBJDIR)/IpdbgEscaping.o: ../../rtl/common/IpdbgEscaping.vhd $(OBJDIR)/ipdbg_interface_pkg.o
	$(GHDL) -a $(GHDLFLAGS) $<
$(OBJDIR)/pdpRam.o: ../../rtl/common/pdpRam.vhd
	$(GHDL) -a $(GHDLFLAGS) $<
$(OBJDIR)/dffpc.o: ../../rtl/common/dffpc_behav.vhd
	$(GHDL) -a $(GHDLFLAGS) $<
$(OBJDIR)/WaveformGeneratorTop.o: ../../rtl/WaveformGenerator/WaveformGeneratorTop.vhd $(OBJDIR)/ipdbg_interface_pkg.o
	$(GHDL) -a $(GHDLFLAGS) $<
$(OBJDIR)/WaveformGeneratorController.o: ../../rtl/WaveformGenerator/WaveformGeneratorController.vhd
	$(GHDL) -a $(GHDLFLAGS) $<
$(OBJDIR)/WaveformGeneratorMemory.o: ../../rtl/WaveformGenerator/WaveformGeneratorMemory.vhd
	$(GHDL) -a $(GHDLFLAGS) $<
$(OBJDIR)/IoViewTop.o: ../../rtl/IoView/IoViewTop.vhd $(OBJDIR)/ipdbg_interface_pkg.o
	$(GHDL) -a $(GHDLFLAGS) $<
$(OBJDIR)/IoViewController.o: ../../rtl/IoView/IoViewController.vhd
	$(GHDL) -a $(GHDLFLAGS) $<
$(OBJDIR)/BusAccessStatemachine.o: ../../rtl/BusAccess/BusAccessStatemachine.vhd
	$(GHDL) -a $(GHDLFLAGS) $<
$(OBJDIR)/BusAccessController.o: ../../rtl/BusAccess/BusAccessController.vhd
	$(GHDL) -a $(GHDLFLAGS) $<
$(OBJDIR)/WbMaster.o: ../../rtl/BusAccess/WbMaster.vhd $(OBJDIR)/ipdbg_interface_pkg.o
	$(GHDL) -a $(GHDLFLAGS) $<
