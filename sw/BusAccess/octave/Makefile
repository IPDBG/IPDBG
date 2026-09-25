# Octave bindings for IPDBG BusAccess
#
#   make          build BusAccess.oct
#                 Linux:   links libBusAccess.so (builds the library first if needed)
#                 Windows: compiles the library into BusAccess.oct (MinGW-w64, e.g. MSYS2)
#   make clean    remove generated files

SWIG      ?= swig
MKOCTFILE ?= mkoctfile

LIBDIR := ../bin/Release

.PHONY: all clean FORCE

all: BusAccess.oct

# always ask the library Makefile, relink only if the library changed
$(LIBDIR)/libBusAccess.so: FORCE
	$(MAKE) -C ..

BusAccessCxx_wrap.cxx: ../BusAccessCxx.i ../BusAccessCxx.h ../BusAccessCxx.tpp
	$(SWIG) -c++ -octave -I.. -o $@ $<

ifeq ($(OS),Windows_NT)

# Windows: the library is compiled into BusAccess.oct, so no DLL has to be found at runtime
LIBSRCS := ../BusAccess.c ../BusAccessCxx.cpp

BusAccess.oct: BusAccessCxx_wrap.cxx $(LIBSRCS) ../BusAccess.h
	$(MKOCTFILE) -I.. -DIPDBG_STATIC BusAccessCxx_wrap.cxx $(LIBSRCS) -lws2_32 -o $@

else

# rpath: find libBusAccess.so relative to BusAccess.oct, no LD_LIBRARY_PATH needed.
# mkoctfile runs the linker through a shell again, hence the escaped \$ORIGIN.
BusAccess.oct: BusAccessCxx_wrap.cxx $(LIBDIR)/libBusAccess.so
	$(MKOCTFILE) -I.. $< -L$(LIBDIR) -lBusAccess -Wl,-rpath,'\$$ORIGIN/$(LIBDIR)' -o $@

endif

clean:
	rm -f BusAccessCxx_wrap.cxx BusAccessCxx_wrap.o BusAccess.oct BusAccess.o BusAccessCxx.o
