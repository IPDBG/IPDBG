# SPDX-FileCopyrightText: The IPDBG authors
# SPDX-License-Identifier: MPL-2.0

# Python bindings for IPDBG WaveformGenerator
#
#   make          build WaveformGenerator.py and the extension module _WaveformGenerator
#                 Linux:   _WaveformGenerator.so, links libipdbg-waveformgenerator.so (builds the library first if needed)
#                 Windows: _WaveformGenerator<suffix>.pyd with the library compiled in (MinGW-w64 and the
#                          MSYS2 Python; <suffix> from python3-config --extension-suffix)
#   make install  install WaveformGenerator.py and the module into the site-packages of python3 under
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

WaveformGeneratorCxx_wrap.cxx WaveformGenerator.py: ../WaveformGeneratorCxx.i ../WaveformGeneratorCxx.h
	$(SWIG) -c++ -python -I.. -o WaveformGeneratorCxx_wrap.cxx $<

ifeq ($(OS),Windows_NT)

# Windows: the library is compiled into the module, so no DLL has to be found at runtime.
# Extensions have to be linked against libpython on Windows, hence --embed.
MODULE := _WaveformGenerator$(shell $(PYTHON3_CONFIG) --extension-suffix)
OBJS   := WaveformGeneratorCxx_wrap.o WaveformGenerator.o WaveformGeneratorCxx.o

override CPPFLAGS += -I.. -DIPDBG_STATIC $(shell $(PYTHON3_CONFIG) --includes)
override CFLAGS   += -std=gnu11
override CXXFLAGS += -std=c++17

all: $(MODULE)

WaveformGeneratorCxx_wrap.o: WaveformGeneratorCxx_wrap.cxx
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $< -o $@

WaveformGenerator.o: ../WaveformGenerator.c ../WaveformGenerator.h
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

WaveformGeneratorCxx.o: ../WaveformGeneratorCxx.cpp ../WaveformGeneratorCxx.h ../WaveformGenerator.h
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $< -o $@

$(MODULE): $(OBJS)
	$(CXX) -shared $^ $(LDFLAGS) $(shell $(PYTHON3_CONFIG) --ldflags --embed) -lws2_32 -o $@

else

MODULE := _WaveformGenerator.so

override CXXFLAGS += -std=c++17 -fPIC -I.. $(shell $(PYTHON3_CONFIG) --includes)
override LDFLAGS  += -L$(LIBDIR)

all: $(MODULE)

# always ask the library Makefile, relink only if the library changed
$(LIBDIR)/libipdbg-waveformgenerator.so: FORCE
	$(MAKE) -C ..

WaveformGeneratorCxx_wrap.o: WaveformGeneratorCxx_wrap.cxx
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $< -o $@

$(MODULE): WaveformGeneratorCxx_wrap.o $(LIBDIR)/libipdbg-waveformgenerator.so
	$(CXX) -shared $< $(LDFLAGS) -lipdbg-waveformgenerator -o $@

endif

# site-packages (platlib) of python3 with PREFIX as base, e.g. /usr/local/lib64/python3.13/site-packages
# (scheme posix_prefix). Debian and Ubuntu use dist-packages instead: set PYTHONDIR there,
# e.g. PYTHONDIR=/usr/local/lib/python3.12/dist-packages
PYTHON3   ?= python3
PYTHONDIR ?= $(shell $(PYTHON3) -c "import sysconfig; print(sysconfig.get_path('platlib', 'posix_prefix', vars={'base': '$(prefix)', 'platbase': '$(exec_prefix)'}))")

install: all
	$(INSTALL) -d $(DESTDIR)$(PYTHONDIR)
	$(INSTALL_DATA) WaveformGenerator.py $(DESTDIR)$(PYTHONDIR)
	$(INSTALL_PROGRAM) $(MODULE) $(DESTDIR)$(PYTHONDIR)

uninstall:
	rm -f $(DESTDIR)$(PYTHONDIR)/WaveformGenerator.py $(DESTDIR)$(PYTHONDIR)/$(MODULE)

clean:
	rm -f WaveformGeneratorCxx_wrap.cxx WaveformGenerator.py $(MODULE) WaveformGeneratorCxx_wrap.o WaveformGenerator.o WaveformGeneratorCxx.o
	rm -rf __pycache__
