# ipdbg

Python modules for [IPDBG](https://github.com/IPDBG/IPDBG), the
vendor-independent debugger for FPGAs:

- `BusAccess`: read and write registers through an IPDBG bus master core
  (AXI4-Lite, Wishbone, AHB, APB, Avalon, RISC-V DMI)
- `WaveformGenerator`: load and start waveforms in the IPDBG waveform
  generator core

The modules connect over TCP to an IPDBG host server, e.g. OpenOCD for JTAG.

```sh
pip install ipdbg
```

```python
import BusAccess

ba = BusAccess.IpdbgBusAccess()
ba.open("127.0.0.1", "4245")
ba.write(0x10, 0xcafe)
print(hex(ba.read(0x10)))
ba.close()
```

```python
import WaveformGenerator

wfg = WaveformGenerator.IpdbgWaveformGenerator()
wfg.open("127.0.0.1", "4243")
wfg.write(list(range(256)))
wfg.start()
wfg.close()
```

Documentation:
[BusAccess](https://github.com/IPDBG/IPDBG/blob/master/sw/BusAccess/python/README.md),
[WaveformGenerator](https://github.com/IPDBG/IPDBG/blob/master/sw/WaveformGenerator/python/README.md).

License: [MPL-2.0](https://www.mozilla.org/MPL/2.0/)
