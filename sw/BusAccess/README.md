# IPDBG BusAccess

Host-side library for the IPDBG bus master cores. It lets a PC act as a bus
master inside an FPGA design: read and write registers and memories on a
Wishbone, APB, AXI4-Lite, AHB, Avalon or RISC-V DMI bus through an IPDBG
connection.

Part of [IPDBG](https://github.com/IPDBG/IPDBG).

This directory contains:

| Path                 | Content                                              |
|----------------------|------------------------------------------------------|
| `BusAccess.h/.c`     | C API                                                |
| `BusAccessCxx.h/.cpp/.tpp` | C++ class `IpdbgBusAccess` (wraps the C API)   |
| `BusAccessCxx.i`     | SWIG interface, shared by the Python and Octave bindings |
| [`python/`](python/README.md) | Python bindings                             |
| [`octave/`](octave/README.md) | Octave bindings                             |

## How it works

```
 PC                                              FPGA
┌──────────────────────┐   TCP   ┌─────────────┐   JTAG/…   ┌────────────────┐     ┌──────────┐
│ C / C++ / Python /   │ ──────► │ IPDBG host  │ ─────────► │ IPDBG bus      │ ──► │ your bus │
│ Octave (BusAccess)   │         │ server      │            │ master core    │     │ slaves   │
└──────────────────────┘         └─────────────┘            └────────────────┘     └──────────┘
```

The library connects via TCP to an IPDBG host server, e.g. OpenOCD for JTAG.
IPDBG is transport-agnostic, so any other IPDBG host server works as well.

After connecting, the library queries the widths of all fields from the core.
These widths are defined by the HDL generics, so the same host code works for
any bus configuration.

### Fields

| Field      | Meaning                                                              |
|------------|----------------------------------------------------------------------|
| Address    | Bus address                                                          |
| Write data | Data for write accesses                                              |
| Read data  | Data returned by read accesses                                       |
| Strobe     | Byte/lane enables for writes (`sel_o`, `pstrb`, `wstrb`, …). After reset all bits are `1` (full word access). |
| Misc       | Protocol specific sideband signals (`pprot`, `hprot`/`hsize`, …). Usually set once and left static. |

All sizes reported by the API are in **bits**. On the wire and in the C API,
every field is transferred as `ceil(bits / 8)` bytes, least significant byte
first. A field with width 0 does not exist on that core.

### Access results

Every read and write is answered by the core with either ACK or NAK. A NAK
means the bus signalled an error (e.g. `err_i`, `pslverr`, `hresp`, an AXI
`SLVERR`/`DECERR`). See the table below for what triggers a NAK on each core.

### Locked accesses

Reads and writes can be *locked*. The core asserts its bus lock signal at the
start of a locked access and keeps it asserted until the end of the next
unlocked access. This is used for atomic read-modify-write sequences. Only
cores whose bus has a lock signal support it (Wishbone, AHB, Avalon).

## Supported bus master cores

The HDL cores are in [`rtl/BusAccess`](../../rtl/BusAccess).

| Core                                                   | Data width                    | Strobe       | Misc (width, reset value)                          | Lock        | NAK on                         |
|--------------------------------------------------------|-------------------------------|--------------|----------------------------------------------------|-------------|--------------------------------|
| [`WbMaster`](../../rtl/BusAccess/WbMaster.vhd)         | any, multiple of `sel_o`      | `sel_o`      | –                                                  | `lock_o`    | `rty_i`, `err_i`               |
| [`ApbMaster`](../../rtl/BusAccess/ApbMaster.vhd)       | 8, 16, 32                     | `pstrb`      | `pprot` (3, `000`)                                 | –           | `pslverr`                      |
| [`Axi4lMaster`](../../rtl/BusAccess/Axi4lMaster.vhd)   | 32, 64                        | `wstrb`      | `awprot` & `arprot` (6, `000000`)                  | –           | `rresp`/`bresp` ≠ OKAY         |
| [`AhbMaster`](../../rtl/BusAccess/AhbMaster.vhd)       | 8 … 1024                      | `hwstrb`     | `hprot` & `hsize` (3, 7 or 10; privileged data access, full bus width) | `hmastlock` | `hresp`   |
| [`AvalonMaster`](../../rtl/BusAccess/AvalonMaster.vhd) | 8 … 1024                      | `byteenable` | `debugaccess` (1, `1`)                             | `lock`      | `response` ≠ OKAY (reads only) |
| [`RiscvDtm`](../../rtl/BusAccess/RiscvDtm.vhd)         | 32 (address 7 … 32 bit)       | –            | `dmireset`, `dmihardreset` (2, `00`)               | –           | never                          |

Note on the reset values: `AhbMaster` starts with privileged data accesses and
`AvalonMaster` starts with `debugaccess` asserted. Both are deliberate: a
debugger usually needs these permissions, e.g. to write to an on-chip memory
configured as ROM.

## Building

Requirements:

* Linux (only tested platform; patches for other systems are welcome)
* GCC/G++ (or Clang) with C++17 support, GNU make

```sh
cd sw/BusAccess
make
```

This builds the library into `bin/Release`:

| File                    | Purpose                                         |
|-------------------------|-------------------------------------------------|
| `libBusAccess.so.0.1.0` | The library (C API and C++ class)               |
| `libBusAccess.so.0`     | Symlink, SONAME used by programs at runtime     |
| `libBusAccess.so`       | Symlink used when linking                       |

`make clean` removes the build output. The Code::Blocks project in this
directory builds the same library (target *Release*).

To use the library from your own program, add `sw/BusAccess` to the include
path and link with `-L<path>/sw/BusAccess/bin/Release -lBusAccess`. At runtime
the loader has to find `libBusAccess.so.0`, e.g. via
`-Wl,-rpath,<path>/sw/BusAccess/bin/Release` or `LD_LIBRARY_PATH`.

## C API

Header: `BusAccess.h`

### Connection

| Function                                            | Description                                   |
|-----------------------------------------------------|-----------------------------------------------|
| `IpdbgBusAccess_new()`                              | Create a handle. Returns `NULL` on failure.   |
| `IpdbgBusAccess_open(handle, host, port)`           | Connect, reset the core and read its field widths. `host` and `port` are strings, e.g. `"127.0.0.1"`, `"4245"`. |
| `IpdbgBusAccess_isOpen(handle)`                     | Non-zero if connected.                        |
| `IpdbgBusAccess_close(handle)`                      | Close the connection.                         |
| `IpdbgBusAccess_delete(handle)`                     | Close (if open) and free the handle.          |
| `IpdbgBusAccess_getFieldSize(handle, field, &bits)` | Width of `ADDRESS`, `READ_DATA`, `WRITE_DATA`, `STROBE` or `MISC` in bits. |
| `IpdbgBusAccess_getLastError(handle)`               | Description of the error of the last call on this handle, `""` if it succeeded. Never `NULL`. |

### Accesses

All `address`, `data` and `result` parameters are byte buffers, least
significant byte first, with at least `ceil(width / 8)` bytes for the
respective field.

| Function                                                        | Description                                   |
|-----------------------------------------------------------------|-----------------------------------------------|
| `IpdbgBusAccess_write(handle, address, data)`                   | Write access.                                 |
| `IpdbgBusAccess_read(handle, address, result)`                  | Read access.                                  |
| `IpdbgBusAccess_write_ctrllock(handle, address, data, locked)`  | Write, optionally locked.                     |
| `IpdbgBusAccess_read_ctrllock(handle, address, result, locked)` | Read, optionally locked.                      |
| `IpdbgBusAccess_read_modify_write(handle, address, modify)`     | Locked read, call `modify(buffer)`, unlocked write. Requires equal read and write data width. |
| `IpdbgBusAccess_setStrobe(handle, data)`                        | Set the strobe used for subsequent writes.    |
| `IpdbgBusAccess_setMiscellaneous(handle, data)`                 | Set the misc signals.                         |

The core keeps the last address, so repeated accesses to the same address do
not resend it.

### Protocol helpers

These set the misc field for a specific core and check that the misc width
matches that core.

| Function                                                 | Core           | Flags                                         |
|----------------------------------------------------------|----------------|-----------------------------------------------|
| `IpdbgAxi4lAccess_setAxprot(handle, arprot, awprot)`     | `Axi4lMaster`  | AXI/APB protection flags                      |
| `IpdbgApbAccess_setPprot(handle, pprot)`                 | `ApbMaster`    | AXI/APB protection flags                      |
| `IpdbgAhbAccess_setHprotHsize(handle, hprot, hsize)`     | `AhbMaster`    | AHB flags; `hsize` = log2(bytes per transfer), e.g. 2 for 32 bit |
| `IpdbgAvalonAccess_setDebugAccess(handle, debug)`        | `AvalonMaster` | `DebugAccess`, `NonDebugAccess`               |
| `IpdbgDtm_setResets(handle, reset, hardreset)`           | `RiscvDtm`     | `dmireset`, `dmihardreset`                    |

Flag values (OR them together). The Python and Octave bindings don't export
these names, so use the numeric values there.

| AXI4-Lite / APB                          | AHB                                          |
|------------------------------------------|----------------------------------------------|
| `UnprivilegedAccess` 0x0, `PrivilegedAccess` 0x1 | `H_OpcodeFetch` 0x00, `H_DataAccess` 0x01 |
| `SecureAccess` 0x0, `NonSecureAccess` 0x2 | `H_UserAccess` 0x00, `H_PrivilegedAccess` 0x02 |
| `DataAccess` 0x0, `InstructionAccess` 0x4 | `H_NonBufferable` 0x00, `H_Bufferable` 0x04 |
|                                          | `H_NonCacheable` 0x00, `H_Cacheable` 0x08    |
|                                          | `H_DontLookup` 0x00, `H_Lookup` 0x10         |
|                                          | `H_DontAllocate` 0x00, `H_Allocate` 0x20     |
|                                          | `H_NonShareable` 0x00, `H_Shareable` 0x40    |

### Return values

| Value       | Meaning                                                  |
|-------------|----------------------------------------------------------|
| `RET_ACK`   | Read/write completed successfully.                       |
| `RET_NAK`   | Read/write completed with a bus error.                   |
| `RET_OK`    | Success (all functions other than read/write).           |
| `RET_ERROR` | Communication error, invalid handle or wrong core type.  |

The library does not print anything. After `RET_ERROR` or `RET_NAK`,
`IpdbgBusAccess_getLastError()` describes what went wrong, e.g.
`unable to connect to 127.0.0.1:4245 (Connection refused)`.

### Example

```c
#include <stdio.h>
#include "BusAccess.h"

int main(void)
{
    struct IpdbgBusAccessHandle *ba = IpdbgBusAccess_new();
    if (!ba)
        return 1;
    if (IpdbgBusAccess_open(ba, "127.0.0.1", "4245") != RET_OK)
    {
        printf("%s\n", IpdbgBusAccess_getLastError(ba));
        IpdbgBusAccess_delete(ba);
        return 1;
    }

    /* 16 bit address, 32 bit data, least significant byte first */
    const uint8_t address[2] = {55, 0};
    const uint8_t data[4]    = {0xfe, 0xca, 0x00, 0x00};  /* 0xcafe */
    uint8_t result[4];

    if (IpdbgBusAccess_write(ba, address, data) != RET_ACK)
        printf("write failed: %s\n", IpdbgBusAccess_getLastError(ba));

    if (IpdbgBusAccess_read(ba, address, result) == RET_ACK)
        printf("read: 0x%02x%02x%02x%02x\n", result[3], result[2], result[1], result[0]);

    IpdbgBusAccess_delete(ba);
    return 0;
}
```

## C++ API

Header: `BusAccessCxx.h` (requires C++17)

The class `IpdbgBusAccess` wraps the C API. Values are passed as unsigned
integers instead of byte buffers. All errors, including a NAK, throw a
`std::runtime_error` with a descriptive message.

| Method                                            | Description                                   |
|---------------------------------------------------|-----------------------------------------------|
| `open(host, port)`, `close()`, `isOpen()`         | Connection                                    |
| `getAddressSize()`, `getReadDataSize()`, `getWriteDataSize()`, `getStrobeSize()`, `getMiscSize()` | Field widths in bits |
| `write(address, data, locked = false)`            | Write access                                  |
| `read<A, D>(address, locked = false)`             | Read access, returns `D`                      |
| `read_modify_write<A, D>(address, fn)`            | Locked read, `fn(value)`, unlocked write      |
| `setStrobe(value)`, `setMiscellaneous(value)`     | Strobe and misc                               |
| `setAxi4lAxprot()`, `setApbPprot()`, `setAhbHprotHsize()`, `setAvalonDebugAccess()`, `setDtmResets()` | Protocol helpers (see C API) |

Address and data types must be unsigned integer types. They may be wider than
the field, but the value must fit: an address or data value with bits set
beyond the field width throws, and so does `read()` when the read data field
is wider than `D` (checked before the bus is accessed).

```cpp
#include <cstdint>
#include <iostream>
#include "BusAccessCxx.h"

int main()
{
    IpdbgBusAccess ba;
    try {
        ba.open("127.0.0.1", "4245");
        ba.write(uint16_t{55}, uint32_t{0xcafe});
        auto value = ba.read<uint16_t, uint32_t>(55);
        std::cout << std::hex << value << '\n';

        ba.read_modify_write<uint16_t, uint32_t>(55, [](uint32_t v) { return v | 1u; });
        ba.close();
    } catch (const std::runtime_error &e) {
        std::cerr << e.what() << '\n';
        return 1;
    }
}
```

## Language bindings

* [Python](python/README.md)
* [Octave](octave/README.md)

## License

* Hardware (`rtl/`): [CERN-OHL-W-2.0](https://ohwr.org/cern_ohl_w_v2.txt)
* Software (`sw/`): [MPL-2.0](https://www.mozilla.org/MPL/2.0/)
