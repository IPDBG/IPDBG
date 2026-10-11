# IPDBG host software

| Directory | Contents | Installed as |
|-----------|----------|--------------|
| [`BusAccess`](BusAccess/README.md) | BusAccess library with C++, Python and Octave bindings | `libipdbg-busaccess`, `ipdbg-busaccess.pc`, Python/Octave module `BusAccess` |
| [`WaveformGenerator`](WaveformGenerator/README.md) | WaveformGenerator library with C++, Python and Octave bindings | `libipdbg-waveformgenerator`, `ipdbg-waveformgenerator.pc`, Python/Octave module `WaveformGenerator` |
| [`IoView`](IoView/README.md) | IoView host application for the IoProbe core | `ipdbg-ioview` |
| [`UartBridge`](UartBridge/README.md) | TCP to serial port bridge for the UART transport | `ipdbg-uartbridge` |
| [`CoSim`](CoSim/README.md) | Co-simulation with GHDL, try IPDBG without hardware | not installed |

The version of the host software is in [`VERSION`](VERSION).

## Building

Requirements: GCC/G++ with C++17 support, GNU make, pkg-config, and

* UartBridge: [libserialport](https://sigrok.org/wiki/Libserialport)
* IoView: wxWidgets 3.0 or later
* Python bindings: SWIG, Python 3 with development files
* Octave bindings: SWIG, GNU Octave with development files (`mkoctfile`)

The READMEs of the projects list the package names.

```sh
cd sw
make                 # libraries, UartBridge and IoView
make python octave   # the bindings, optional
```

Named targets replace the default target: `make python octave` builds the
bindings and the libraries, but not UartBridge and IoView; `make all python
octave` builds everything. The same holds for `make install-python
install-octave`.

Each project can also be built on its own with `make` in its directory, see
its README. The programs and the bindings are linked against the library
without rpath, so the installed ones use the installed library. To run them
from the source tree on Linux, the loader has to find the library, e.g.

```sh
LD_LIBRARY_PATH=sw/BusAccess/bin/Release sw/IoView/bin/Release/IoView
```

## Installing

```sh
sudo make install                     # to /usr/local
sudo make install PREFIX=/usr
make install-python install-octave    # the bindings, optional
make uninstall                        # uninstall-python, uninstall-octave
```

On Linux, run `sudo ldconfig` after installing the libraries. Some
distributions (e.g. Fedora) do not search `/usr/local/lib`: add it to a file
in `/etc/ld.so.conf.d/`, or install with `PREFIX=/usr`.

The Makefiles follow the GNU conventions. The variables, with their
defaults ([`common.mk`](common.mk)):

| Variable | Default | Installs |
|----------|---------|----------|
| `PREFIX` | `/usr/local` | |
| `bindir` | `PREFIX/bin` | programs; the DLLs on Windows |
| `libdir` | `PREFIX/lib` | libraries, e.g. `libdir=/usr/lib64` on Fedora |
| `includedir` | `PREFIX/include` | headers, in `includedir/ipdbg` |
| `pkgconfigdir` | `libdir/pkgconfig` | `ipdbg-busaccess.pc`, `ipdbg-waveformgenerator.pc` |
| `datadir` | `PREFIX/share` | IoView desktop file and icon |
| `PYTHONDIR` | `site-packages` of `python3` under `PREFIX` | Python modules; Debian and Ubuntu use `dist-packages`, e.g. `PYTHONDIR=/usr/lib/python3/dist-packages` |
| `OCTDIR` | `octave-config -p LOCALOCTFILEDIR` | Octave modules |
| `DESTDIR` | empty | staging directory for packages, put in front of all paths |

For example, for a package:

```sh
make
make install PREFIX=/usr libdir=/usr/lib64 DESTDIR=/tmp/pkgroot
```

The installed names have the prefix `ipdbg-` to avoid collisions with other
software. The libraries keep their own ABI version (soname
`libipdbg-busaccess.so.0`), independent of the version of the host software.

On Windows (MSYS2), `make install` installs the programs as
`ipdbg-ioview.exe` and `ipdbg-uartbridge.exe`; IoView and the bindings have
the library compiled in.

Ready-made programs for Windows, without MSYS2, are in the ZIP of each
[release](https://github.com/IPDBG/IPDBG/releases).

## License

[MPL-2.0](https://www.mozilla.org/MPL/2.0/)
