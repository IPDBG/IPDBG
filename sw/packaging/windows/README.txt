IPDBG host software @VERSION@ for Windows (64 bit)
https://github.com/IPDBG/IPDBG

No installation needed: unpack the ZIP and start the programs in bin.

  bin\ipdbg-ioview.exe       IoView: reads and sets the signals of an IoProbe
                             core
  bin\ipdbg-uartbridge.exe   UartBridge: forwards a TCP port to a serial port,
                             for the IPDBG UART transport; command line,
                             ipdbg-uartbridge --help shows the options
  bin\*.dll                  the BusAccess and WaveformGenerator libraries
                             and the DLLs the programs need

To start ipdbg-uartbridge from any directory, add bin to PATH.

For your own programs (MinGW-w64, e.g. MSYS2 UCRT64), the BusAccess and
WaveformGenerator libraries:

  include\ipdbg              headers, e.g. #include <ipdbg/BusAccess.h>
  lib\*.dll.a                import libraries (-lipdbg-busaccess,
                             -lipdbg-waveformgenerator)
  lib\pkgconfig              pkg-config files ipdbg-busaccess.pc and
                             ipdbg-waveformgenerator.pc; pkgconf finds the
                             directories relative to them

The Python and Octave bindings are not included: they work only with the
Python or Octave of MSYS2 they are built for. Build them in MSYS2, see
sw/BusAccess/README.md and sw/WaveformGenerator/README.md.

Documentation:
  IoView       https://github.com/IPDBG/IPDBG/blob/master/sw/IoView/README.md
  UartBridge   https://github.com/IPDBG/IPDBG/blob/master/sw/UartBridge/README.md
  BusAccess    https://github.com/IPDBG/IPDBG/blob/master/sw/BusAccess/README.md
  WaveformGenerator
               https://github.com/IPDBG/IPDBG/blob/master/sw/WaveformGenerator/README.md

License: MPL-2.0, see LICENSES\MPL-2.0.txt. The DLLs of other projects in
bin are listed in THIRD-PARTY.txt, their licenses are in licenses.
