# SPDX-FileCopyrightText: The IPDBG authors
# SPDX-License-Identifier: MPL-2.0

# Octave bindings for IPDBG BusAccess
#
#   make          build BusAccess.oct
#                 Linux:   links libipdbg-busaccess.so (builds the library first if needed)
#                 Windows: compiles the library into BusAccess.oct (MinGW-w64, e.g. MSYS2)
#   make install  install BusAccess.oct into the site oct-file directory of Octave
#                 (octave-config -p LOCALOCTFILEDIR); another directory with OCTDIR=...
#   make uninstall remove it again
#   make clean    remove generated files
#
# Linux: the module links the library without rpath. Before make install, run Octave with
#   LD_LIBRARY_PATH=../bin/Release and addpath of this directory

include ../../common.mk

SWIG      ?= swig
MKOCTFILE ?= mkoctfile

LIBDIR := ../bin/Release

.PHONY: all install uninstall clean FORCE

all: BusAccess.oct

# always ask the library Makefile, relink only if the library changed
$(LIBDIR)/libipdbg-busaccess.so: FORCE
	$(MAKE) -C ..

BusAccessCxx_wrap.cxx: ../BusAccessCxx.i ../BusAccessCxx.h ../BusAccessCxx.tpp
	$(SWIG) -c++ -octave -I.. -o $@ $<

ifeq ($(OS),Windows_NT)

# Windows: the library is compiled into BusAccess.oct, so no DLL has to be found at runtime
LIBSRCS := ../BusAccess.c ../BusAccessCxx.cpp

BusAccess.oct: BusAccessCxx_wrap.cxx $(LIBSRCS) ../BusAccess.h
	$(MKOCTFILE) -I.. -DIPDBG_STATIC BusAccessCxx_wrap.cxx $(LIBSRCS) -lws2_32 -o $@

else

BusAccess.oct: BusAccessCxx_wrap.cxx $(LIBDIR)/libipdbg-busaccess.so
	$(MKOCTFILE) -I.. $< -L$(LIBDIR) -lipdbg-busaccess -o $@

endif

OCTAVE_CONFIG ?= octave-config
OCTDIR        ?= $(shell $(OCTAVE_CONFIG) -p LOCALOCTFILEDIR)

install: all
	$(INSTALL) -d $(DESTDIR)$(OCTDIR)
	$(INSTALL_PROGRAM) BusAccess.oct $(DESTDIR)$(OCTDIR)

uninstall:
	rm -f $(DESTDIR)$(OCTDIR)/BusAccess.oct

clean:
	rm -f BusAccessCxx_wrap.cxx BusAccessCxx_wrap.o BusAccess.oct BusAccess.o BusAccessCxx.o
