# IoProbe

Read and set individual signals of your FPGA design from the host: virtual
LEDs and switches. [IoView](../../sw/IoView/README.md) is the host
application; IoProbe speaks the BusAccess protocol, so your own programs and
scripts can use it through the [BusAccess library](../../sw/BusAccess/README.md#core-identification)
as well.

Part of [IPDBG](https://github.com/IPDBG/IPDBG).

```
 PC                                     FPGA
┌────────┐  TCP  ┌─────────┐  JTAG/…  ┌─────────┐     ┌────────────┐     ┌─────────────┐
│ IoView │ ◄───► │ OpenOCD │ ◄──────► │ JtagHub │ ◄─► │ IoProbeTop │ ◄─► │ your design │
└────────┘       └─────────┘          └─────────┘     └────────────┘     └─────────────┘
```

## Interface

| Generic / port         | Meaning |
|------------------------|---------|
| `ASYNC_RESET`          | Asynchronous (`true`) or synchronous reset |
| `clk`, `rst`, `ce`     | Clock, reset (active high), clock enable |
| `dn_lines`, `up_lines` | To and from the hub, e.g. a channel of the [JtagHub](../JtagHub/README.md), or [`IpdbgUart`](../Uart/README.md) |
| `probe_inputs`         | Signals read by the host, at least 1 bit. All bits are sampled in the same clock cycle. |
| `probe_outputs`        | Signals set by the host, at least 1 bit. `0` after reset and after every connect of IoView. |
| `probe_outputs_update` | One clock cycle pulse when the host wrote the outputs |

The widths of `probe_inputs` and `probe_outputs` are taken from the signals
you connect and may differ; the host queries them.

## Instantiation

From the [Cmod S7 demo](../demo/cmod-s7/top.vhd): 10 inputs, the four LEDs
as outputs:

```vhdl
io_probe_i : entity work.IoProbeTop
    generic map(
        ASYNC_RESET => false
    )
    port map(
        clk                  => clk,
        rst                  => rst,
        ce                   => '1',
        dn_lines             => dn_lines_2,
        up_lines             => up_lines_2,
        probe_inputs         => io_probe_rd,  -- std_logic_vector(9 downto 0)
        probe_outputs        => leds,         -- std_logic_vector(3 downto 0)
        probe_outputs_update => open
    );
```

## Files

`IoProbeTop.vhd`, and in addition:

* from `rtl/BusAccess`: `BusAccessController.vhd` and
  `BusAccessStatemachine.vhd`,
* from `rtl/common`: `ipdbg_interface_pkg.vhd` and `IpdbgEscaping.vhd`.

The [co-simulation](../../sw/CoSim/README.md) runs IoProbe without hardware,
and the testbench of [`IpdbgUart`](../Uart/README.md#simulation) checks it
over the UART.

## License

[CERN-OHL-W-2.0](https://ohwr.org/cern_ohl_w_v2.txt)
