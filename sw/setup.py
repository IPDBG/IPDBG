# SPDX-FileCopyrightText: The IPDBG authors
# SPDX-License-Identifier: MPL-2.0
#
# Builds the Python modules BusAccess and WaveformGenerator with SWIG, with
# the library compiled into each module. Metadata in pyproject.toml.

import os
import shutil
import sys

from setuptools import Extension, setup
from setuptools.command.build_ext import build_ext

HERE = os.path.dirname(os.path.abspath(__file__))


def module(name, sources):
    return Extension(
        "_" + name,
        sources=[f"{name}/{name}Cxx.i"] + [f"{name}/{s}" for s in sources],
        include_dirs=[name],
        define_macros=[("IPDBG_STATIC", None)],
        swig_opts=["-c++", f"-I{name}"],
        libraries=["ws2_32"] if sys.platform == "win32" else [],
    )


class BuildExt(build_ext):
    """SWIG writes the Python part of each module into build_temp; copy it
    next to the extension, so that it ends up in the wheel."""

    def build_extensions(self):
        if self.compiler.compiler_type == "msvc":
            for ext in self.extensions:
                ext.extra_compile_args += ["/std:c++17", "/D_CRT_SECURE_NO_WARNINGS"]
        else:
            # C++17 only for the C++ sources: clang rejects it for C
            compile_one = self.compiler._compile

            def _compile(obj, src, ext, cc_args, extra_postargs, pp_opts):
                if src.endswith((".cpp", ".cxx")):
                    extra_postargs = list(extra_postargs) + ["-std=c++17"]
                compile_one(obj, src, ext, cc_args, extra_postargs, pp_opts)

            self.compiler._compile = _compile
        super().build_extensions()

    def run(self):
        os.makedirs(self.build_temp, exist_ok=True)
        for ext in self.extensions:
            ext.swig_opts += ["-outdir", self.build_temp]
        super().run()
        target = HERE if self.inplace else self.build_lib
        for ext in self.extensions:
            name = ext.name.lstrip("_") + ".py"
            shutil.copy(os.path.join(self.build_temp, name), os.path.join(target, name))


setup(
    version=open(os.path.join(HERE, "VERSION")).read().strip(),
    ext_modules=[
        module("BusAccess", ["BusAccess.c", "BusAccessCxx.cpp"]),
        module("WaveformGenerator", ["WaveformGenerator.c", "WaveformGeneratorCxx.cpp"]),
    ],
    cmdclass={"build_ext": BuildExt},
    # only the extensions, no automatic search for Python packages
    packages=[],
    py_modules=[],
)
