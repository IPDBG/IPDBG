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

## Windows ZIP

For users without MSYS2, [`packaging/windows/make-zip.sh`](packaging/windows/make-zip.sh)
packs IoView and UartBridge with all DLLs they need, and the libraries for
own programs, into `ipdbg-VERSION-windows-x86_64.zip`. In an MSYS2 UCRT64
shell, with the packages listed in
[`.github/workflows/sw.yml`](../.github/workflows/sw.yml):

```sh
sw/packaging/windows/make-zip.sh out
```

GitHub Actions builds the ZIP on every change of `sw/` (workflow *Host
software*, which also builds and checks everything on Linux) and attaches it
to the run. For a tag `vVERSION` the tag has to match
[`VERSION`](VERSION); other builds have the commit in the name.

## Release

1. Set the version in [`VERSION`](VERSION), commit and push.
2. Tag the commit and push the tag, e.g.
   `git tag -a v0.1.0 -m "IPDBG 0.1.0" && git push origin v0.1.0`.
3. The workflow *Host software* builds and checks everything on Linux and
   Windows. If all passes, it creates a draft release on GitHub with the
   Windows ZIP and notes generated from the commits. Check the notes and
   publish the release. The Linux packages are built from the source
   archive of the tag.

## License

[MPL-2.0](https://www.mozilla.org/MPL/2.0/)
