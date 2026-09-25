# IPDBG WaveformGenerator – Octave bindings

Octave bindings for the [IPDBG WaveformGenerator library](../README.md),
generated with SWIG from the C++ class `IpdbgWaveformGenerator`.

See the [main README](../README.md) for the concepts (widths, playback,
double buffer, sample values) and the supported core.

## Requirements

* Linux, or Windows with MinGW-w64 (e.g. [MSYS2](https://www.msys2.org))
* GNU Octave including development files (`mkoctfile`; `octave-devel` on
  Fedora, `octave-dev` on Debian/Ubuntu, `liboctave-dev` on older
  releases)
* SWIG
* GCC/G++ with C++17 support, GNU make

## Building

```sh
cd sw/WaveformGenerator/octave
make
```

This creates `WaveformGenerator.oct`.

* Linux: the module links `libWaveformGenerator.so` and builds it first if needed (see
  the [main README](../README.md#building)). It finds the library on its
  own, so `LD_LIBRARY_PATH` is not needed.
* Windows: the library is compiled into `WaveformGenerator.oct`, so no DLL has to be
  found at runtime.

To use the module from another directory, add `sw/WaveformGenerator/octave`
to the Octave search path, e.g.
`addpath("<path>/sw/WaveformGenerator/octave")`.

`make clean` removes the generated files.

## Usage

```octave
WaveformGenerator;
wfg = WaveformGenerator.IpdbgWaveformGenerator();
wfg.open("127.0.0.1", "4243");

wfg.getDataWidth()
wfg.getMaxSamples()

% one period of a sine, full scale, signed
n = wfg.getMaxSamples();
amplitude = 2^(wfg.getDataWidth() - 1) - 1;
wave = round(amplitude * sin(2 * pi * (0:n-1) / n));

wfg.write(wave);
wfg.start();
wfg.isRunning()
wfg.close();
```

`WaveformGenerator;` loads the module once per session.

`write()` takes a real numeric vector (`double`, `single` or an integer
type). All values must be integers, round them first.

## Error handling

All errors raise an Octave error with a descriptive message, e.g. when the
connection fails, the waveform is longer than the sample memory or a sample
is outside the range of the data width:

```octave
try
  wfg.write(wave);
catch err
  disp(["writing the waveform failed: " err.message]);
end_try_catch
```

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
* Octave numbers are `double` by default and represent integers exactly
  only up to 2^53. For data widths above 53 bit, pass `int64` values, e.g.
  `wfg.write(int64(wave))`.
* Data widths above 64 bit can only be written through the C API.

## License

[MPL-2.0](https://www.mozilla.org/MPL/2.0/)
