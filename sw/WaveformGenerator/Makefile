# IPDBG WaveformGenerator library (C API + C++ class)
#
#   make          build the library into bin/Release
#                 Linux:   libWaveformGenerator.so (+ versioned names)
#                 Windows: libWaveformGenerator.dll and libWaveformGenerator.dll.a (MinGW-w64, e.g. MSYS2)
#   make test     build bin/Release/test (example program, see test.c)
#   make clean    remove build output

VERSION_MAJOR := 0
VERSION       := $(VERSION_MAJOR).1.0

OBJDIR := obj/Release
BINDIR := bin/Release

CC  ?= gcc
CXX ?= g++

CFLAGS   ?= -O2 -g
CXXFLAGS ?= -O2 -g
override CFLAGS   += -std=gnu11 -Wall -Wextra -MMD -MP
override CXXFLAGS += -std=c++17 -Wall -Wextra -MMD -MP

OBJS := $(OBJDIR)/WaveformGenerator.o $(OBJDIR)/WaveformGeneratorCxx.o

ifeq ($(OS),Windows_NT)
    LIB     := $(BINDIR)/libWaveformGenerator.dll
    IMPLIB  := $(BINDIR)/libWaveformGenerator.dll.a
    TEST    := $(BINDIR)/test.exe
    LIBS    := -lws2_32
    OUTPUTS := $(LIB) $(IMPLIB) $(TEST)
    # the DLL exports its functions, programs using it import them
    $(OBJS): override CPPFLAGS += -DEXPORT
else
    LIBNAME := libWaveformGenerator.so
    SONAME  := $(LIBNAME).$(VERSION_MAJOR)
    REAL    := $(LIBNAME).$(VERSION)
    LIB     := $(BINDIR)/$(LIBNAME)
    TEST    := $(BINDIR)/test
    OUTPUTS := $(BINDIR)/$(LIBNAME) $(BINDIR)/$(SONAME) $(BINDIR)/$(REAL) $(TEST)
    override CFLAGS   += -fPIC
    override CXXFLAGS += -fPIC
endif

.PHONY: all test clean

all: $(LIB)

test: $(TEST)

ifeq ($(OS),Windows_NT)

$(LIB): $(OBJS) | $(BINDIR)
	$(CXX) -shared -Wl,--out-implib,$(IMPLIB) $(LDFLAGS) $^ $(LIBS) -o $@

# the DLL is found because test.exe is in the same directory
$(TEST): $(OBJDIR)/test.o $(LIB)
	$(CC) $< $(LDFLAGS) -L$(BINDIR) -lWaveformGenerator -o $@

else

$(BINDIR)/$(REAL): $(OBJS) | $(BINDIR)
	$(CXX) -shared -Wl,-soname,$(SONAME) $(LDFLAGS) $^ $(LIBS) -o $@

$(BINDIR)/$(SONAME): $(BINDIR)/$(REAL)
	ln -sf $(REAL) $@

$(BINDIR)/$(LIBNAME): $(BINDIR)/$(SONAME)
	ln -sf $(SONAME) $@

# rpath: find the library next to the program, no LD_LIBRARY_PATH needed
$(TEST): $(OBJDIR)/test.o $(LIB)
	$(CC) $< $(LDFLAGS) -L$(BINDIR) -lWaveformGenerator -Wl,-rpath,'$$ORIGIN' -o $@

endif

$(OBJDIR)/%.o: %.c | $(OBJDIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

$(OBJDIR)/%.o: %.cpp | $(OBJDIR)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $< -o $@

$(OBJDIR) $(BINDIR):
	mkdir -p $@

clean:
	rm -f $(OBJS) $(OBJS:.o=.d) $(OBJDIR)/test.o $(OBJDIR)/test.d $(OUTPUTS)

-include $(OBJS:.o=.d) $(OBJDIR)/test.d
