// SPDX-FileCopyrightText: The IPDBG authors
// SPDX-License-Identifier: MPL-2.0

/* SWIG interface for the IPDBG BusAccess C++ class, shared by the Python and Octave bindings. */
%module BusAccess

%include <std_string.i>
%include <stdint.i>
%include <exception.i>

%{
#include "BusAccessCxx.h"
%}

/* translate C++ exceptions into Python RuntimeError / Octave error */
%exception {
    try {
        $action
    } catch (const std::exception &e) {
        SWIG_exception(SWIG_RuntimeError, e.what());
    }
}

/* Octave: "x = Module.IpdbgBusAccess" without () gives the class, not an object;
   calling a method on it would pass a null pointer: raise an error instead */
%typemap(check) IpdbgBusAccess *self {
    if (!$1)
        SWIG_exception(SWIG_ValueError, "not an IpdbgBusAccess object, create one with IpdbgBusAccess()");
}

/* export/import macro of the headers, not needed by SWIG */
#define API

/* core types, see getCoreType() (defined in BusAccess.h, which SWIG does not read) */
#define CORE_TYPE_BUS_MASTER 0
#define CORE_TYPE_IOPROBE    1

%include "BusAccessCxx.h"

%extend IpdbgBusAccess {
    %template(write)            write<uint64_t, uint64_t>;
    %template(read)             read<uint64_t, uint64_t>;
    %template(setMiscellaneous) setMiscellaneous<uint64_t>;
    %template(setStrobe)        setStrobe<uint64_t>;
}
