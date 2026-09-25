# Python bindings for IPDBG BusAccess
#
#   make          build BusAccess.py and the extension module _BusAccess
#                 Linux:   _BusAccess.so, links libBusAccess.so (builds the library first if needed)
#                 Windows: _BusAccess<suffix>.pyd with the library compiled in (MinGW-w64 and the
#                          MSYS2 Python; <suffix> from python3-config --extension-suffix)
#   make clean    remove generated files

SWIG    ?= swig
CC      ?= gcc
CXX     ?= g++
PYTHON3_CONFIG ?= python3-config

LIBDIR := ../bin/Release

CFLAGS   ?= -O2 -g
CXXFLAGS ?= -O2 -g

.PHONY: all clean FORCE
.DEFAULT_GOAL := all

BusAccessCxx_wrap.cxx BusAccess.py: ../BusAccessCxx.i ../BusAccessCxx.h ../BusAccessCxx.tpp
	$(SWIG) -c++ -python -I.. -o BusAccessCxx_wrap.cxx $<

ifeq ($(OS),Windows_NT)

# Windows: the library is compiled into the module, so no DLL has to be found at runtime.
# Extensions have to be linked against libpython on Windows, hence --embed.
MODULE := _BusAccess$(shell $(PYTHON3_CONFIG) --extension-suffix)
OBJS   := BusAccessCxx_wrap.o BusAccess.o BusAccessCxx.o

override CPPFLAGS += -I.. -DIPDBG_STATIC $(shell $(PYTHON3_CONFIG) --includes)
override CFLAGS   += -std=gnu11
override CXXFLAGS += -std=c++17

all: $(MODULE)

BusAccessCxx_wrap.o: BusAccessCxx_wrap.cxx
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $< -o $@

BusAccess.o: ../BusAccess.c ../BusAccess.h
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

BusAccessCxx.o: ../BusAccessCxx.cpp ../BusAccessCxx.h ../BusAccess.h
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $< -o $@

$(MODULE): $(OBJS)
	$(CXX) -shared $^ $(LDFLAGS) $(shell $(PYTHON3_CONFIG) --ldflags --embed) -lws2_32 -o $@

else

MODULE := _BusAccess.so

override CXXFLAGS += -std=c++17 -fPIC -I.. $(shell $(PYTHON3_CONFIG) --includes)
# find libBusAccess.so relative to _BusAccess.so, no LD_LIBRARY_PATH needed
override LDFLAGS  += -L$(LIBDIR) -Wl,-rpath,'$$ORIGIN/$(LIBDIR)'

all: $(MODULE)

# always ask the library Makefile, relink only if the library changed
$(LIBDIR)/libBusAccess.so: FORCE
	$(MAKE) -C ..

BusAccessCxx_wrap.o: BusAccessCxx_wrap.cxx
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $< -o $@

$(MODULE): BusAccessCxx_wrap.o $(LIBDIR)/libBusAccess.so
	$(CXX) -shared $< $(LDFLAGS) -lBusAccess -o $@

endif

clean:
	rm -f BusAccessCxx_wrap.cxx BusAccess.py $(MODULE) BusAccessCxx_wrap.o BusAccess.o BusAccessCxx.o
	rm -rf __pycache__
