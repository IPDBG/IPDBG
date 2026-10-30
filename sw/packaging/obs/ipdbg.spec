# SPDX-FileCopyrightText: The IPDBG authors
# SPDX-License-Identifier: MPL-2.0
#
# RPM package of the IPDBG host software for the openSUSE Build Service
# (Fedora, openSUSE, AlmaLinux), see README.md.

# The SWIG of EL 9 cannot build bindings for its Octave
%if 0%{?rhel} == 9
%bcond_with     octave
%else
%bcond_without  octave
%endif

Name:           ipdbg
Version:        0.2.0
Release:        1%{?dist}
Summary:        Host software of IPDBG, the debugger for FPGAs
License:        MPL-2.0
URL:            https://github.com/IPDBG/IPDBG
Source0:        ipdbg-%{version}.tar.gz

BuildRequires:  gcc
BuildRequires:  gcc-c++
BuildRequires:  make
BuildRequires:  pkgconfig
BuildRequires:  pkgconfig(libserialport)
%if 0%{?suse_version}
BuildRequires:  wxWidgets-devel >= 3
%else
BuildRequires:  wxGTK-devel
%endif
BuildRequires:  swig
BuildRequires:  python3-devel
%if %{with octave}
BuildRequires:  octave-devel
%endif

%description
IPDBG provides vendor-independent debug cores for FPGAs (logic analyzer,
waveform generator, bus master, I/O probe, serial console) and the host
software to use them over JTAG or UART.

%package -n ipdbg-ioview
Summary:        IoView: read and set signals of an IPDBG IoProbe core

%description -n ipdbg-ioview
IoView is the GUI for the IoProbe core of IPDBG: it shows the probe inputs
as LEDs and sets the probe outputs.

%package -n ipdbg-uartbridge
Summary:        UartBridge: TCP to serial port bridge for the IPDBG UART transport

%description -n ipdbg-uartbridge
UartBridge forwards a TCP port to a serial port, so the IPDBG host tools
reach a core over the UART transport.

%package -n libipdbg0
Summary:        IPDBG BusAccess and WaveformGenerator libraries

%description -n libipdbg0
The libraries libipdbg-busaccess (register accesses through an IPDBG bus
master core) and libipdbg-waveformgenerator (control of the IPDBG waveform
generator core).

%package -n libipdbg-devel
Summary:        Development files of the IPDBG libraries
Requires:       libipdbg0%{?_isa} = %{version}-%{release}

%description -n libipdbg-devel
Headers and pkg-config files of libipdbg-busaccess and
libipdbg-waveformgenerator.

%package -n python3-ipdbg
Summary:        Python bindings of the IPDBG libraries
Requires:       libipdbg0%{?_isa} = %{version}-%{release}

%description -n python3-ipdbg
Python modules BusAccess and WaveformGenerator for the IPDBG bus master and
waveform generator cores.

%if %{with octave}
%package -n octave-ipdbg
Summary:        GNU Octave bindings of the IPDBG libraries
Requires:       libipdbg0%{?_isa} = %{version}-%{release}
# openSUSE splits the command line Octave from the GUI
%if 0%{?suse_version}
Requires:       octave-cli
%else
Requires:       octave
%endif

%description -n octave-ipdbg
GNU Octave modules BusAccess and WaveformGenerator for the IPDBG bus master
and waveform generator cores.
%endif

%prep
%autosetup -n IPDBG-%{version}
# both are README.md, the documentation directory needs distinct names
cp sw/BusAccess/README.md README-BusAccess.md
cp sw/WaveformGenerator/README.md README-WaveformGenerator.md

%build
%{?set_build_flags}
WX_CONFIG=$(command -v wx-config || command -v wx-config-3.2)
%make_build -C sw all python %{?with_octave:octave} WX_CONFIG="$WX_CONFIG"

%install
WX_CONFIG=$(command -v wx-config || command -v wx-config-3.2)
%make_install -C sw install-python %{?with_octave:install-octave} WX_CONFIG="$WX_CONFIG" \
    PREFIX=%{_prefix} libdir=%{_libdir} PYTHONDIR=%{python3_sitearch}
%if %{with octave}
# the Octave directory comes from octave-config
octdir=$(octave-config -p LOCALOCTFILEDIR)
printf '%s\n' "$octdir/BusAccess.oct" "$octdir/WaveformGenerator.oct" > octave.files
%endif
# byte-compile the Python modules: Fedora does it automatically, openSUSE not
python3 -m compileall -q -d %{python3_sitearch} %{buildroot}%{python3_sitearch}

%ldconfig_scriptlets -n libipdbg0

%files -n ipdbg-ioview
%license LICENSES/MPL-2.0.txt
%doc sw/IoView/README.md
%{_bindir}/ipdbg-ioview
%{_datadir}/applications/ipdbg-ioview.desktop
%{_datadir}/icons/hicolor/scalable/apps/ipdbg-ioview.svg

%files -n ipdbg-uartbridge
%license LICENSES/MPL-2.0.txt
%doc sw/UartBridge/README.md
%{_bindir}/ipdbg-uartbridge

%files -n libipdbg0
%license LICENSES/MPL-2.0.txt
%{_libdir}/libipdbg-busaccess.so.0*
%{_libdir}/libipdbg-waveformgenerator.so.0*

%files -n libipdbg-devel
%doc README-BusAccess.md README-WaveformGenerator.md
%{_includedir}/ipdbg/
%{_libdir}/libipdbg-busaccess.so
%{_libdir}/libipdbg-waveformgenerator.so
%{_libdir}/pkgconfig/ipdbg-busaccess.pc
%{_libdir}/pkgconfig/ipdbg-waveformgenerator.pc

%files -n python3-ipdbg
%{python3_sitearch}/BusAccess.py
%{python3_sitearch}/WaveformGenerator.py
%{python3_sitearch}/_BusAccess.so
%{python3_sitearch}/_WaveformGenerator.so
%{python3_sitearch}/__pycache__/BusAccess.*
%{python3_sitearch}/__pycache__/WaveformGenerator.*

%if %{with octave}
%files -n octave-ipdbg -f octave.files
%endif

%changelog
* Fri Oct 30 2026 Daniel Anselmi <danselmi@gmx.ch> - 0.2.0-1
- Version 0.2.0

* Tue Oct 27 2026 Daniel Anselmi <danselmi@gmx.ch> - 0.1.1-2
- No Octave bindings on EL 9

* Tue Oct 13 2026 Daniel Anselmi <danselmi@gmx.ch> - 0.1.1-1
- Version 0.1.1

* Sun Oct 11 2026 Daniel Anselmi <danselmi@gmx.ch> - 0.1.0-1
- First package
