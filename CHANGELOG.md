# Changelog

Changes that matter to users of IPDBG. The version is the version of the
host software (`sw/VERSION`); the HDL cores are released together with it.

## 0.2.0 – 2026-10-30

### Fixed

- BusAccess: the lock polarity was inverted. After every write by the host,
  `lock_o` (Wishbone), `hmastlock` (AHB) and `lock` (Avalon) stayed
  asserted, and a locked read did not lock the bus.
- BusAccess and WaveformGenerator libraries: `close()` waits for an answer
  of the core first; OpenOCD dropped commands sent just before. On Linux
  and macOS the connection is closed gracefully, as on Windows, so that
  OpenOCD accepts a new connection right after.

### Changed

- All hubs, transports and cores use a valid/ready handshake between hub
  and core which allows bytes to follow back to back. A JtagHub
  channel without flow control still does not wait for `dnlink_ready`.
  Own cores have to follow the handshake too, see `rtl/common/README.md`.
- Iurt: THR moves to a transmit register as soon as possible, so THRE is set
  earlier, like on a 16450; TEMT is set when both are empty. OE is only set
  for a byte that the hub dropped.

### Added

- Linux packages for Fedora, openSUSE, Debian, Ubuntu, AlmaLinux 9 (also
  for Rocky Linux and RHEL 9, with EPEL; without Octave bindings) and Arch,
  from the openSUSE Build Service (project `home:ipdbg`).
- Protocol descriptions for own transports and host tools, in the READMEs
  of `rtl/common`, the JtagHub, the UART transport and the cores.
- Self-checking testbenches for all cores and `IpdbgClockDomainCrossing`,
  run by `rtl/test/run.sh` and in GitHub Actions.
- CoSim: a second Logic Analyzer with run-length compression (port 4246),
  and `sw/CoSim/test/run.sh`, which checks the cores with the host tools
  and sigrok-cli, also in GitHub Actions.

## 0.1.1 – 2026-10-13

### Added

- Python package on PyPI: `pip install ipdbg`, with wheels for Linux,
  Windows and macOS.
- Build files for Linux packages for Fedora, openSUSE, Debian, Ubuntu and
  Arch, in `sw/packaging`.
- IoView follows the light or dark mode of the system, also on Windows.

### Fixed

- Octave bindings: did not compile with the SWIG of openSUSE Leap 16.

## 0.1.0 – 2026-10-11

First release, see the
[release notes](https://github.com/IPDBG/IPDBG/releases/tag/v0.1.0).
