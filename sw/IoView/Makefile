# SPDX-FileCopyrightText: The IPDBG authors
# SPDX-License-Identifier: MPL-2.0

# IoView: GUI for the IoProbe core (wxWidgets)
#
#   make            build bin/Release/IoView
#                   Linux:   links libipdbg-busaccess.so (builds the library
#                            first if needed); to run it from the source tree:
#                            LD_LIBRARY_PATH=../BusAccess/bin/Release bin/Release/IoView
#                   Windows: bin/Release/IoView.exe with the library compiled in
#                            (MinGW-w64 and wxWidgets from MSYS2)
#   make install    install it as $(bindir)/ipdbg-ioview, on Linux with the
#                   desktop file and the icon; see ../common.mk for PREFIX,
#                   DESTDIR etc. Install the library too (make install in
#                   ../BusAccess or in ..).
#   make uninstall  remove the installed files
#   make clean      remove build output
#
# wxWidgets is found with wx-config; select another one with
# e.g. make WX_CONFIG=wx-config-gtk3

include ../common.mk

WX_CONFIG ?= wx-config

OBJDIR := obj/Release
BINDIR := bin/Release
BADIR  := ../BusAccess
LIBDIR := $(BADIR)/bin/Release

CC  ?= gcc
CXX ?= g++

CFLAGS   ?= -O2 -g
CXXFLAGS ?= -O2 -g
override CPPFLAGS += -I$(BADIR) -DIPDBG_VERSION='"$(VERSION)"'
override CFLAGS   += -std=gnu11 -Wall -MMD -MP
override CXXFLAGS += -std=c++17 -Wall -MMD -MP $(shell $(WX_CONFIG) --cxxflags)
WX_LIBS = $(shell $(WX_CONFIG) --libs core,base)

SRCS := ConnectionDialog.cpp IOViewApp.cpp IOViewMain.cpp IOViewPanel.cpp IOViewProtocol.cpp led.cpp
OBJS := $(SRCS:%.cpp=$(OBJDIR)/%.o)

.PHONY: all clean install uninstall FORCE

ifeq ($(OS),Windows_NT)

# Windows: the library is compiled into IoView.exe, so no DLL has to be found at runtime
TARGET    := $(BINDIR)/IoView.exe
INSTALLED := $(bindir)/ipdbg-ioview.exe
override CPPFLAGS += -DIPDBG_STATIC
OBJS   += $(OBJDIR)/BusAccess.o $(OBJDIR)/resource.o

all: $(TARGET)

$(OBJDIR)/BusAccess.o: $(BADIR)/BusAccess.c | $(OBJDIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

# icon and manifest (visual styles) of wxWidgets
$(OBJDIR)/resource.o: resource.rc ipdbg-ioview.ico | $(OBJDIR)
	$(shell $(WX_CONFIG) --rescomp) -i $< -o $@ -O coff

$(TARGET): $(OBJS) | $(BINDIR)
	$(CXX) $(LDFLAGS) $^ $(WX_LIBS) -lws2_32 -o $@

else

TARGET    := $(BINDIR)/IoView
INSTALLED := $(bindir)/ipdbg-ioview
DESKTOP   := $(datadir)/applications/ipdbg-ioview.desktop
ICON      := $(datadir)/icons/hicolor/scalable/apps/ipdbg-ioview.svg

all: $(TARGET)

# always ask the library Makefile, relink only if the library changed
$(LIBDIR)/libipdbg-busaccess.so: FORCE
	$(MAKE) -C $(BADIR)

# no rpath: the installed IoView finds the installed library, in the source
# tree LD_LIBRARY_PATH is needed
$(TARGET): $(OBJS) $(LIBDIR)/libipdbg-busaccess.so | $(BINDIR)
	$(CXX) $(LDFLAGS) $(OBJS) -L$(LIBDIR) -lipdbg-busaccess $(WX_LIBS) -o $@

endif

$(OBJDIR)/%.o: %.cpp | $(OBJDIR)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $< -o $@

# rebuilt when the version changes
$(OBJDIR)/IOViewMain.o: ../VERSION

$(OBJDIR) $(BINDIR):
	mkdir -p $@

install: all
	$(INSTALL) -d $(DESTDIR)$(bindir)
	$(INSTALL_PROGRAM) $(TARGET) $(DESTDIR)$(INSTALLED)
ifneq ($(OS),Windows_NT)
	$(INSTALL) -d $(DESTDIR)$(dir $(DESKTOP)) $(DESTDIR)$(dir $(ICON))
	$(INSTALL_DATA) ipdbg-ioview.desktop $(DESTDIR)$(DESKTOP)
	$(INSTALL_DATA) ipdbg-ioview.svg $(DESTDIR)$(ICON)
endif

uninstall:
	rm -f $(DESTDIR)$(INSTALLED)
ifneq ($(OS),Windows_NT)
	rm -f $(DESTDIR)$(DESKTOP) $(DESTDIR)$(ICON)
endif

clean:
	rm -rf $(OBJDIR) $(BINDIR)

-include $(OBJS:.o=.d)
