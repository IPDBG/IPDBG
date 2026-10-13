# Waveform Generator

Plays a waveform from a sample memory into your FPGA design, e.g. as
stimulus for a block under test. The host loads the samples and starts or
stops the playback, either from [sigrok](https://sigrok.org) or from your
own programs with the [WaveformGenerator library](../../sw/WaveformGenerator/README.md)
(C, C++, Python, GNU Octave).

Part of [IPDBG](https://github.com/IPDBG/IPDBG).

```
 PC                                                        FPGA
┌──────────────────────┐  TCP  ┌─────────┐  JTAG/…  ┌─────────┐     ┌──────────────────────┐     ┌─────────────┐
│ sigrok, C / C++ /    │ ◄───► │ OpenOCD │ ◄──────► │ JtagHub │ ◄─► │ WaveformGeneratorTop │ ──► │ your design │
│ Python / Octave      │       │         │          │         │     │                      │     │             │
└──────────────────────┘       └─────────┘          └─────────┘     └──────────────────────┘     └─────────────┘
```

## Interface

| Generic / port | Meaning |
|----------------|---------|
| `ADDR_WIDTH` | Size of the sample memory: 2^`ADDR_WIDTH` samples, default 13 |
| `ASYNC_RESET` | Asynchronous (`true`) or synchronous reset |
| `DOUBLE_BUFFER` | `true`: a second sample memory, so a new waveform can be written while playing without glitches. Default `false`. |
| `SYNC_MASTER` | `false`: after start, wait for `sync_in` before playing. Default `true`. |
| `clk`, `rst`, `ce` | Clock, reset (active high), clock enable |
| `dn_lines`, `up_lines` | To and from the hub, e.g. a channel of the [JtagHub](../JtagHub/README.md) |
| `data_out` | The samples. The width is taken from the signal you connect. `0` while nothing is playing. |
| `sample_enable` | The next sample is output every clock cycle in which `sample_enable` is `'1'`. Connect `'1'` to output a sample every clock cycle. |
| `first_sample` | `'1'` with the first sample of every repetition |
| `output_active` | `'1'` while the waveform is playing |
| `one_shot` | `'1'` plays the waveform once, like the one-shot command of the host. Default `'0'`. |
| `sync_out` | Pulses at the end of every repetition while playing repeatedly (not during a one-shot) |
| `sync_in` | Start of a generator with `SYNC_MASTER = false`. Default `'0'`. |

How start, one-shot and stop act, and what happens when a new waveform is
written while playing, is described in the
[WaveformGenerator library README](../../sw/WaveformGenerator/README.md#playback).

### Several generators in step

Connect `sync_out` of one generator (`SYNC_MASTER = true`) to `sync_in` of
the others (`SYNC_MASTER = false`). Started from the host, the others wait
for the end of the current repetition of the master and then play in step
with it.

## Protocol

For your own host tool instead of the library. The bytes to the core are
[escaped](../common/README.md#escaping). *D* and *A* are `data_out'length`
and `ADDR_WIDTH` in bytes (bits rounded up).

| Command | Then to the core | Answer |
|---------|------------------|--------|
| `0xF2` sizes | – | `data_out'length` and `ADDR_WIDTH`, 4 bytes each, least significant byte first |
| `0xF5` status | – | 1 byte: bit 0 = playing, bit 1 = `DOUBLE_BUFFER` |
| `0xF4` number of samples | *A* bytes: number − 1 | – |
| `0xF3` write samples | the samples, *D* bytes each | `0xFA` while writing, `0xFB` at the end |
| `0xF0` start | – | – |
| `0xF6` one shot | – | – |
| `0xF1` stop | – | – |

* Values are sent most significant byte first.
* Send `0xF4` before `0xF3`: the core expects that many samples.
* While receiving samples, the core sends `0xFA` after every 64 bytes,
  except after the last one, as a sign of life; it drops a `0xFA` while
  the host is not ready to take it. After the last sample it sends `0xFB`.

## Instantiation

From the [Cmod S7 demo](../demo/cmod-s7/top.vhd): 16 bit, 4096 samples,
a sample every clock cycle:

```vhdl
wfg_i : entity work.WaveformGeneratorTop
    generic map(
        ADDR_WIDTH    => 12,
        ASYNC_RESET   => false,
        DOUBLE_BUFFER => false,
        SYNC_MASTER   => true
    )
    port map(
        clk           => clk,
        rst           => rst,
        ce            => '1',
        dn_lines      => dn_lines_1,
        up_lines      => up_lines_1,
        data_out      => wfg_out,
        first_sample  => open,
        sample_enable => '1',
        output_active => open,
        one_shot      => '0',
        sync_out      => open,
        sync_in       => '0'
    );
```

## Files

| File | Content |
|------|---------|
| `WaveformGeneratorTop.vhd` | Top level |
| `WaveformGeneratorController.vhd` | Commands from the host, writing the samples |
| `WaveformGeneratorMemory.vhd` | Sample memory and playback |

In addition, from `rtl/common`: `ipdbg_interface_pkg.vhd`,
`IpdbgEscaping.vhd` and `pdpRam.vhd`.

The [co-simulation](../../sw/CoSim/README.md) runs the Waveform Generator
without hardware.

## License

[CERN-OHL-W-2.0](https://ohwr.org/cern_ohl_w_v2.txt)
