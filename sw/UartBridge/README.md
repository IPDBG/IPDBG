# UartBridge

Connects the host tools to an IPDBG core over a serial port: UartBridge
forwards a TCP port to the serial port of the IPDBG UART transport
([`rtl/Uart`](../../rtl/Uart), `IpdbgUart`). The host tools connect to the
TCP port as usual, like to OpenOCD for JTAG.

Part of [IPDBG](https://github.com/IPDBG/IPDBG).

```
 PC                                                          FPGA
┌──────────────┐  TCP  ┌────────────┐  serial port  ┌───────────┐     ┌───────────┐
│ host tool    │ ◄───► │ UartBridge │ ◄───────────► │ IpdbgUart │ ◄─► │ one IPDBG │
│ (IoView, …)  │       │            │  (e.g. FTDI)  │           │     │ core      │
└──────────────┘       └────────────┘               └───────────┘     └───────────┘
```

`IpdbgUart` connects a single IPDBG core, there is no hub, so UartBridge
forwards the bytes unchanged in both directions. For several cores, use one
UART and one UartBridge per core, or JTAG.

## Requirements

* Linux, or Windows with [MSYS2](https://www.msys2.org) (MinGW-w64)
* [libserialport](https://sigrok.org/wiki/Libserialport) including
  development files, e.g. `libserialport-devel` on Fedora,
  `libserialport-dev` on Debian/Ubuntu,
  `mingw-w64-ucrt-x86_64-libserialport` on MSYS2 (UCRT64)
* pkg-config, G++ with C++17 support, GNU make

## Building

```sh
cd sw/UartBridge
make
```

This creates `bin/Release/UartBridge` (`UartBridge.exe` on Windows).
`make clean` removes the build output.

The Code::Blocks project `UartBridge.cbp` builds with the Makefile (target
*all*). On Windows, set the make program of the compiler in Code::Blocks to
the `make` of MSYS2 (*Settings → Compiler → Toolchain executables → Make
program*).

## Usage

```
UartBridge [options] <serial-port> <baudrate> <tcp-port>
UartBridge --list
```

| Option | Meaning |
|--------|---------|
| `--list` | List the serial ports with description, USB vendor/product ID and serial number, then exit |
| `--bind <address>` | IPv4 address to listen on; default `127.0.0.1`, `0.0.0.0` for all interfaces |
| `-h`, `--help` | Help |

The frame format is fixed to 8N1 (8 data bits, no parity, 1 stop bit), no
flow control, like `IpdbgUart`. The baudrate must match the generic
`CLOCKS_PER_ONE_SIXTEENTH_BIT` of `IpdbgUart`: baudrate = clock frequency /
(16 × `CLOCKS_PER_ONE_SIXTEENTH_BIT`).

Find the port of your board, then start the bridge, e.g. for an IoProbe core
behind the UART:

```sh
UartBridge --list
UartBridge /dev/ttyUSB1 115200 4244     # Linux
UartBridge COM4 115200 4244             # Windows
```

Then connect the host tool to `127.0.0.1` and the TCP port, here IoView to
port 4244.

Behaviour:

* One client at a time. While a client is connected, further connections
  are closed right away. When the client disconnects, the bridge waits for
  the next one; the serial port stays open.
* Bytes that arrived on the serial port while no client was connected are
  discarded when the next client connects.
* If the serial port fails, e.g. the USB adapter is unplugged, the bridge
  exits with an error.
* By default the bridge only accepts connections from the same PC. With
  `--bind 0.0.0.0`, anyone who can reach the PC over the network can access
  the IPDBG core.

## License

[MPL-2.0](https://www.mozilla.org/MPL/2.0/)
