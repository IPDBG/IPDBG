# JtagHub – the JTAG connection of the IPDBG cores

The JtagHub connects up to seven IPDBG cores to the host over the JTAG port
of the FPGA, the same port you use to configure it. No extra pins are
needed. On the host, OpenOCD provides one TCP port per core.

Part of [IPDBG](https://github.com/IPDBG/IPDBG).

```
 FPGA                                                          PC
┌─────────────┐     ┌─────────┐   JTAG   ┌──────────────┐  TCP  ┌────────────┐
│ IPDBG cores │ ◄─► │ JtagHub │ ◄──────► │ JTAG adapter │ ◄───► │ OpenOCD    │ ◄─► host tools
│ (up to 7)   │     │         │          │              │  USB  │ (ipdbg)    │
└─────────────┘     └─────────┘          └──────────────┘       └────────────┘
```

The hub uses a user data register of the FPGA's JTAG TAP (`USER1` or the
vendor's equivalent), so it works next to configuration and other JTAG
users of the device.

## Interface

All hub variants have these generics and ports:

| Generic / port | Meaning |
|----------------|---------|
| `MFF_LENGTH` | Number of flip-flops of the synchronizers between the JTAG clock and `clk`, default 3 |
| `FLOW_CONTROL_ENABLE` | One bit per channel, bit N for channel N. `'1'`: the hub honours `dnlink_ready` of the core and holds back the host while the core cannot take a byte. `'0'`: the core must take every byte immediately. |
| `clk` | Clock of the cores; all `dn_lines`/`up_lines` are synchronous to it |
| `ce` | Clock enable |
| `dn_lines_0` … `dn_lines_6` | To the cores (`ipdbg_dn_lines`) |
| `up_lines_0` … `up_lines_6` | From the cores (`ipdbg_up_lines`); default `unused_up_lines`, so unused channels can be left open |

The records are defined in
[`rtl/common/ipdbg_interface_pkg.vhd`](../common/ipdbg_interface_pkg.vhd).
Channel N of the hub is tool N in OpenOCD (`$hub start -tool N`).

Only the cores that need it require flow control, e.g.
[Iurt](../Iurt/README.md). The other cores take every byte immediately and
work with `'0'`.

## Hub variants and TAP files

The hub consists of three parts: the hub entity, the clock domain crossing
`JtagCdc.vhd` (all variants) and a TAP file with the vendor's JTAG
primitive. All TAP files define the entity `IpdbgTap`; add exactly one of
them to your project. The flip-flops of the clock domain crossing come
from `rtl/common/dffpc_<family>.vhd`.

| Vendor | Family | Hub | TAP file | `dffpc` |
|--------|--------|-----|----------|---------|
| AMD (Xilinx) | Spartan-3 | `JtagHub.vhd` | `IpdbgTap_xc3s.vhd` | `dffpc_xc3s.vhd` |
| | Spartan-6 | `JtagHub.vhd` | `IpdbgTap_xc6s.vhd` | `dffpc_xc6.vhd` |
| | Virtex-6 | `JtagHub.vhd` | `IpdbgTap_xc6v.vhd` | `dffpc_xc6.vhd` |
| | 7 Series, Zynq-7000 | `JtagHub.vhd` | `IpdbgTap_xc7.vhd` | `dffpc_xc7.vhd` |
| | UltraScale, UltraScale+ ¹ | `JtagHub.vhd` | `IpdbgTap_xc7.vhd` | `dffpc_xc7.vhd` |
| Intel (Altera) | virtual JTAG, all families with `sld_virtual_jtag` | `JtagHub.vhd` | `IpdbgTap_intel_vjtag.vhd` | `dffpc_intel.vhd` |
| | Arria II, Arria II GZ, Arria V, Arria V GZ, Cyclone III, Cyclone IV, Cyclone IV E, Cyclone V, Cyclone 10 LP, MAX V, MAX 10, Stratix III, Stratix V | `JtagHub_4ext.vhd` | `IpdbgTap_intel.vhd` and `IpdbgTapJtag_<family>.vhd` | `dffpc_intel.vhd` |
| Lattice | ECP2 | `JtagHub_4ext.vhd` | `IpdbgTap_ecp2.vhd` | `dffpc_ecp.vhd` |
| | ECP3 | `JtagHub_4ext.vhd` | `IpdbgTap_ecp3.vhd` | `dffpc_ecp.vhd` |
| | ECP5 | `JtagHub_4ext.vhd` | `IpdbgTap_ecp5.vhd` | `dffpc_ecp.vhd` |
| | Certus-NX | `JtagHub_4ext.vhd` | `IpdbgTap_certus.vhd` | `dffpc_certus.vhd` |
| Gowin | GW1N, GW2A | `JtagHub_4ext.vhd` | `IpdbgTap_gowin.vhd` | `dffpc_gowin.vhd` |
| Efinix | Trion, Titanium | `JtagHub_efinix.vhd` | – (JTAG user TAP of the Efinity interface designer) | `dffpc_efinix.vhd` |
| Microchip (Microsemi) | ProASIC3 | `JtagHub_proasic3.vhd` | `IpdbgTap_proasic3.vhd` | `dffpc_proasic3.vhd` |
| any | soft TAP on user I/Os | `JtagHub_4ext.vhd` | `IpdbgTap_generic.vhd` | `dffpc_behav.vhd` |

¹ Same `BSCANE2` primitive as the 7 Series; less tested so far.

The variants differ in the extra ports:

* `JtagHub.vhd`: none, the JTAG primitive is reached without top-level
  ports. Generic `TDI_HAS_EXT_REGISTER`, see below.
* `JtagHub_4ext.vhd`: `TCK`, `TMS`, `TDI`, `TDO`. The JTAG primitives of
  these families take the JTAG pins as ports; connect them to top-level
  ports named like the JTAG pins of the device. With
  `IpdbgTap_generic.vhd`, they are ordinary user I/Os. Generic
  `TDI_HAS_EXT_REGISTER`, see below.
* `JtagHub_efinix.vhd`: `DRCK`, `TDI`, `TDO`, `SEL`, `CAPTURE`, `SHIFT`,
  `UPDATE`, the signals of the JTAG user TAP that you create in the
  Efinity interface designer. Their names in your top level start with
  the instance name you give the JTAG user TAP there.
* `JtagHub_proasic3.vhd`: `TCK`, `TMS`, `TDI`, `TDO`, `TRST` of the
  `UJTAG` primitive. Connect them to top-level ports with exactly these
  names; they need no pin assignment.

`TDI_HAS_EXT_REGISTER` is `true` if the JTAG primitive registers TDI
before it reaches the hub, so the data register is one bit longer outside
the hub. Set it to `true` for Lattice (ECP2, ECP3, ECP5, Certus-NX) and
`false` for all other families (default).

## Instantiation

From the [Cmod S7 demo](../demo/cmod-s7/top.vhd) (7 Series):

```vhdl
jtag_hub_i : entity work.JtagHub
    generic map(
        MFF_LENGTH           => 3,
        FLOW_CONTROL_ENABLE  => "0000000",
        TDI_HAS_EXT_REGISTER => false
    )
    port map(
        clk        => clk,
        ce         => '1',
        -- channels 0 to 5 accordingly
        dn_lines_6 => dn_lines_6,
        up_lines_6 => up_lines_6
    );
```

Files for this example: `rtl/common/ipdbg_interface_pkg.vhd`,
`rtl/common/dffpc_xc7.vhd`, `JtagCdc.vhd`, `IpdbgTap_xc7.vhd`,
`JtagHub.vhd`.

## Timing constraints

The data crosses between the JTAG clock and `clk` through synchronizers.
For Vivado, `JtagHubCdc.tcl` constrains these paths (`set_max_delay
-datapath_only` and `set_bus_skew`, half the period of the destination
clock). Add it as a constraint file used in implementation only and
processed after the other constraints, as in the
[build script of the Cmod S7 demo](../demo/cmod-s7/build.tcl):

```tcl
set cdc [add_files -fileset constrs_1 rtl/JtagHub/JtagHubCdc.tcl]
set_property USED_IN_SYNTHESIS      false $cdc
set_property USED_IN_IMPLEMENTATION true  $cdc
set_property PROCESSING_ORDER       LATE  $cdc
```

## OpenOCD

OpenOCD 1.0.0 or later, or a git version including commit 52ea420
(*ipdbg: simplify command chains*). Create the hub, then start one server
per core:

```tcl
# with the pld driver of the device: OpenOCD knows the USER instruction
pld create xc7.pld virtex2 -chain-position xc7.tap
ipdbg create-hub xc7.ipdbghub -pld xc7.pld

# or with TAP and instruction register value, as in the Cmod S7 demo
ipdbg create-hub xc7.ipdbghub -tap xc7.tap -ir 0x02

xc7.ipdbghub start -tool 0 -port 4242
xc7.ipdbghub start -tool 1 -port 4243
```

* `-pld` works for the families with an OpenOCD pld driver: AMD, Lattice,
  Gowin, Efinix and Intel. Without it, use `-tap` and `-ir` with the
  `USER1` instruction of the device.
* The user number of `-pld` must match the user register of the TAP. The
  default 1 fits all TAP files except: `IpdbgTap_intel.vhd` with generic
  `sel_user => 0` needs `-pld <name> 0`, and for Efinix it is the number
  of the JTAG user TAP chosen in the Efinity interface designer.
* `IpdbgTap_intel_vjtag.vhd` needs `-vir` in addition.
* `IpdbgTap_generic.vhd` is a TAP of its own with an 8-bit instruction
  register: `jtag newtap ipdbg tap -irlen 8 -expected-id 0xf0f0f0f1`,
  then `ipdbg create-hub ipdbg.hub -tap ipdbg.tap -ir 0x55`.

See the [OpenOCD manual](https://openocd.org/doc/html/Boundary-Scan-Commands.html),
section *IPDBG: JTAG-Host server*, for all options.

## License

[CERN-OHL-W-2.0](https://ohwr.org/cern_ohl_w_v2.txt)
