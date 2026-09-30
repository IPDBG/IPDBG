# SPDX-FileCopyrightText: The IPDBG authors
# SPDX-License-Identifier: MPL-2.0

# UartBridge: TCP <-> serial port bridge for the IPDBG UART transport
#
#   make          build bin/Release/UartBridge (UartBridge.exe on Windows)
#                 needs libserialport, found with pkg-config
#   make clean    remove build output

OBJDIR := obj/Release
BINDIR := bin/Release

CXX        ?= g++
PKG_CONFIG ?= pkg-config

CXXFLAGS ?= -O2 -g
override CXXFLAGS += -std=c++17 -Wall -Wextra -MMD -MP $(shell $(PKG_CONFIG) --cflags libserialport)
LIBS := $(shell $(PKG_CONFIG) --libs libserialport)

ifeq ($(OS),Windows_NT)
    TARGET := $(BINDIR)/UartBridge.exe
    # inet_pton needs Windows Vista or later
    override CPPFLAGS += -D_WIN32_WINNT=0x0601
    LIBS += -lws2_32
else
    TARGET := $(BINDIR)/UartBridge
    override CXXFLAGS += -pthread
    LIBS += -pthread
endif

OBJS := $(OBJDIR)/UartBridge.o

.PHONY: all clean

all: $(TARGET)

$(TARGET): $(OBJS) | $(BINDIR)
	$(CXX) $(LDFLAGS) $^ $(LIBS) -o $@

$(OBJDIR)/%.o: %.cpp | $(OBJDIR)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $< -o $@

$(OBJDIR) $(BINDIR):
	mkdir -p $@

clean:
	rm -rf $(OBJDIR) $(BINDIR)

-include $(OBJS:.o=.d)
