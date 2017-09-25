

CXX=g++
CC=gcc
GHDL=ghdl
DEBUG=-g
OBJDIR=./obj
GHDLBINDFLAGS=--workdir=$(OBJDIR)
GHDLFLAGS=-O3 $(GHDLBINDFLAGS)

LDFLAGS=-O3
LDLIBS=
CFLAGS = -Wall -O3 $(DEBUG)
CXXFLAGS = -Wall -O3 -std=c++11 $(DEBUG)
LFLAGS = -Wall -O3 $(DEBUG)


# Default target
all: directories JtagHostSim

clean:
	@$(RM) -rf $(OBJDIR)
	@$(RM) JtagHostSim
	@$(RM) e~tb_top.o
	@$(RM) e~tb_top.lst

directories:
	@mkdir -p $(OBJDIR)

JtagHostSim: $(OBJDIR)/jtaghost.o $(OBJDIR)/main.o $(OBJDIR)/server.o e~tb_top.o
	$(CXX) $(LDFLAGS) -o JtagHostSim $(OBJDIR)/jtaghost.o $(OBJDIR)/main.o $(OBJDIR)/server.o `$(GHDL) --list-link $(GHDLFLAGS) tb_top` -pthread -lboost_system -lapr-1 $(LDLIBS)

# Targets to analyze/compile files
$(OBJDIR)/jtaghost.o:
	$(CC) $(CFLAGS) -c jtaghost.c -o $(OBJDIR)/jtaghost.o
$(OBJDIR)/main.o:
	$(CXX) $(CXXFLAGS) -I/usr/include/apr-1 -c main.cpp -o $(OBJDIR)/main.o
$(OBJDIR)/server.o:
	$(CC) $(CFLAGS) -I/usr/include/apr-1 -c server.c -o $(OBJDIR)/server.o

e~tb_top.o: $(OBJDIR)/tb_top.o $(OBJDIR)/tb_top.o $(OBJDIR)/JtagHub_sim.o $(OBJDIR)/LogicAnalyserTop.o $(OBJDIR)/LogicAnalyserMemory.o $(OBJDIR)/LogicAnalyserTrigger.o $(OBJDIR)/LogicAnalyserController.o $(OBJDIR)/IpdbgEscaping.o $(OBJDIR)/pdpRam.o
	$(GHDL) --bind $(GHDLBINDFLAGS) tb_top
#	$(GHDL) --bind $(GHDLBINDFLAGS) -o obj/tb_top.o tb_top

$(OBJDIR)/tb_top.o: tb_top.vhd
	$(GHDL) -a $(GHDLFLAGS) $<
$(OBJDIR)/JtagHub_sim.o: JtagHub_sim.vhd
	$(GHDL) -a $(GHDLFLAGS) $<
$(OBJDIR)/LogicAnalyserTop.o: ../../rtl/LogicAnalyser/LogicAnalyserTop.vhd
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


