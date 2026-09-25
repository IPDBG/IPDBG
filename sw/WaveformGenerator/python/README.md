# IPDBG WaveformGenerator – Python bindings

Python bindings for the [IPDBG WaveformGenerator library](../README.md),
generated with SWIG from the C++ class `IpdbgWaveformGenerator`.

See the [main README](../README.md) for the concepts (widths, playback,
double buffer, sample values) and the supported core.

## Requirements

* Linux, or Windows with [MSYS2](https://www.msys2.org) (MinGW-w64 and the
  MSYS2 Python)
* Python 3 including development headers (`python3-devel` on Fedora,
  `python3-dev` on Debian/Ubuntu)
* SWIG
* GCC/G++ with C++17 support, GNU make

## Building

```sh
cd sw/WaveformGenerator/python
make
```

This creates `WaveformGenerator.py` and the extension module:

* Linux: `_WaveformGenerator.so`. It links `libWaveformGenerator.so` and builds it first if
  needed (see the [main README](../README.md#building)). It finds the
  library on its own, so `LD_LIBRARY_PATH` is not needed.
* Windows: `_WaveformGenerator` with the suffix reported by
  `python3-config --extension-suffix`, e.g.
  `_WaveformGenerator.cp312-mingw_x86_64_ucrt_gnu.pyd`. The library is compiled into
  the module, so no DLL has to be found at runtime. The module only works
  with the MSYS2 Python it was built for, not with the Python from
  python.org.

The module is built for the Python version that `python3-config` belongs to.
If that is not the version you run `python3` with, select it explicitly, e.g.
`make PYTHON3_CONFIG=python3.13-config`.

To import the module from another directory, add
`sw/WaveformGenerator/python` to `PYTHONPATH`.

`make clean` removes the generated files.

## Usage

```python
import math
import WaveformGenerator

wfg = WaveformGenerator.IpdbgWaveformGenerator()
wfg.open("127.0.0.1", "4243")

print(wfg.getDataWidth(), wfg.getAddressWidth(), wfg.getMaxSamples())

# one period of a sine, full scale, signed
n = wfg.getMaxSamples()
amplitude = 2 ** (wfg.getDataWidth() - 1) - 1
wave = [round(amplitude * math.sin(2 * math.pi * i / n)) for i in range(n)]

wfg.write(wave)
wfg.start()
print(wfg.isRunning())
wfg.close()
```

`write()` takes any sequence of integers, e.g. a list, a tuple or a `range`.
Floats are rejected, round them first.

## Error handling

Errors of the library raise a `RuntimeError` with a descriptive message, e.g.
when the connection fails, the waveform is longer than the sample memory or
a sample is outside the range of the data width:

```python
try:
    wfg.write(wave)
except RuntimeError as e:
    print(f"writing the waveform failed: {e}")
```

Invalid arguments to `write()` are rejected before the library is called:
a `TypeError` for anything that is not a sequence of integers, an
`OverflowError` for a value outside the signed 64 bit range.

## API

| Method                                      | Description                                   |
|---------------------------------------------|-----------------------------------------------|
| `open(host, port)`                          | Connect to the IPDBG host server. Both arguments are strings. |
| `close()`, `isOpen()`                       | Connection                                    |
| `getDataWidth()`, `getAddressWidth()`       | Widths in bits                                |
| `getMaxSamples()`                           | Size of the sample memory                     |
| `isRunning()`, `hasDoubleBuffer()`          | Status of the core                            |
| `write(samples)`                            | Write the waveform                            |
| `start()`, `stop()`, `oneShot()`            | Playback                                      |

Notes:

* For a data width of N bits, samples must be in the range
  −2^(N−1) … 2^N−1. Negative values are sent as two's complement.
* Data widths above 64 bit can only be written through the C API.

## License

[MPL-2.0](https://www.mozilla.org/MPL/2.0/)
