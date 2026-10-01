# IpdbgUart – an IPDBG core over a UART

`IpdbgUart` connects one IPDBG core to the host over a UART: two user I/Os,
e.g. to the USB UART of the board. Use it where JTAG is not available, or in
addition to the JtagHub. On the host, [UartBridge](../../sw/UartBridge/README.md)
forwards a TCP port to the serial port, so the host tools work as with JTAG.

Part of [IPDBG](https://github.com/IPDBG/IPDBG).

```
 FPGA                                                             PC
┌───────────┐     ┌───────────┐  txd/rxd  ┌────────────┐  serial  ┌────────────┐  TCP  ┌────────────┐
│ one IPDBG │ ◄─► │ IpdbgUart │ ◄───────► │ USB UART   │ ◄──────► │ UartBridge │ ◄───► │ host tool  │
│ core      │     │           │           │ (e.g. FTDI)│   port   │            │       │ (IoView, …)│
└───────────┘     └───────────┘           └────────────┘          └────────────┘       └────────────┘
```

There is no hub: one `IpdbgUart` per core, each with its own two I/Os and
its own UartBridge. For several cores over one connection, use the
[JtagHub](../JtagHub/README.md).

## Interface

| Generic / port | Meaning |
|----------------|---------|
| `CLOCKS_PER_ONE_SIXTEENTH_BIT` | Clock cycles per 1/16 bit: baudrate = clock frequency / (16 × `CLOCKS_PER_ONE_SIXTEENTH_BIT`) |
| `NUM_META_FLOPS` | Number of synchronizer flip-flops for `rxd`, e.g. 3 |
| `ASYNC_RESET` | Asynchronous (`true`) or synchronous reset |
| `clk`, `rst`, `ce` | Clock, reset (active high), clock enable |
| `txd` | Serial output, to the RX input of the USB UART |
| `rxd` | Serial input, from the TX output of the USB UART |
| `dn_lines`, `up_lines` | To and from the IPDBG core, like a channel of the JtagHub |

Choose `CLOCKS_PER_ONE_SIXTEENTH_BIT` so that the baudrate is within 1 % of
the baudrate of UartBridge. Example: 100 MHz / (16 × 54) = 115741
baud, 0.5 % above 115200.

The frame format is fixed to 8N1 (8 data bits, no parity, 1 stop bit),
without hardware flow control, like UartBridge.

Limits:

* The core must take every byte from the host immediately. While
  `dnlink_ready` of the core is `'0'`, received bytes are lost; the UART
  cannot hold back the host.
* Framing errors are not detected.

## Instantiation

From the [Cmod S7 demo](../demo/cmod-s7/top.vhd), an IoProbe on the USB
UART of the board:

```vhdl
uart_i : entity work.IpdbgUart
    generic map(
        CLOCKS_PER_ONE_SIXTEENTH_BIT => 54,     -- 100 MHz, 115200 baud
        NUM_META_FLOPS               => 3,
        ASYNC_RESET                  => false
    )
    port map(
        clk      => clk,
        rst      => rst,
        ce       => '1',
        txd      => uart_tx,
        rxd      => uart_rx,
        dn_lines => dn_lines_uart,
        up_lines => up_lines_uart
    );

uart_probe_i : entity work.IoProbeTop
    generic map(
        ASYNC_RESET => false
    )
    port map(
        clk                  => clk,
        rst                  => rst,
        ce                   => '1',
        dn_lines             => dn_lines_uart,
        up_lines             => up_lines_uart,
        probe_inputs         => inputs,
        probe_outputs        => outputs,
        probe_outputs_update => open
    );
```

On the host:

```sh
UartBridge /dev/ttyUSB1 115200 4246
```

Then connect the host tool, here IoView, to port 4246.

## Files

| File | Content |
|------|---------|
| `IpdbgUart.vhd` | Connects receiver and transmitter to `dn_lines`/`up_lines` |
| `IpdbgUartRx.vhd` | Receiver, 16 times oversampling |
| `IpdbgUartTx.vhd` | Transmitter |
| `test/IpdbgUart_tb.vhd` | Self-checking testbench with an IoProbe core |

In addition: `rtl/common/ipdbg_interface_pkg.vhd` and the `dffpc` of your
FPGA family from `rtl/common` for the synchronizer of `rxd`, see the
[JtagHub README](../JtagHub/README.md#hub-variants-and-tap-files).
`dffpc_behav.vhd` is for simulation only.

## Simulation

With [GHDL](https://github.com/ghdl/ghdl):

```sh
cd rtl/Uart
ghdl -a --std=08 ../common/ipdbg_interface_pkg.vhd ../common/dffpc_behav.vhd \
    ../common/IpdbgEscaping.vhd ../BusAccess/BusAccessStatemachine.vhd \
    ../BusAccess/BusAccessController.vhd ../IoProbe/IoProbeTop.vhd \
    IpdbgUartTx.vhd IpdbgUartRx.vhd IpdbgUart.vhd test/IpdbgUart_tb.vhd
ghdl --elab-run --std=08 IpdbgUart_tb
```

The testbench sends the width query of the BusAccess protocol to an
IoProbe core over the UART and checks the 24 bytes of the answer. It ends
with `IpdbgUart_tb: passed` or stops at the first mismatch.

## License

[CERN-OHL-W-2.0](https://ohwr.org/cern_ohl_w_v2.txt)
