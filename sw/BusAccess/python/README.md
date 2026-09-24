# IPDBG BusAccess – Python bindings

Python bindings for the [IPDBG BusAccess library](../README.md), generated
with SWIG from the C++ class `IpdbgBusAccess`.

See the [main README](../README.md) for the concepts (field widths, strobe,
misc, ACK/NAK, locking) and the supported bus master cores.

## Requirements

* Linux (only tested platform; patches for other systems are welcome)
* Python 3 including development headers (`python3-devel` on Fedora,
  `python3-dev` on Debian/Ubuntu). Tested with Python 3.13.
* SWIG
* GCC/G++ with C++17 support, GNU make

## Building

```sh
cd sw/BusAccess/python
make
```

This builds the library first if needed (see the
[main README](../README.md#building)).

This creates `BusAccess.py` and `_BusAccess.so`. `_BusAccess.so` finds
`libBusAccess.so` on its own, so `LD_LIBRARY_PATH` is not needed.

To import the module from another directory, add `sw/BusAccess/python` to
`PYTHONPATH`.

`make clean` removes the generated files.

## Usage

The output below comes from a Wishbone master (`WbMaster`) with a 16 bit
address, 32 bit data and a 2 bit `sel_o`.

```python
>>> import BusAccess
>>> ba = BusAccess.IpdbgBusAccess()
>>> ba.open("127.0.0.1", "4245")
>>> ba.getAddressSize()
16
>>> ba.getReadDataSize()
32
>>> ba.getWriteDataSize()
32
>>> ba.getStrobeSize()
2
>>> ba.getMiscSize()
0
>>> address = 55
>>> ba.write(address, 0xcafe)
>>> hex(ba.read(address))
'0xcafe'
>>> ba.close()
```

## Error handling

All errors raise a `RuntimeError` with a descriptive message, e.g. when the
connection fails, the bus answers with a NAK or a value doesn't fit into its
field (such as an address above `0xffff` on a 16 bit address bus):

```python
try:
    ba.write(address, 0xcafe)
except RuntimeError as e:
    print(f"bus access failed: {e}")
```

## API

| Method                                      | Description                                   |
|---------------------------------------------|-----------------------------------------------|
| `open(host, port)`                          | Connect to the IPDBG host server. Both arguments are strings. |
| `close()`, `isOpen()`                       | Connection                                    |
| `getAddressSize()`, `getReadDataSize()`, `getWriteDataSize()`, `getStrobeSize()`, `getMiscSize()` | Field widths in bits |
| `write(address, data, locked=False)`        | Write access                                  |
| `read(address, locked=False)`               | Read access, returns an `int`                 |
| `setStrobe(value)`                          | Strobe for subsequent writes                  |
| `setMiscellaneous(value)`                   | Misc signals                                  |
| `setAxi4lAxprot(arprot, awprot)`            | `Axi4lMaster` protection flags                |
| `setApbPprot(pprot)`                        | `ApbMaster` protection flags                  |
| `setAhbHprotHsize(hprot, hsize)`            | `AhbMaster` `hprot` and `hsize`               |
| `setAvalonDebugAccess(debug)`               | `AvalonMaster` `debugaccess`                  |
| `setDtmResets(reset, hardreset)`            | `RiscvDtm` `dmireset` / `dmihardreset`        |

Notes:

* Addresses and values are limited to 64 bits. Wider fields (possible with
  the AHB and Avalon masters) can only be accessed through the C or C++ API.
* The flag names from `BusAccess.h` (e.g. `PrivilegedAccess`) are not
  exported. Use the numeric values listed in the
  [main README](../README.md#protocol-helpers), e.g.
  `ba.setAxi4lAxprot(0x1, 0x1)` for privileged accesses.

## Read-modify-write

There is no `read_modify_write()` in Python. A locked read followed by an
unlocked write does the same: the locked read asserts the bus lock (on cores
that have one, see the [main README](../README.md#locked-accesses)) and the
unlocked write releases it again.

```python
value = ba.read(address, True)   # locked read
ba.write(address, value | 0x1)   # unlocked write, releases the lock
```

## License

[MPL-2.0](https://www.mozilla.org/MPL/2.0/)
