# SPDX-FileCopyrightText: The IPDBG authors
# SPDX-License-Identifier: MPL-2.0

# IPDBG WaveformGenerator library (C API + C++ class)
#
#   make            build the library into bin/Release
#                   Linux:   libipdbg-waveformgenerator.so (+ versioned names)
#                   Windows: libipdbg-waveformgenerator.dll and libipdbg-waveformgenerator.dll.a (MinGW-w64, e.g. MSYS2)
#   make library    same as make
#   make test       build bin/Release/test (example program, see test.c)
#   make python     build the Python bindings (make -C python)
#   make octave     build the Octave bindings (make -C octave)
#   make install    install library, headers (include/ipdbg) and pkg-config file ipdbg-waveformgenerator.pc,
#                   see ../common.mk for PREFIX, DESTDIR, ...
#   make uninstall  remove what make install installed
#   make clean      remove build output (not the one of the bindings)

include ../common.mk

# ABI version of the library (soname), independent of the release version
ABI_MAJOR   := 0
ABI_VERSION := $(ABI_MAJOR).1.0

OBJDIR := obj/Release
BINDIR := bin/Release

HEADERS := WaveformGenerator.h WaveformGeneratorCxx.h

CC  ?= gcc
CXX ?= g++

CFLAGS   ?= -O2 -g
CXXFLAGS ?= -O2 -g
override CFLAGS   += -std=gnu11 -Wall -Wextra -MMD -MP
override CXXFLAGS += -std=c++17 -Wall -Wextra -MMD -MP

OBJS := $(OBJDIR)/WaveformGenerator.o $(OBJDIR)/WaveformGeneratorCxx.o
PC   := ipdbg-waveformgenerator.pc

ifeq ($(OS),Windows_NT)
    LIB     := $(BINDIR)/libipdbg-waveformgenerator.dll
    IMPLIB  := $(BINDIR)/libipdbg-waveformgenerator.dll.a
    TEST    := $(BINDIR)/test.exe
    LIBS    := -lws2_32
    OUTPUTS := $(LIB) $(IMPLIB) $(TEST)
    # the DLL exports its functions, programs using it import them
    $(OBJS): override CPPFLAGS += -DEXPORT
else
    LIBNAME := libipdbg-waveformgenerator.so
    SONAME  := $(LIBNAME).$(ABI_MAJOR)
    REAL    := $(LIBNAME).$(ABI_VERSION)
    LIB     := $(BINDIR)/$(LIBNAME)
    TEST    := $(BINDIR)/test
    OUTPUTS := $(BINDIR)/$(LIBNAME) $(BINDIR)/$(SONAME) $(BINDIR)/$(REAL) $(TEST)
    override CFLAGS   += -fPIC
    override CXXFLAGS += -fPIC
endif

.PHONY: all library test python octave install uninstall clean

all: $(LIB)

library: all

test: $(TEST)

python octave:
	$(MAKE) -C $@

ifeq ($(OS),Windows_NT)

$(LIB): $(OBJS) | $(BINDIR)
	$(CXX) -shared -Wl,--out-implib,$(IMPLIB) $(LDFLAGS) $^ $(LIBS) -o $@

# the DLL is found because test.exe is in the same directory
$(TEST): $(OBJDIR)/test.o $(LIB)
	$(CC) $< $(LDFLAGS) -L$(BINDIR) -lipdbg-waveformgenerator -o $@

install: all
	$(INSTALL) -d $(DESTDIR)$(bindir) $(DESTDIR)$(libdir) $(DESTDIR)$(includedir)/ipdbg $(DESTDIR)$(pkgconfigdir)
	$(INSTALL_PROGRAM) $(LIB) $(DESTDIR)$(bindir)
	$(INSTALL_DATA) $(IMPLIB) $(DESTDIR)$(libdir)
	$(INSTALL_DATA) $(HEADERS) $(DESTDIR)$(includedir)/ipdbg
	$(write_pc) > $(DESTDIR)$(pkgconfigdir)/$(PC)

uninstall:
	rm -f $(DESTDIR)$(bindir)/$(notdir $(LIB)) $(DESTDIR)$(libdir)/$(notdir $(IMPLIB))
	rm -f $(addprefix $(DESTDIR)$(includedir)/ipdbg/,$(HEADERS)) $(DESTDIR)$(pkgconfigdir)/$(PC)

else

$(BINDIR)/$(REAL): $(OBJS) | $(BINDIR)
	$(CXX) -shared -Wl,-soname,$(SONAME) $(LDFLAGS) $^ $(LIBS) -o $@

$(BINDIR)/$(SONAME): $(BINDIR)/$(REAL)
	ln -sf $(REAL) $@

$(BINDIR)/$(LIBNAME): $(BINDIR)/$(SONAME)
	ln -sf $(SONAME) $@

# rpath: find the library next to the example program, no LD_LIBRARY_PATH needed
# (the example is not installed)
$(TEST): $(OBJDIR)/test.o $(LIB)
	$(CC) $< $(LDFLAGS) -L$(BINDIR) -lipdbg-waveformgenerator -Wl,-rpath,'$$ORIGIN' -o $@

install: all
	$(INSTALL) -d $(DESTDIR)$(libdir) $(DESTDIR)$(includedir)/ipdbg $(DESTDIR)$(pkgconfigdir)
	$(INSTALL_PROGRAM) $(BINDIR)/$(REAL) $(DESTDIR)$(libdir)
	ln -sf $(REAL) $(DESTDIR)$(libdir)/$(SONAME)
	ln -sf $(SONAME) $(DESTDIR)$(libdir)/$(LIBNAME)
	$(INSTALL_DATA) $(HEADERS) $(DESTDIR)$(includedir)/ipdbg
	$(write_pc) > $(DESTDIR)$(pkgconfigdir)/$(PC)

uninstall:
	rm -f $(addprefix $(DESTDIR)$(libdir)/,$(REAL) $(SONAME) $(LIBNAME))
	rm -f $(addprefix $(DESTDIR)$(includedir)/ipdbg/,$(HEADERS)) $(DESTDIR)$(pkgconfigdir)/$(PC)

endif

# pkg-config file, written by make install with the install directories.
# libdir and includedir relative to prefix if they are below it, so that
# pkgconf can relocate the files (default on Windows, --define-prefix)
pc_rel = $(patsubst $(prefix)/%,$${prefix}/%,$(1))
write_pc = printf '%s\n' \
    'prefix=$(prefix)' \
    'libdir=$(call pc_rel,$(libdir))' \
    'includedir=$(call pc_rel,$(includedir))' \
    '' \
    'Name: ipdbg-waveformgenerator' \
    'Description: IPDBG WaveformGenerator: control of an IPDBG Waveform Generator core' \
    'Version: $(VERSION)' \
    'URL: https://github.com/IPDBG/IPDBG' \
    'Libs: -L$${libdir} -lipdbg-waveformgenerator' \
    $(if $(LIBS),'Libs.private: $(LIBS)') \
    'Cflags: -I$${includedir}'

$(OBJDIR)/%.o: %.c | $(OBJDIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

$(OBJDIR)/%.o: %.cpp | $(OBJDIR)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $< -o $@

$(OBJDIR) $(BINDIR):
	mkdir -p $@

clean:
	rm -f $(OBJS) $(OBJS:.o=.d) $(OBJDIR)/test.o $(OBJDIR)/test.d $(OUTPUTS)

-include $(OBJS:.o=.d) $(OBJDIR)/test.d
