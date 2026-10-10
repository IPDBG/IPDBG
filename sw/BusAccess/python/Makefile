# SPDX-FileCopyrightText: The IPDBG authors
# SPDX-License-Identifier: MPL-2.0

# Python bindings for IPDBG BusAccess
#
#   make          build BusAccess.py and the extension module _BusAccess
#                 Linux:   _BusAccess.so, links libipdbg-busaccess.so (builds the library first if needed)
#                 Windows: _BusAccess<suffix>.pyd with the library compiled in (MinGW-w64 and the
#                          MSYS2 Python; <suffix> from python3-config --extension-suffix)
#   make install  install BusAccess.py and the module into the site-packages of python3 under
#                 PREFIX (see ../../common.mk); another directory with PYTHONDIR=...
#   make uninstall remove them again
#   make clean    remove generated files
#
# Linux: the module links the library without rpath. Before make install, run it with
#   LD_LIBRARY_PATH=../bin/Release PYTHONPATH=. python3 ...

include ../../common.mk

SWIG    ?= swig
CC      ?= gcc
CXX     ?= g++
PYTHON3_CONFIG ?= python3-config

LIBDIR := ../bin/Release

CFLAGS   ?= -O2 -g
CXXFLAGS ?= -O2 -g

.PHONY: all install uninstall clean FORCE
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
override LDFLAGS  += -L$(LIBDIR)

all: $(MODULE)

# always ask the library Makefile, relink only if the library changed
$(LIBDIR)/libipdbg-busaccess.so: FORCE
	$(MAKE) -C ..

BusAccessCxx_wrap.o: BusAccessCxx_wrap.cxx
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $< -o $@

$(MODULE): BusAccessCxx_wrap.o $(LIBDIR)/libipdbg-busaccess.so
	$(CXX) -shared $< $(LDFLAGS) -lipdbg-busaccess -o $@

endif

# site-packages (platlib) of python3 with PREFIX as base, e.g. /usr/local/lib64/python3.13/site-packages
# (scheme posix_prefix). Debian and Ubuntu use dist-packages instead: set PYTHONDIR there,
# e.g. PYTHONDIR=/usr/local/lib/python3.12/dist-packages
PYTHON3   ?= python3
PYTHONDIR ?= $(shell $(PYTHON3) -c "import sysconfig; print(sysconfig.get_path('platlib', 'posix_prefix', vars={'base': '$(prefix)', 'platbase': '$(exec_prefix)'}))")

install: all
	$(INSTALL) -d $(DESTDIR)$(PYTHONDIR)
	$(INSTALL_DATA) BusAccess.py $(DESTDIR)$(PYTHONDIR)
	$(INSTALL_PROGRAM) $(MODULE) $(DESTDIR)$(PYTHONDIR)

uninstall:
	rm -f $(DESTDIR)$(PYTHONDIR)/BusAccess.py $(DESTDIR)$(PYTHONDIR)/$(MODULE)

clean:
	rm -f BusAccessCxx_wrap.cxx BusAccess.py $(MODULE) BusAccessCxx_wrap.o BusAccess.o BusAccessCxx.o
	rm -rf __pycache__
