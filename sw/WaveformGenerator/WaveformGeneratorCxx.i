/* SWIG interface for the IPDBG WaveformGenerator C++ class, shared by the Python and Octave bindings. */
%module WaveformGenerator

%include <std_string.i>
%include <stdint.i>
%include <exception.i>

%{
#include <cmath>
#include <cstdint>
#include <string>
#include <vector>
#include "WaveformGeneratorCxx.h"
%}

/* translate C++ exceptions into Python RuntimeError / Octave error */
%exception {
    try {
        $action
    } catch (const std::exception &e) {
        SWIG_exception(SWIG_RuntimeError, e.what());
    }
}

/* samples for write(): a sequence of integers */
#ifdef SWIGPYTHON
/* any sequence or iterable of integers: list, tuple, range, numpy array, ... */
%typemap(in) const std::vector<int64_t> &samples (std::vector<int64_t> temp) {
    PyObject *seq = PySequence_Fast($input, "samples must be a sequence of integers");
    if (!seq)
        SWIG_fail;
    const Py_ssize_t n = PySequence_Fast_GET_SIZE(seq);
    temp.reserve(n);
    for (Py_ssize_t i = 0; i < n; ++i) {
        PyObject *index = PyNumber_Index(PySequence_Fast_GET_ITEM(seq, i)); /* rejects floats */
        if (!index) {
            Py_DECREF(seq);
            SWIG_fail;
        }
        int overflow = 0;
        const long long value = PyLong_AsLongLongAndOverflow(index, &overflow);
        Py_DECREF(index);
        if (overflow) {
            Py_DECREF(seq);
            PyErr_Format(PyExc_OverflowError, "sample %zd does not fit into 64 bit (signed)", i);
            SWIG_fail;
        }
        if (value == -1 && PyErr_Occurred()) {
            Py_DECREF(seq);
            SWIG_fail;
        }
        temp.push_back(value);
    }
    Py_DECREF(seq);
    $1 = &temp;
}
#endif

#ifdef SWIGOCTAVE
/* a real vector (double, single or integer type) with integer values */
%typemap(in) const std::vector<int64_t> &samples (std::vector<int64_t> temp) {
    const octave_value &in = $input;
    if (in.iscomplex() || !(in.isinteger() || in.is_double_type() || in.is_single_type())) {
        SWIG_exception(SWIG_TypeError, "samples must be a real numeric vector");
    }
    if (in.isinteger() && in.is_uint64_type()) {
        const uint64NDArray a = in.uint64_array_value();
        temp.reserve(a.numel());
        for (octave_idx_type i = 0; i < a.numel(); ++i) {
            const uint64_t value = a(i).value();
            if (value > static_cast<uint64_t>(INT64_MAX)) {
                SWIG_exception(SWIG_OverflowError, ("sample " + std::to_string(i) +
                                                    " does not fit into 64 bit (signed)").c_str());
            }
            temp.push_back(static_cast<int64_t>(value));
        }
    } else if (in.isinteger()) {
        const int64NDArray a = in.int64_array_value(); /* exact for all other integer types */
        temp.reserve(a.numel());
        for (octave_idx_type i = 0; i < a.numel(); ++i)
            temp.push_back(a(i).value());
    } else {
        const NDArray a = in.array_value();
        temp.reserve(a.numel());
        for (octave_idx_type i = 0; i < a.numel(); ++i) {
            const double value = a(i);
            if (std::floor(value) != value) {
                SWIG_exception(SWIG_ValueError, ("sample " + std::to_string(i) +
                                                 " is not an integer").c_str());
            }
            /* 2^63 is exactly representable as double, INT64_MAX is not */
            if (value < -9223372036854775808.0 || value >= 9223372036854775808.0) {
                SWIG_exception(SWIG_OverflowError, ("sample " + std::to_string(i) +
                                                    " does not fit into 64 bit (signed)").c_str());
            }
            temp.push_back(static_cast<int64_t>(value));
        }
    }
    $1 = &temp;
}
#endif

/* export/import macro of the headers, not needed by SWIG */
#define API

%include "WaveformGeneratorCxx.h"
