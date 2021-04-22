

CXX=g++
CC=gcc
GHDL=ghdl
DEBUG=-g
OBJDIR=./obj
GHDLBINDFLAGS=--workdir=$(OBJDIR)
GHDLFLAGS=-O3 $(DEBUG) $(GHDLBINDFLAGS)

LDFLAGS=-O3
LDLIBS=
CFLAGS = -Wall $(DEBUG) -O3 $(DEBUG)
CXXFLAGS = -Wall $(DEBUG) -O3 -std=c++11 $(DEBUG)
LFLAGS = -Wall $(DEBUG) -O3 $(DEBUG)


# Default target
all: directories JtagHostSim

cleanall:
	@$(RM) -rf $(OBJDIR)
	@$(RM) JtagHostSim
	@$(RM) e~tb_top.o
	@$(RM) e~tb_top.lst

directories:
	@mkdir -p $(OBJDIR)

JtagHostSim: $(OBJDIR)/jtaghost.o $(OBJDIR)/main.o $(OBJDIR)/server.o e~tb_top.o $(OBJDIR)/JtagHostLoop.o
	$(CXX) $(LDFLAGS) -o JtagHostSim $(OBJDIR)/jtaghost.o $(OBJDIR)/main.o $(OBJDIR)/server.o $(OBJDIR)/JtagHostLoop.o `$(GHDL) --list-link $(GHDLFLAGS) tb_top` -pthread -lboost_system -lapr-1 $(LDLIBS)

# Targets to analyze/compile files
$(OBJDIR)/jtaghost.o: jtaghost.c
	$(CC) $(CFLAGS) -c jtaghost.c -o $(OBJDIR)/jtaghost.o
$(OBJDIR)/main.o: main.cpp
	$(CXX) $(CXXFLAGS) -I/usr/include/apr-1 -c main.cpp -o $(OBJDIR)/main.o
$(OBJDIR)/JtagHostLoop.o: JtagHostLoop.cpp
	$(CXX) $(CXXFLAGS) -c JtagHostLoop.cpp -o $(OBJDIR)/JtagHostLoop.o
$(OBJDIR)/server.o: server.c
	$(CC) $(CFLAGS) -I/usr/include/apr-1 -c server.c -o $(OBJDIR)/server.o

e~tb_top.o: $(OBJDIR)/tb_top.o $(OBJDIR)/tb_top.o $(OBJDIR)/JtagHub_sim.o \
    $(OBJDIR)/LogicAnalyserTop.o $(OBJDIR)/LogicAnalyserMemory.o $(OBJDIR)/LogicAnalyserTrigger.o $(OBJDIR)/LogicAnalyserController.o \
    $(OBJDIR)/WaveformGeneratorController.o $(OBJDIR)/WaveformGeneratorMemory.o $(OBJDIR)/WaveformGeneratorTop.o \
    $(OBJDIR)/IoViewTop.o $(OBJDIR)/IoViewController.o \
    $(OBJDIR)/IpdbgEscaping.o $(OBJDIR)/pdpRam.o
	$(GHDL) --bind $(GHDLBINDFLAGS) tb_top

$(OBJDIR)/ipdbg_interface_pkg.o: ../../rtl/common/ipdbg_interface_pkg.vhd
	$(GHDL) -a $(GHDLFLAGS) $<
$(OBJDIR)/tb_top.o: tb_top.vhd $(OBJDIR)/ipdbg_interface_pkg.o
	$(GHDL) -a $(GHDLFLAGS) $<
$(OBJDIR)/JtagHub_sim.o: JtagHub_sim.vhd \
	$(OBJDIR)/ipdbg_interface_pkg.o
	$(GHDL) -a $(GHDLFLAGS) $<
$(OBJDIR)/LogicAnalyserTop.o: ../../rtl/LogicAnalyser/LogicAnalyserTop.vhd \
	$(OBJDIR)/ipdbg_interface_pkg.o
	$(GHDL) -a $(GHDLFLAGS) $<
$(OBJDIR)/LogicAnalyserMemory.o: ../../rtl/LogicAnalyser/LogicAnalyserMemory.vhd
	$(GHDL) -a $(GHDLFLAGS) $<
$(OBJDIR)/LogicAnalyserTrigger.o: ../../rtl/LogicAnalyser/LogicAnalyserTrigger.vhd
	$(GHDL) -a $(GHDLFLAGS) $<
$(OBJDIR)/LogicAnalyserController.o: ../../rtl/LogicAnalyser/LogicAnalyserController.vhd
	$(GHDL) -a $(GHDLFLAGS) $<
$(OBJDIR)/IpdbgEscaping.o: ../../rtl/common/IpdbgEscaping.vhd
	$(GHDL) -a $(GHDLFLAGS) $<
$(OBJDIR)/pdpRam.o: ../../rtl/common/pdpRam.vhd
	$(GHDL) -a $(GHDLFLAGS) $<
$(OBJDIR)/WaveformGeneratorController.o: ../../rtl/WaveformGenerator/WaveformGeneratorController.vhd
	$(GHDL) -a $(GHDLFLAGS) $<
$(OBJDIR)/WaveformGeneratorMemory.o: ../../rtl/WaveformGenerator/WaveformGeneratorMemory.vhd
	$(GHDL) -a $(GHDLFLAGS) $<
$(OBJDIR)/WaveformGeneratorTop.o: ../../rtl/WaveformGenerator/WaveformGeneratorTop.vhd
	$(GHDL) -a $(GHDLFLAGS) $<
$(OBJDIR)/IoViewTop.o: ../../rtl/IoView/IoViewTop.vhd
	$(GHDL) -a $(GHDLFLAGS) $<
$(OBJDIR)/IoViewController.o: ../../rtl/IoView/IoViewController.vhd
	$(GHDL) -a $(GHDLFLAGS) $<

