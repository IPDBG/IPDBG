# IPDBG BusAccess – Octave bindings

Octave bindings for the [IPDBG BusAccess library](../README.md), generated
with SWIG from the C++ class `IpdbgBusAccess`.

See the [main README](../README.md) for the concepts (field widths, strobe,
misc, ACK/NAK, locking) and the supported bus master cores.

## Requirements

* Linux, or Windows with MinGW-w64 (e.g. [MSYS2](https://www.msys2.org))
* GNU Octave including development files (`mkoctfile`; `octave-devel` on
  Fedora, `octave-dev` on Debian/Ubuntu). Tested with Octave 9.4.
* SWIG
* GCC/G++ with C++17 support, GNU make

## Building

```sh
cd sw/BusAccess/octave
make
```

This creates `BusAccess.oct`.

* Linux: the module links `libBusAccess.so` and builds it first if needed (see
  the [main README](../README.md#building)). It finds the library on its
  own, so `LD_LIBRARY_PATH` is not needed.
* Windows: the library is compiled into `BusAccess.oct`, so no DLL has to be
  found at runtime.

To use the module from another directory, add `sw/BusAccess/octave` to the
Octave search path, e.g. `addpath("<path>/sw/BusAccess/octave")`.

`make clean` removes the generated files.

## Usage

The output below comes from a Wishbone master (`WbMaster`) with a 16 bit
address, 32 bit data and a 2 bit `sel_o`.

```octave
>> BusAccess;
>> ba = BusAccess.IpdbgBusAccess();
>> ba.open("127.0.0.1", "4245");
>> ba.getAddressSize()
ans = 16
>> ba.getReadDataSize()
ans = 32
>> ba.getWriteDataSize()
ans = 32
>> ba.getStrobeSize()
ans = 2
>> ba.getMiscSize()
ans = 0
>> address = 42;
>> write_data = 55;
>> ba.write(address, write_data);
>> ba.read(address)
ans = 55
>> ba.close();
```

`BusAccess;` loads the module once per session.

## Error handling

All errors raise an Octave error with a descriptive message, e.g. when the
connection fails, the bus answers with a NAK or a value doesn't fit into its
field (such as an address above `0xffff` on a 16 bit address bus):

```octave
try
  ba.write(address, write_data);
catch err
  disp(["bus access failed: " err.message]);
end_try_catch
```

## API

| Method                                      | Description                                   |
|---------------------------------------------|-----------------------------------------------|
| `open(host, port)`                          | Connect to the IPDBG host server. Both arguments are strings. |
| `close()`, `isOpen()`                       | Connection                                    |
| `getAddressSize()`, `getReadDataSize()`, `getWriteDataSize()`, `getStrobeSize()`, `getMiscSize()` | Field widths in bits |
| `write(address, data, locked)`              | Write access, `locked` is optional (default `false`) |
| `read(address, locked)`                     | Read access, `locked` is optional (default `false`) |
| `setStrobe(value)`                          | Strobe for subsequent writes                  |
| `setMiscellaneous(value)`                   | Misc signals                                  |
| `setAxi4lAxprot(arprot, awprot)`            | `Axi4lMaster` protection flags                |
| `setApbPprot(pprot)`                        | `ApbMaster` protection flags                  |
| `setAhbHprotHsize(hprot, hsize)`            | `AhbMaster` `hprot` and `hsize`               |
| `setAvalonDebugAccess(debug)`               | `AvalonMaster` `debugaccess`                  |
| `setDtmResets(reset, hardreset)`            | `RiscvDtm` `dmireset` / `dmihardreset`        |

Notes:

* Octave numbers are `double` by default and represent integers exactly
  only up to 2^53. For wider addresses or data, pass `uint64` values, e.g.
  `ba.write(uint64(address), uint64(0xffffffffffffffff))`.
* Addresses and values are limited to 64 bits. Wider fields (possible with
  the AHB and Avalon masters) can only be accessed through the C or C++ API.
* The flag names from `BusAccess.h` (e.g. `PrivilegedAccess`) are not
  exported. Use the numeric values listed in the
  [main README](../README.md#protocol-helpers), e.g.
  `ba.setAxi4lAxprot(1, 1)` for privileged accesses.

## Read-modify-write

There is no `read_modify_write()` in Octave. A locked read followed by an
unlocked write does the same: the locked read asserts the bus lock (on cores
that have one, see the [main README](../README.md#locked-accesses)) and the
unlocked write releases it again.

```octave
value = ba.read(address, true);       % locked read
ba.write(address, bitor(value, 1));   % unlocked write, releases the lock
```

## License

[MPL-2.0](https://www.mozilla.org/MPL/2.0/)
