# SPDX-FileCopyrightText: The IPDBG authors
# SPDX-License-Identifier: MPL-2.0

# Common settings of the sw Makefiles: release version and install directories.
# Included by every Makefile below sw/; IPDBG_SW is the directory of this file.

IPDBG_SW := $(patsubst %/,%,$(dir $(lastword $(MAKEFILE_LIST))))

# release version of the IPDBG software (sw/VERSION), not the ABI version of the libraries
VERSION := $(shell cat $(IPDBG_SW)/VERSION)

# install directories (GNU conventions), e.g.
#   make install PREFIX=/usr DESTDIR=/tmp/pkgroot
PREFIX      ?= /usr/local
prefix      ?= $(PREFIX)
exec_prefix ?= $(prefix)
bindir      ?= $(exec_prefix)/bin
libdir      ?= $(exec_prefix)/lib
includedir  ?= $(prefix)/include
datarootdir ?= $(prefix)/share
datadir     ?= $(datarootdir)
pkgconfigdir ?= $(libdir)/pkgconfig

INSTALL         ?= install
INSTALL_PROGRAM ?= $(INSTALL) -m 755
INSTALL_DATA    ?= $(INSTALL) -m 644
