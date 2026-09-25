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

/* export/import macro of the headers, not needed by SWIG */
#define API

%include "BusAccessCxx.h"

%extend IpdbgBusAccess {
    %template(write)            write<uint64_t, uint64_t>;
    %template(read)             read<uint64_t, uint64_t>;
    %template(setMiscellaneous) setMiscellaneous<uint64_t>;
    %template(setStrobe)        setStrobe<uint64_t>;
}
