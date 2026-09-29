# Iurt – a UART for the CPU in your FPGA, over IPDBG

Iurt gives a soft CPU in the FPGA a serial console without extra pins: the
CPU sees a 16450-compatible UART on its bus, and the other end is a TCP port
on the host. Connect any terminal to that port.

The name stands for IPDBG URT: a UART without the "asynchronous", since the
bytes travel over IPDBG instead of a serial line.

Part of [IPDBG](https://github.com/IPDBG/IPDBG).

```
 FPGA                                                       PC
┌─────┐  bus  ┌──────┐     ┌──────────┐   JTAG   ┌─────────┐  TCP  ┌──────────┐
│ CPU │ ────► │ Iurt │ ◄─► │ JtagHub  │ ◄──────► │ OpenOCD │ ◄───► │ terminal │
└─────┘       └──────┘     └──────────┘          └─────────┘       └──────────┘
```

## Programming model

Iurt looks like a 16450 (a 16550 without FIFO), so the existing 8250/16550
drivers work, e.g. those of Linux, U-Boot and Zephyr. FreeRTOS has no UART
drivers of its own; for bare-metal or FreeRTOS code, polling LSR and
reading RBR / writing THR is all it takes. The eight registers are 32 bits
apart, bits 31..8 read 0:

| Offset | DLAB = 0, read | DLAB = 0, write | DLAB = 1 |
|--------|----------------|-----------------|----------|
| 0x00   | RBR            | THR             | DLL      |
| 0x04   | IER            | IER             | DLM      |
| 0x08   | IIR            | FCR (ignored)   |          |
| 0x0C   | LCR            | LCR             |          |
| 0x10   | MCR            | MCR             |          |
| 0x14   | LSR            | –               |          |
| 0x18   | MSR            | –               |          |
| 0x1C   | SCR            | SCR             |          |

Device tree example for Linux:

```dts
serial@40000000 {
    compatible = "ns16450";
    reg = <0x40000000 0x20>;
    reg-shift = <2>;
    reg-io-width = <4>;
    clock-frequency = <50000000>; /* any value, the baud rate has no effect */
    interrupts = <...>;           /* optional, without it the driver polls */
};
```

Use `ns16450`, not `ns16550a`: Iurt has no FIFO.

Differences to a real 16450:

* No FIFO. FCR writes are ignored, IIR bits 7..6 read 0.
* The baud rate (DLL/DLM), LCR and MCR are stored but have no effect.
* While RBR is full, Iurt stalls the host, so no byte is lost. This needs
  the flow control of the hub for the Iurt channel (`FLOW_CONTROL_ENABLE`
  of the JtagHub). Without it, a byte arriving while RBR is full is lost
  and sets OE in the LSR.
* While THR is full, THRE stays 0 until the host has taken the byte.
* LSR: DR, OE, THRE and TEMT; no parity, framing or break errors.
* MSR: DCD, DSR and CTS are 1. In loopback mode (MCR bit 4) the MSR
  reflects MCR like a 16450, but the data is not looped back.
* Interrupts: receiver line status (overrun), received data available and
  THR empty, with the priorities of the 16450. `irq` is a level, active
  high.

The bytes to and from the host are not escaped, so all 256 values pass
unchanged and any TCP terminal works, e.g. `nc 127.0.0.1 <port>` with the port of
the Iurt channel.

## Bus interfaces

| Entity       | Bus |
|--------------|-----|
| `IurtWb`     | Wishbone B4, classic single read/write (`cyc_i` is not used) |
| `IurtAxi4l`  | AXI4-Lite |
| `IurtApb3`   | APB3 |
| `IurtApb4`   | APB4 |
| `IurtAvalon` | Avalon-MM (`address` is the word address) |
| `IurtObi`    | OBI (Open Bus Interface) |
| `IurtAhb`    | AHB-Lite |

All have the generic `ASYNC_RESET`, the ports `clk`, `rst`, `ce`, `irq`,
`dn_lines`, `up_lines` and the bus ports with the names of the bus
specification from the slave's view, like the BusAccess masters: e.g.
`cyc_i`, `stb_i`, `dat_i`, `dat_o`, `ack_o` for Wishbone, `awaddr`, `awvalid`,
… for AXI4-Lite, `psel`, `penable`, … for APB, `hsel`, `haddr`, … for
AHB-Lite. The bus address covers the 32 bytes of Iurt; connect the low bits
of your bus address.

* The generated register blocks (bus interface, IIR, LCR, MCR, LSR, MSR,
  SCR) have a synchronous, active-high reset: `clk` must run while `rst` is
  active. `ASYNC_RESET` and `ce` apply to `IurtCore` (RBR, THR, IER,
  DLL/DLM, interrupts) and the transfers to and from the host. Register
  accesses are handled regardless of `ce`.
* The files need VHDL-2008.

## Files

| File | Content |
|------|---------|
| `IurtCore.vhd` | RBR/THR/DLL and IER/DLM (depend on DLAB), status for IIR, LSR and MSR, interrupts, transfers to and from the host |
| `Iurt<Bus>.vhd` | Top per bus: register block and `IurtCore` |
| `generated/` | Register blocks generated from `iurt.rdl` with [PeakRDL-regblock-vhdl](https://github.com/SystemRDL/PeakRDL-regblock-vhdl), one per bus, and `reg_utils.vhd`: bus interface, IIR, LCR, MCR, LSR, MSR and SCR |
| `iurt.rdl` | SystemRDL description of the registers and their fields; RBR/THR/DLL and IER/DLM are `external` |
| `Makefile` | `make regs` regenerates `generated/` |
| `test/tb_Iurt.vhd` | Self-checking testbench (Wishbone or AHB-Lite) |

For a design with `IurtAxi4l`, add `rtl/common/ipdbg_interface_pkg.vhd`,
`generated/reg_utils.vhd`, `generated/IurtRegsAxi4l_pkg.vhd`,
`generated/IurtRegsAxi4l.vhd`, `IurtCore.vhd` and `IurtAxi4l.vhd`; the other
buses accordingly (AHB-Lite uses `IurtRegsPassthrough`).

The files in `generated/` are part of the repository, so you do not need
PeakRDL to use iurt. After changing `iurt.rdl`, regenerate them:

```sh
pip install peakrdl-cli==1.5.0 peakrdl-regblock-vhdl==1.3.1.1
cd rtl/Iurt
make regs
```

## Simulation

With [GHDL](https://github.com/ghdl/ghdl):

```sh
cd rtl/Iurt
ghdl -a --std=08 ../common/ipdbg_interface_pkg.vhd generated/reg_utils.vhd \
    generated/IurtRegsWb_pkg.vhd generated/IurtRegsWb.vhd \
    generated/IurtRegsPassthrough_pkg.vhd generated/IurtRegsPassthrough.vhd \
    IurtCore.vhd IurtWb.vhd IurtAhb.vhd test/tb_Iurt.vhd
ghdl --elab-run --std=08 tb_Iurt -gBUS_TYPE=wb  -gASYNC_RESET=true
ghdl --elab-run --std=08 tb_Iurt -gBUS_TYPE=ahb -gASYNC_RESET=false
```

The testbench ends with `tb_Iurt: all tests passed` or stops at the first
mismatch.

## License

[CERN-OHL-W-2.0](https://ohwr.org/cern_ohl_w_v2.txt). The generated files
belong to IPDBG as well; `generated/reg_utils.vhd` is from
PeakRDL-regblock-vhdl and free to use (MIT, see its `hdl-src/README.md`).
