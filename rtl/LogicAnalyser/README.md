# Logic Analyzer

Records internal signals of your FPGA design and shows them in
[sigrok](https://sigrok.org) / [PulseView](https://sigrok.org/wiki/PulseView),
with all sigrok protocol decoders. The host side is the `ipdbg-la` driver of
libsigrok; there is no separate host program.

Part of [IPDBG](https://github.com/IPDBG/IPDBG).

```
 FPGA                                                        PC
┌─────────────┐     ┌──────────────────┐     ┌─────────┐  JTAG/…  ┌─────────┐  TCP  ┌──────────────────────┐
│ your design │ ──► │ LogicAnalyserTop │ ◄─► │ JtagHub │ ◄──────► │ OpenOCD │ ◄───► │ PulseView,           │
│             │     │                  │     │         │          │         │       │ sigrok-cli (ipdbg-la)│
└─────────────┘     └──────────────────┘     └─────────┘          └─────────┘       └──────────────────────┘
```

## Interface

| Generic / port | Meaning |
|----------------|---------|
| `ADDR_WIDTH` | Depth of the sample memory: 2^`ADDR_WIDTH` samples |
| `ASYNC_RESET` | Asynchronous (`true`) or synchronous reset |
| `USE_EXT_TRIGGER` | `false`: the trigger logic of the core (see below). `true`: `ext_trigger` instead of the trigger logic. |
| `RUN_LENGTH_COMPRESSION` | Width of the run-length counter, 0 to 32; 0 switches it off. See [Run-length compression](#run-length-compression). |
| `clk`, `rst`, `ce` | Clock, reset (active high), clock enable |
| `dn_lines`, `up_lines` | To and from the hub, e.g. a channel of the [JtagHub](../JtagHub/README.md) |
| `probe` | The signals to record. The width is taken from the signal you connect. |
| `sample_enable` | A sample is taken every clock cycle in which `sample_enable` is `'1'`. Connect `'1'` to sample every clock cycle. |
| `ext_trigger` | External trigger, only used with `USE_EXT_TRIGGER = true`. Default `'1'`: left open, it triggers immediately. |

The sample rate is the rate of `sample_enable`. The core does not report it,
so PulseView shows sample numbers instead of times.

## Trigger

The trigger logic matches the trigger settings of sigrok: per channel 0, 1,
rising, falling or any edge, set in PulseView or sigrok-cli. With
`USE_EXT_TRIGGER = true`, `ext_trigger` replaces it, e.g. to trigger on a
condition of your design.

The host sets how many samples before the trigger are kept (in sigrok the
*capture ratio*); the rest of the memory is filled after the trigger. When
the memory is full, the stored samples are written to the host.

## Run-length compression

With `RUN_LENGTH_COMPRESSION = N > 0`, the core stores a sample only when it
changes, together with an N-bit counter of how often it repeated. A memory of
2^`ADDR_WIDTH` words then covers up to 2^(`ADDR_WIDTH` + N) samples, as long
as the signals do not change too often.

The `ipdbg-la` driver of libsigrok does not support it yet; with the
released libsigrok, use `RUN_LENGTH_COMPRESSION = 0`. Support is in the
branch [`ipdbg-la-rlc`](https://github.com/danselmi/libsigrok/tree/ipdbg-la-rlc).

## Instantiation

From the [Cmod S7 demo](../demo/cmod-s7/top.vhd): 16 signals, 512 samples,
a sample in every clock cycle:

```vhdl
la_i : entity work.LogicAnalyserTop
    generic map(
        ADDR_WIDTH             => 9,
        ASYNC_RESET            => false,
        USE_EXT_TRIGGER        => false,
        RUN_LENGTH_COMPRESSION => 0
    )
    port map(
        clk           => clk,
        rst           => rst,
        ce            => '1',
        dn_lines      => dn_lines_0,
        up_lines      => up_lines_0,
        sample_enable => '1',
        ext_trigger   => '1',
        probe         => la_probe
    );
```

## Usage

Start the IPDBG server for the channel of the core, e.g. with OpenOCD (see
the [JtagHub README](../JtagHub/README.md#openocd)). Then connect in
PulseView (*Connect to Device* → driver *IPDBG Logic Analyzer*, interface
TCP, host `127.0.0.1` and the port) or with sigrok-cli:

```sh
sigrok-cli --driver=ipdbg-la:conn=tcp-raw/127.0.0.1/4242 --scan
sigrok-cli --driver=ipdbg-la:conn=tcp-raw/127.0.0.1/4242 --samples 512 -o capture.sr
```

The [co-simulation](../../sw/CoSim/README.md) runs the Logic Analyzer
without hardware.

## Files

| File | Content |
|------|---------|
| `LogicAnalyserTop.vhd` | Top level |
| `LogicAnalyserController.vhd` | Commands from the host, readout of the samples |
| `LogicAnalyserTrigger.vhd` | Trigger logic |
| `LogicAnalyserMemory.vhd` | Sample memory, samples before and after the trigger |
| `LogicAnalyserRunLengthCoder.vhd` | Run-length compression |

In addition, from `rtl/common`: `ipdbg_interface_pkg.vhd`,
`IpdbgEscaping.vhd` and `pdpRam.vhd`.

## License

[CERN-OHL-W-2.0](https://ohwr.org/cern_ohl_w_v2.txt)
