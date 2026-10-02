# BusAccess – a bus master for the host

A bus master in your FPGA design, controlled from the host: read and write
the registers and memories on a Wishbone, APB, AXI4-Lite, AHB-Lite or
Avalon bus, or the Debug Module Interface (DMI) of a RISC-V debug module.
On the host, use the [BusAccess library](../../sw/BusAccess/README.md)
(C, C++, Python, GNU Octave).

Part of [IPDBG](https://github.com/IPDBG/IPDBG).

```
 PC                                                FPGA
┌───────────────────┐  TCP  ┌─────────┐  JTAG/…  ┌─────────┐     ┌────────────┐  bus  ┌───────────────┐
│ BusAccess library │ ◄───► │ OpenOCD │ ◄──────► │ JtagHub │ ◄─► │ bus master │ ◄───► │ registers,    │
│ (C/C++/Py/Octave) │       │         │          │         │     │ core       │       │ memories, …   │
└───────────────────┘       └─────────┘          └─────────┘     └────────────┘       └───────────────┘
```

## Bus master cores

| Core | Data width | Strobe | Misc (width, reset value) | Lock | NAK on |
|------|------------|--------|---------------------------|------|--------|
| `WbMaster` | any, multiple of `sel_o` | `sel_o` | – | `lock_o` | `rty_i`, `err_i` |
| `ApbMaster` | 8, 16, 32 | `pstrb` | `pprot` (3, `000`) | – | `pslverr` |
| `Axi4lMaster` | 32, 64 | `wstrb` | `awprot` & `arprot` (6, `000000`) | – | `rresp`/`bresp` ≠ OKAY |
| `AhbMaster` | 8 … 1024 | `hwstrb` | `hprot` & `hsize` (3, 7 or 10; privileged data access, full bus width) | `hmastlock` | `hresp` |
| `AvalonMaster` | 8 … 1024 | `byteenable` | `debugaccess` (1, `1`) | `lock` | `response` ≠ OKAY (reads only) |
| `RiscvDtm` | 32 (address 7 … 32 bit) | – | `dmireset`, `dmihardreset` (2, `00`) | – | never |

*Misc* are bus signals the host sets with the protocol helpers of the
library, e.g. `setAxi4lAxprot()`. *NAK* is the access result the host gets
when the slave reports an error.

Note on the reset values: `AhbMaster` starts with privileged data accesses
and `AvalonMaster` starts with `debugaccess` asserted. Both are deliberate: a
debugger usually needs these permissions, e.g. to write to an on-chip memory
configured as ROM.

All cores have the generic `ASYNC_RESET`, the ports `clk`, `rst`, `ce`,
`dn_lines`, `up_lines` and the bus ports with the names of the bus
specification. The widths of address, data and strobe are taken from the
signals you connect; the host queries them, so the same host code works for
any configuration. Unsupported widths are reported by assertions with
severity `failure`.

Notes per bus:

* `WbMaster`: Wishbone B4 classic, single read/write; `stall_i` is not
  supported.
* `ApbMaster`: `psel` is a single select; decode it from the address
  outside the core for several slaves. Without `pready` at the slave,
  connect `penable` to `pready`. Address up to 32 bit.
* `Axi4lMaster`: `awaddr` and `araddr`, `wdata` and `rdata` must have the
  same width.
* `AhbMaster`: AHB-Lite. Generic `MASTER_ID`, output on `hmaster`. `hburst`
  is 0 or 3 bits wide, `hprot` 0, 4 or 7 bits.
* `RiscvDtm`: the DMI side of a RISC-V Debug Transport Module, to connect
  to the DMI of a RISC-V debug module.

### Your own bus

`BusAccessController.vhd` implements the protocol and the access sequence
independent of a bus: address, data, strobe and misc outputs, `start_read`
/ `start_write`, and the inputs `read_done`, `write_done` and
`access_error`. The bus master cores above are thin wrappers around it, so
use one of them as a template for another bus.

## Instantiation

From the [Cmod S7 demo](../demo/cmod-s7/top.vhd): a Wishbone master with
16 bit address, 32 bit data and 2 bit `sel`:

```vhdl
bus_access_i : entity work.WbMaster
    generic map (
        ASYNC_RESET => false
    )
    port map (
        clk      => clk,
        rst      => rst,
        ce       => '1',
        dn_lines => dn_lines_3,
        up_lines => up_lines_3,
        lock_o   => lock,
        cyc_o    => cyc,
        stb_o    => stb,
        ack_i    => ack,
        we_o     => we,
        adr_o    => adr,     -- std_logic_vector(15 downto 0)
        sel_o    => sel,     -- std_logic_vector(1 downto 0)
        dat_o    => wr_dat,  -- std_logic_vector(31 downto 0)
        dat_i    => rd_dat   -- std_logic_vector(31 downto 0)
    );
```

## Files

| File | Content |
|------|---------|
| `WbMaster.vhd`, `ApbMaster.vhd`, `Axi4lMaster.vhd`, `AhbMaster.vhd`, `AvalonMaster.vhd`, `RiscvDtm.vhd` | The bus master cores |
| `BusAccessController.vhd` | Protocol and access sequence, used by all cores |
| `BusAccessStatemachine.vhd` | State machine of the controller |

In addition, from `rtl/common`: `ipdbg_interface_pkg.vhd` and
`IpdbgEscaping.vhd`. [IoProbe](../IoProbe/README.md) uses the controller as
well.

The [co-simulation](../../sw/CoSim/README.md) runs `WbMaster` without
hardware.

## License

[CERN-OHL-W-2.0](https://ohwr.org/cern_ohl_w_v2.txt)
