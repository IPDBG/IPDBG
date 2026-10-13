# Common files

Files used by several IPDBG cores and transports. The README of each core
lists which of them it needs.

Part of [IPDBG](https://github.com/IPDBG/IPDBG).

| File | Content |
|------|---------|
| `ipdbg_interface_pkg.vhd` | The records `ipdbg_dn_lines` and `ipdbg_up_lines` between hub and core ([core interface](#core-interface)), and `unused_up_lines` for unused channels |
| `IpdbgEscaping.vhd` | [Escaping](#escaping) of the byte stream from the host: `0xEE` resets the core, `0x55` escapes these two values in the data. Used by the cores. |
| `pdpRam.vhd` | Pseudo dual-port RAM, inferred by the synthesis tools; sample memories of Logic Analyzer and Waveform Generator |
| `dffpc_<family>.vhd` | Flip-flop for the synchronizers of clock domain crossings, see below |
| `dffpc_behav.vhd` | The same for simulation only, **never** use it for synthesis |
| `IpdbgClockDomainCrossing.vhd` | Connects a core with another clock than the hub, see below |
| `IpdbgClockDomainCrossing.tcl` | Vivado constraints for `IpdbgClockDomainCrossing` |

## Core interface

Hub or transport and core are connected by two records of
`ipdbg_interface_pkg.vhd`, synchronous to one clock:

| Record | Direction | Signals |
|--------|-----------|---------|
| `ipdbg_dn_lines` | to the core | `dnlink_valid`, `dnlink_data` (8 bit): byte from the host; `uplink_ready`: the hub takes a byte |
| `ipdbg_up_lines` | from the core | `uplink_valid`, `uplink_data` (8 bit): byte to the host; `dnlink_ready`: the core takes a byte |

Both directions use the valid/ready handshake of AXI4-Stream:

* A byte moves at a rising edge of the clock with `valid = '1'` and
  `ready = '1'`. Bytes may follow back to back, one per clock.
* The sender keeps `valid` and the data until then. It must not wait for
  `ready` before it sets `valid`.
* The receiver may change `ready` at any time.

Exception: a JtagHub channel without flow control (`FLOW_CONTROL_ENABLE`)
does not wait for `dnlink_ready`. It sets `dnlink_valid` for one clock, and
the core must take the byte. The cores of this repository keep
`dnlink_ready = '1'` and take a byte every clock, so they work on such a
channel.

The bytes between host tool and core pass the transport unchanged; the
meaning of the bytes is up to the core, see [escaping](#escaping) and the
README of each core.

## Escaping

The host tools reset the core through the byte stream to the core.
`IpdbgEscaping` decodes it in front of the core:

| Bytes from the host | To the core |
|---------------------|-------------|
| `0xEE` | nothing; resets the core (output `reset` for one clock) |
| `0x55`, then any byte | the second byte, as data |
| any other byte | the byte |

A host tool sends `0xEE` when it connects, to start from a known state, and
puts `0x55` in front of each data byte `0x55` or `0xEE`. The command
bytes of the cores are never `0x55` or `0xEE`. The bytes from the core to
the host are not escaped.

Logic Analyzer, Waveform Generator, BusAccess and IoProbe contain
`IpdbgEscaping`. [Iurt](../Iurt/README.md) does not: its bytes go to a
terminal unchanged.

## dffpc

The synchronizers of the JtagHub, of `IpdbgUart` and of
`IpdbgClockDomainCrossing` use the entity `dffpc`. Each
`dffpc_<family>.vhd` instantiates a flip-flop primitive of the vendor;
without the primitive, the clock domain crossing does not work reliably.
Add exactly one of them to your project; the
[JtagHub README](../JtagHub/README.md#hub-variants-and-tap-files) lists
which one fits your FPGA family. For a vendor without a `dffpc` file, write
one that instantiates a flip-flop primitive of the vendor, and please send
us a [pull request](https://github.com/IPDBG/IPDBG/pulls).

## A core with another clock than the hub

All channels of a hub run on the clock `clk` of the hub. For a core in
another clock domain, put `IpdbgClockDomainCrossing` between the hub and the
core:

```
┌─────────┐  dn/up_lines   ┌──────────────────────────┐  dn/up_lines  ┌──────┐
│ JtagHub │ ◄────────────► │ IpdbgClockDomainCrossing │ ◄───────────► │ core │
│ (clk)   │   clk_host     │                          │   clk_func    │      │
└─────────┘                └──────────────────────────┘               └──────┘
```

| Generic / port | Meaning |
|----------------|---------|
| `ASYNC_RESET` | Asynchronous (`true`) or synchronous reset |
| `MFF_LENGTH` | Number of synchronizer flip-flops, default 3 |
| `clk_host`, `rst_host`, `ce_host` | Clock, reset and clock enable of the hub side |
| `dn_lines_host`, `up_lines_host` | To and from the channel of the hub |
| `clk_func`, `rst_func`, `ce_func` | Clock, reset and clock enable of the core side |
| `dn_lines_func`, `up_lines_func` | To and from the core |

* Enable the flow control of the hub for this channel
  (`FLOW_CONTROL_ENABLE` of the [JtagHub](../JtagHub/README.md#interface)):
  the clock domain crossing takes one byte at a time and holds back the hub
  in between.
* For Vivado, add `IpdbgClockDomainCrossing.tcl` like `JtagHubCdc.tcl`, as a
  constraint file used in implementation only and processed late, see the
  [JtagHub README](../JtagHub/README.md#timing-constraints).

With the UART transport, no clock domain crossing is needed: run
[`IpdbgUart`](../Uart/README.md) on the clock of the core.

## License

[CERN-OHL-W-2.0](https://ohwr.org/cern_ohl_w_v2.txt)
