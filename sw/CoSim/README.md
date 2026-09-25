# IPDBG CoSim – try IPDBG without hardware

CoSim replaces the FPGA and the JTAG adapter with a
[GHDL](https://github.com/ghdl/ghdl) simulation of a small demo design.
OpenOCD connects to the simulation through its `remote_bitbang` adapter.
Everything above that – OpenOCD, the host tools and your scripts – is the
same as with real hardware.

Part of [IPDBG](https://github.com/IPDBG/IPDBG).

```
 PulseView, IoView,  ── TCP ──▶ OpenOCD ── remote_bitbang ──▶ CoSim
 Python, Octave, …   4242…4245           TCP port 3421       (GHDL simulation:
                                                              JTAG TAP, hub, IPDBG cores)
```

## Requirements

* Linux (CoSim uses POSIX sockets)
* GHDL with the LLVM or GCC backend. The mcode backend cannot link the
  simulation with the C++ part.
* G++, GNU make
* OpenOCD 1.0.0 or later, or OpenOCD from git including commit 52ea420
  (*ipdbg: simplify command chains*), with the IPDBG server and the
  `remote_bitbang` adapter. If your build lacks the adapter, configure
  OpenOCD with `--enable-remote-bitbang`.
* The host tools you want to try, see [The demo design](#the-demo-design).

## Building and starting

```sh
cd sw/CoSim
make
./CoSim
```

`./CoSim` waits until OpenOCD connects on port 3421 and only then starts
the simulation. In a second terminal:

```sh
cd sw/CoSim
openocd -f ipdbg_JtagSim.cfg
```

OpenOCD now serves the four IPDBG cores of the demo design on the ports
4242 to 4245. The simulation runs until you stop it with Ctrl-C.

To record the signals of the simulation for
[GTKWave](https://gtkwave.sourceforge.net), start CoSim with any argument:

```sh
./CoSim 1      # writes wave.ghw
```

The file grows quickly, so keep these runs short.

`make cleanall` removes the build output.

## The demo design

The demo design ([`tb_top.vhd`](tb_top.vhd)) connects four IPDBG cores to
a JTAG hub:

| Port | Core               | Configuration |
|------|--------------------|---------------|
| 4242 | Logic Analyzer     | 16 channels, 512 samples, sampling every clock cycle |
| 4243 | Waveform Generator | 16 bit, 512 samples, no double buffer |
| 4244 | IoView             | 9 outputs, 18 inputs |
| 4245 | BusAccess          | Wishbone master (`WbMaster`), 16 bit address, 32 bit data, 2 bit `sel` |

The cores are connected to each other, so you can see the effect of one
tool in another:

* The Logic Analyzer records the output of the Waveform Generator. While
  the Waveform Generator is not playing, all channels are 0.
* The IoView inputs are the outputs, twice: input bits 17..9 and 8..0 both
  show output bits 8..0.
* Behind the Wishbone master is a single 32 bit register, which answers at
  every address. Each `sel` bit selects 16 bits of it. Every write is
  reported in the output of `./CoSim`.

Most tools suggest a different port than the one of the demo design, e.g.
PulseView suggests 5555. Enter the port from the table above.

## Trying the tools

### Waveform Generator and Logic Analyzer

Load a waveform into the Waveform Generator, e.g. a ramp from Python (see
[`sw/WaveformGenerator/python`](../WaveformGenerator/python/README.md) for
building the module):

```python
import WaveformGenerator

wfg = WaveformGenerator.IpdbgWaveformGenerator()
wfg.open("127.0.0.1", "4243")
wfg.write(list(range(256)))
wfg.start()
wfg.close()
```

Then capture it with the Logic Analyzer, either in PulseView
(*Connect to Device* → driver *IPDBG Logic Analyzer*, interface TCP,
host `127.0.0.1`, port `4242`) or with sigrok-cli:

```sh
sigrok-cli --driver=ipdbg-la:conn=tcp-raw/127.0.0.1/4242 --scan
sigrok-cli --driver=ipdbg-la:conn=tcp-raw/127.0.0.1/4242 --samples 512 -o ramp.sr
```

The [main README](../../README.md#features) shows a more elaborate example:
an I²C frame generated in Octave and decoded in PulseView.

### IoView

Start IoView, choose *IoView-IP* → *Connect* and enter host `127.0.0.1`
and port `4244`. IoView remembers the port for the next start. Every
output you set shows up twice at the inputs.

### BusAccess

With the Python bindings (see
[`sw/BusAccess/python`](../BusAccess/python/README.md)):

```python
import BusAccess

ba = BusAccess.IpdbgBusAccess()
ba.open("127.0.0.1", "4245")
ba.write(0x10, 0xcafebabe)
print(hex(ba.read(0x10)))
ba.close()
```

The write is reported in the output of `./CoSim`.

## Files

| File                | Content |
|---------------------|---------|
| `tb_top.vhd`        | Demo design: JTAG hub and the four IPDBG cores |
| `JtagAdapter.vhd`   | JTAG adapter driven by the `remote_bitbang` protocol |
| `main.cpp`          | TCP server for `remote_bitbang`, starts the GHDL simulation |
| `ipdbg_JtagSim.cfg` | OpenOCD configuration |
| `Makefile`          | Build |
| `CoSim.cbp`         | Code::Blocks project |

## License

* Hardware (`rtl/`): [CERN-OHL-W-2.0](https://ohwr.org/cern_ohl_w_v2.txt)
* Software (`sw/`): [MPL-2.0](https://www.mozilla.org/MPL/2.0/)
