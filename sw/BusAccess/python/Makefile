# Python bindings for IPDBG BusAccess
#
#   make          build BusAccess.py and _BusAccess.so (builds the library first if needed)
#   make clean    remove generated files

SWIG    ?= swig
CXX     ?= g++
PYTHON3_CONFIG ?= python3-config

LIBDIR := ../bin/Release

CXXFLAGS ?= -O2 -g
override CXXFLAGS += -std=c++17 -fPIC -I.. $(shell $(PYTHON3_CONFIG) --includes)
# find libBusAccess.so relative to _BusAccess.so, no LD_LIBRARY_PATH needed
override LDFLAGS  += -L$(LIBDIR) -Wl,-rpath,'$$ORIGIN/$(LIBDIR)'

.PHONY: all clean FORCE

all: _BusAccess.so

# always ask the library Makefile, relink only if the library changed
$(LIBDIR)/libBusAccess.so: FORCE
	$(MAKE) -C ..

BusAccessCxx_wrap.cxx BusAccess.py: ../BusAccessCxx.i ../BusAccessCxx.h ../BusAccessCxx.tpp
	$(SWIG) -c++ -python -I.. -o BusAccessCxx_wrap.cxx $<

BusAccessCxx_wrap.o: BusAccessCxx_wrap.cxx
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $< -o $@

_BusAccess.so: BusAccessCxx_wrap.o $(LIBDIR)/libBusAccess.so
	$(CXX) -shared $< $(LDFLAGS) -lBusAccess -o $@

clean:
	rm -f BusAccessCxx_wrap.cxx BusAccessCxx_wrap.o BusAccess.py _BusAccess.so
	rm -rf __pycache__
