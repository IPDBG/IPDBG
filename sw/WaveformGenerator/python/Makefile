# Python bindings for IPDBG WaveformGenerator
#
#   make          build WaveformGenerator.py and the extension module _WaveformGenerator
#                 Linux:   _WaveformGenerator.so, links libWaveformGenerator.so (builds the library first if needed)
#                 Windows: _WaveformGenerator<suffix>.pyd with the library compiled in (MinGW-w64 and the
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
# find libWaveformGenerator.so relative to _WaveformGenerator.so, no LD_LIBRARY_PATH needed
override LDFLAGS  += -L$(LIBDIR) -Wl,-rpath,'$$ORIGIN/$(LIBDIR)'

all: $(MODULE)

# always ask the library Makefile, relink only if the library changed
$(LIBDIR)/libWaveformGenerator.so: FORCE
	$(MAKE) -C ..

WaveformGeneratorCxx_wrap.o: WaveformGeneratorCxx_wrap.cxx
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $< -o $@

$(MODULE): WaveformGeneratorCxx_wrap.o $(LIBDIR)/libWaveformGenerator.so
	$(CXX) -shared $< $(LDFLAGS) -lWaveformGenerator -o $@

endif

clean:
	rm -f WaveformGeneratorCxx_wrap.cxx WaveformGenerator.py $(MODULE) WaveformGeneratorCxx_wrap.o WaveformGenerator.o WaveformGeneratorCxx.o
	rm -rf __pycache__
