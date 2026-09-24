# IPDBG BusAccess library (C API + C++ class)
#
#   make          build bin/Release/libBusAccess.so
#   make clean    remove build output

VERSION_MAJOR := 0
VERSION       := $(VERSION_MAJOR).1.0

LIBNAME := libBusAccess.so
SONAME  := $(LIBNAME).$(VERSION_MAJOR)
REAL    := $(LIBNAME).$(VERSION)

OBJDIR := obj/Release
BINDIR := bin/Release

CC  ?= gcc
CXX ?= g++

CFLAGS   ?= -O2 -g
CXXFLAGS ?= -O2 -g
override CFLAGS   += -std=gnu11 -Wall -Wextra -fPIC -MMD -MP
override CXXFLAGS += -std=c++17 -Wall -Wextra -fPIC -MMD -MP

OBJS := $(OBJDIR)/BusAccess.o $(OBJDIR)/BusAccessCxx.o

.PHONY: all clean

all: $(BINDIR)/$(LIBNAME)

$(BINDIR)/$(REAL): $(OBJS) | $(BINDIR)
	$(CXX) -shared -Wl,-soname,$(SONAME) $(LDFLAGS) $^ -o $@

$(BINDIR)/$(SONAME): $(BINDIR)/$(REAL)
	ln -sf $(REAL) $@

$(BINDIR)/$(LIBNAME): $(BINDIR)/$(SONAME)
	ln -sf $(SONAME) $@

$(OBJDIR)/%.o: %.c | $(OBJDIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

$(OBJDIR)/%.o: %.cpp | $(OBJDIR)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $< -o $@

$(OBJDIR) $(BINDIR):
	mkdir -p $@

clean:
	rm -f $(OBJS) $(OBJS:.o=.d) $(BINDIR)/$(LIBNAME) $(BINDIR)/$(SONAME) $(BINDIR)/$(REAL)

-include $(OBJS:.o=.d)
