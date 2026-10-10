# SPDX-FileCopyrightText: The IPDBG authors
# SPDX-License-Identifier: MPL-2.0

# UartBridge: TCP <-> serial port bridge for the IPDBG UART transport
#
#   make            build bin/Release/UartBridge (UartBridge.exe on Windows)
#                   needs libserialport, found with pkg-config
#   make install    install it as $(bindir)/ipdbg-uartbridge, see ../common.mk
#                   for PREFIX, DESTDIR etc.
#   make uninstall  remove the installed file
#   make clean      remove build output

include ../common.mk

OBJDIR := obj/Release
BINDIR := bin/Release

CXX        ?= g++
PKG_CONFIG ?= pkg-config

CXXFLAGS ?= -O2 -g
override CXXFLAGS += -std=c++17 -Wall -Wextra -MMD -MP $(shell $(PKG_CONFIG) --cflags libserialport)
override CPPFLAGS += -DIPDBG_VERSION='"$(VERSION)"'
LIBS = $(shell $(PKG_CONFIG) --libs libserialport)

ifeq ($(OS),Windows_NT)
    EXE := .exe
    # inet_pton needs Windows Vista or later
    override CPPFLAGS += -D_WIN32_WINNT=0x0601
    LIBS += -lws2_32
else
    EXE :=
    override CXXFLAGS += -pthread
    LIBS += -pthread
endif
TARGET    := $(BINDIR)/UartBridge$(EXE)
INSTALLED := $(bindir)/ipdbg-uartbridge$(EXE)

OBJS := $(OBJDIR)/UartBridge.o

.PHONY: all clean install uninstall

all: $(TARGET)

$(TARGET): $(OBJS) | $(BINDIR)
	$(CXX) $(LDFLAGS) $^ $(LIBS) -o $@

# rebuilt when the version changes
$(OBJDIR)/UartBridge.o: ../VERSION

$(OBJDIR)/%.o: %.cpp | $(OBJDIR)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $< -o $@

$(OBJDIR) $(BINDIR):
	mkdir -p $@

install: all
	$(INSTALL) -d $(DESTDIR)$(bindir)
	$(INSTALL_PROGRAM) $(TARGET) $(DESTDIR)$(INSTALLED)

uninstall:
	rm -f $(DESTDIR)$(INSTALLED)

clean:
	rm -rf $(OBJDIR) $(BINDIR)

-include $(OBJS:.o=.d)
