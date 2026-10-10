# SPDX-FileCopyrightText: The IPDBG authors
# SPDX-License-Identifier: MPL-2.0

# Builds and installs the host software, see README.md. Each project can also
# be built on its own in its directory. CoSim is not part of it.
#
#   make                 libraries, UartBridge and IoView
#   make install         install them, see common.mk for PREFIX, DESTDIR etc.
#   make uninstall       remove the installed files
#   make python octave   the Python and Octave bindings (optional), only them
#                        and the libraries; everything: make all python octave
#   make install-python install-octave, make uninstall-python uninstall-octave
#   make clean           remove build output of all projects
#
# Variables given on the command line (PREFIX=..., DESTDIR=...) are passed on
# to the projects.

LIBS     := BusAccess WaveformGenerator
PROGRAMS := UartBridge IoView
PYTHON   := $(LIBS:%=%/python)
OCTAVE   := $(LIBS:%=%/octave)

.PHONY: all install uninstall clean python octave \
	install-python install-octave uninstall-python uninstall-octave \
	$(LIBS) $(PROGRAMS) $(PYTHON) $(OCTAVE)

all: $(LIBS) $(PROGRAMS)
python: $(PYTHON)
octave: $(OCTAVE)

# IoView and the bindings use BusAccess or WaveformGenerator from the source
# tree: build the library first, so that two makes never build it at once
IoView: BusAccess
BusAccess/python BusAccess/octave: BusAccess
WaveformGenerator/python WaveformGenerator/octave: WaveformGenerator

$(LIBS) $(PROGRAMS) $(PYTHON) $(OCTAVE):
	$(MAKE) -C $@

# run_each TARGET, DIRS: make TARGET in each of DIRS, one after the other
run_each = $(foreach d,$(2),$(MAKE) -C $(d) $(1) &&) true

install: all
	$(call run_each,install,$(LIBS) $(PROGRAMS))

uninstall:
	$(call run_each,uninstall,$(LIBS) $(PROGRAMS))

install-python: python
	$(call run_each,install,$(PYTHON))

install-octave: octave
	$(call run_each,install,$(OCTAVE))

uninstall-python:
	$(call run_each,uninstall,$(PYTHON))

uninstall-octave:
	$(call run_each,uninstall,$(OCTAVE))

clean:
	$(call run_each,clean,$(LIBS) $(PROGRAMS) $(PYTHON) $(OCTAVE))
