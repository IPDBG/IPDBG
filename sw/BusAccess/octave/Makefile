# Octave bindings for IPDBG BusAccess
#
#   make          build BusAccess.oct (builds the library first if needed)
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

# rpath: find libBusAccess.so relative to BusAccess.oct, no LD_LIBRARY_PATH needed.
# mkoctfile runs the linker through a shell again, hence the escaped \$ORIGIN.
BusAccess.oct: BusAccessCxx_wrap.cxx $(LIBDIR)/libBusAccess.so
	$(MKOCTFILE) -I.. $< -L$(LIBDIR) -lBusAccess -Wl,-rpath,'\$$ORIGIN/$(LIBDIR)' -o $@

clean:
	rm -f BusAccessCxx_wrap.cxx BusAccessCxx_wrap.o BusAccess.oct
