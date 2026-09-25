# Octave bindings for IPDBG WaveformGenerator
#
#   make          build WaveformGenerator.oct
#                 Linux:   links libWaveformGenerator.so (builds the library first if needed)
#                 Windows: compiles the library into WaveformGenerator.oct (MinGW-w64, e.g. MSYS2)
#   make clean    remove generated files

SWIG      ?= swig
MKOCTFILE ?= mkoctfile

LIBDIR := ../bin/Release

.PHONY: all clean FORCE

all: WaveformGenerator.oct

# always ask the library Makefile, relink only if the library changed
$(LIBDIR)/libWaveformGenerator.so: FORCE
	$(MAKE) -C ..

WaveformGeneratorCxx_wrap.cxx: ../WaveformGeneratorCxx.i ../WaveformGeneratorCxx.h
	$(SWIG) -c++ -octave -I.. -o $@ $<

ifeq ($(OS),Windows_NT)

# Windows: the library is compiled into WaveformGenerator.oct, so no DLL has to be found at runtime
LIBSRCS := ../WaveformGenerator.c ../WaveformGeneratorCxx.cpp

WaveformGenerator.oct: WaveformGeneratorCxx_wrap.cxx $(LIBSRCS) ../WaveformGenerator.h
	$(MKOCTFILE) -I.. -DIPDBG_STATIC WaveformGeneratorCxx_wrap.cxx $(LIBSRCS) -lws2_32 -o $@

else

# rpath: find libWaveformGenerator.so relative to WaveformGenerator.oct, no LD_LIBRARY_PATH needed.
# mkoctfile runs the linker through a shell again, hence the escaped \$ORIGIN.
WaveformGenerator.oct: WaveformGeneratorCxx_wrap.cxx $(LIBDIR)/libWaveformGenerator.so
	$(MKOCTFILE) -I.. $< -L$(LIBDIR) -lWaveformGenerator -Wl,-rpath,'\$$ORIGIN/$(LIBDIR)' -o $@

endif

clean:
	rm -f WaveformGeneratorCxx_wrap.cxx WaveformGeneratorCxx_wrap.o WaveformGenerator.oct WaveformGenerator.o WaveformGeneratorCxx.o
