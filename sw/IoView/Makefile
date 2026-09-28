# SPDX-FileCopyrightText: The IPDBG authors
# SPDX-License-Identifier: MPL-2.0

# IoView: GUI for the IoProbe core (wxWidgets)
#
#   make          build bin/Release/IoView
#                 Linux:   links libBusAccess.so (builds the library first if needed)
#                 Windows: bin/Release/IoView.exe with the library compiled in
#                          (MinGW-w64 and wxWidgets from MSYS2)
#   make clean    remove build output
#
# wxWidgets is found with wx-config; select another one with
# e.g. make WX_CONFIG=wx-config-gtk3

WX_CONFIG ?= wx-config

OBJDIR := obj/Release
BINDIR := bin/Release
BADIR  := ../BusAccess
LIBDIR := $(BADIR)/bin/Release

CC  ?= gcc
CXX ?= g++

CFLAGS   ?= -O2 -g
CXXFLAGS ?= -O2 -g
override CPPFLAGS += -I$(BADIR)
override CFLAGS   += -std=gnu11 -Wall -MMD -MP
override CXXFLAGS += -std=c++17 -Wall -MMD -MP $(shell $(WX_CONFIG) --cxxflags)
WX_LIBS := $(shell $(WX_CONFIG) --libs core,base)

SRCS := ConnectionDialog.cpp IOViewApp.cpp IOViewMain.cpp IOViewPanel.cpp IOViewProtocol.cpp led.cpp
OBJS := $(SRCS:%.cpp=$(OBJDIR)/%.o)

.PHONY: all clean FORCE

ifeq ($(OS),Windows_NT)

# Windows: the library is compiled into IoView.exe, so no DLL has to be found at runtime
TARGET := $(BINDIR)/IoView.exe
override CPPFLAGS += -DIPDBG_STATIC
OBJS   += $(OBJDIR)/BusAccess.o $(OBJDIR)/resource.o

all: $(TARGET)

$(OBJDIR)/BusAccess.o: $(BADIR)/BusAccess.c | $(OBJDIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

# icon and manifest (visual styles) of wxWidgets
$(OBJDIR)/resource.o: resource.rc | $(OBJDIR)
	$(shell $(WX_CONFIG) --rescomp) -i $< -o $@ -O coff

$(TARGET): $(OBJS) | $(BINDIR)
	$(CXX) $(LDFLAGS) $^ $(WX_LIBS) -lws2_32 -o $@

else

TARGET := $(BINDIR)/IoView

all: $(TARGET)

# always ask the library Makefile, relink only if the library changed
$(LIBDIR)/libBusAccess.so: FORCE
	$(MAKE) -C $(BADIR)

# rpath: find libBusAccess.so relative to IoView, no LD_LIBRARY_PATH needed
$(TARGET): $(OBJS) $(LIBDIR)/libBusAccess.so | $(BINDIR)
	$(CXX) $(LDFLAGS) $(OBJS) -L$(LIBDIR) -lBusAccess -Wl,-rpath,'$$ORIGIN/../../$(LIBDIR)' $(WX_LIBS) -o $@

endif

$(OBJDIR)/%.o: %.cpp | $(OBJDIR)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $< -o $@

$(OBJDIR) $(BINDIR):
	mkdir -p $@

clean:
	rm -rf $(OBJDIR) $(BINDIR)

-include $(OBJS:.o=.d)
