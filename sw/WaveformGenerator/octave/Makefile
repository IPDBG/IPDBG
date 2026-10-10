# SPDX-FileCopyrightText: The IPDBG authors
# SPDX-License-Identifier: MPL-2.0

# Octave bindings for IPDBG WaveformGenerator
#
#   make          build WaveformGenerator.oct
#                 Linux:   links libipdbg-waveformgenerator.so (builds the library first if needed)
#                 Windows: compiles the library into WaveformGenerator.oct (MinGW-w64, e.g. MSYS2)
#   make install  install WaveformGenerator.oct into the site oct-file directory of Octave
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

all: WaveformGenerator.oct

# always ask the library Makefile, relink only if the library changed
$(LIBDIR)/libipdbg-waveformgenerator.so: FORCE
	$(MAKE) -C ..

WaveformGeneratorCxx_wrap.cxx: ../WaveformGeneratorCxx.i ../WaveformGeneratorCxx.h
	$(SWIG) -c++ -octave -I.. -o $@ $<

ifeq ($(OS),Windows_NT)

# Windows: the library is compiled into WaveformGenerator.oct, so no DLL has to be found at runtime
LIBSRCS := ../WaveformGenerator.c ../WaveformGeneratorCxx.cpp

WaveformGenerator.oct: WaveformGeneratorCxx_wrap.cxx $(LIBSRCS) ../WaveformGenerator.h
	$(MKOCTFILE) -I.. -DIPDBG_STATIC WaveformGeneratorCxx_wrap.cxx $(LIBSRCS) -lws2_32 -o $@

else

WaveformGenerator.oct: WaveformGeneratorCxx_wrap.cxx $(LIBDIR)/libipdbg-waveformgenerator.so
	$(MKOCTFILE) -I.. $< -L$(LIBDIR) -lipdbg-waveformgenerator -o $@

endif

OCTAVE_CONFIG ?= octave-config
OCTDIR        ?= $(shell $(OCTAVE_CONFIG) -p LOCALOCTFILEDIR)

install: all
	$(INSTALL) -d $(DESTDIR)$(OCTDIR)
	$(INSTALL_PROGRAM) WaveformGenerator.oct $(DESTDIR)$(OCTDIR)

uninstall:
	rm -f $(DESTDIR)$(OCTDIR)/WaveformGenerator.oct

clean:
	rm -f WaveformGeneratorCxx_wrap.cxx WaveformGeneratorCxx_wrap.o WaveformGenerator.oct WaveformGenerator.o WaveformGeneratorCxx.o
