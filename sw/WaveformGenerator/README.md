# IPDBG WaveformGenerator

Host-side library for the IPDBG Waveform Generator core. It loads a waveform
from a PC into the sample memory of the core and starts or stops the playback,
so you can drive stimuli into your FPGA design through an IPDBG connection.

Part of [IPDBG](https://github.com/IPDBG/IPDBG).

This directory contains:

| Path                                   | Content                                                  |
|----------------------------------------|----------------------------------------------------------|
| `WaveformGenerator.h/.c`               | C API                                                    |
| `WaveformGeneratorCxx.h/.cpp`          | C++ class `IpdbgWaveformGenerator` (wraps the C API)     |
| `WaveformGeneratorCxx.i`               | SWIG interface, shared by the Python and Octave bindings |
| `test.c`                               | Example program for the C API                            |
| [`python/`](python/README.md)          | Python bindings                                          |
| [`octave/`](octave/README.md)          | Octave bindings                                          |

The Waveform Generator can also be used from [sigrok](https://sigrok.org)
without this library.

## How it works

```
 PC                                              FPGA
┌──────────────────────┐   TCP   ┌─────────────┐   JTAG/…   ┌────────────────┐     ┌─────────────┐
│ C / C++ / Python /   │ ──────► │ IPDBG host  │ ─────────► │ IPDBG Waveform │ ──► │ your design │
│ Octave (this library)│         │ server      │            │ Generator core │     │             │
└──────────────────────┘         └─────────────┘            └────────────────┘     └─────────────┘
```

The library connects via TCP to an IPDBG host server, e.g. OpenOCD for JTAG.
IPDBG is transport-agnostic, so any other IPDBG host server works as well.

After connecting, the library queries two widths from the core. Both are
defined in the HDL, so the same host code works for any configuration:

| Width         | Defined by                     | Meaning                                         |
|---------------|--------------------------------|-------------------------------------------------|
| Data width    | width of the `data_out` port   | Bits per sample                                 |
| Address width | generic `ADDR_WIDTH`           | The sample memory holds 2^`ADDR_WIDTH` samples  |

### Playback

A waveform is a sequence of 1 to 2^`ADDR_WIDTH` samples. The core outputs
one sample on `data_out` per clock cycle in which `sample_enable` is `1`, so
`sample_enable` sets the sample rate.

| Command  | Effect                                                                  |
|----------|-------------------------------------------------------------------------|
| start    | Plays the waveform repeatedly until stop.                               |
| one-shot | Plays the waveform once. Ignored while the waveform is playing.         |
| stop     | Ends the playback. `data_out` is `0` while nothing is playing.          |

The core signals the playback on `output_active` and marks the first sample
of every repetition with `first_sample`. A one-shot can also be triggered by
the `one_shot` input of the core.

### Writing while playing

A new waveform can be written at any time. Its length is used from the next
repetition on.

* Without double buffer (generic `DOUBLE_BUFFER = false`), the new samples
  overwrite the memory that is being played. The current repetition can
  therefore contain a mix of old and new samples.
* With double buffer (`DOUBLE_BUFFER = true`), the new samples go to the
  second memory. The core switches to it at the end of the current
  repetition, so the output changes cleanly from the old to the new waveform.

The status reported by the core tells whether it has a double buffer.

### Sample values

On the wire and in the C API, every sample is transferred as
`ceil(data width / 8)` bytes, least significant byte first. The core ignores
bits beyond the data width.

The C++ class and the bindings take signed 64 bit integers. For a data width
of N bits, a sample must be in the range −2^(N−1) … 2^N−1. Negative values
are sent as two's complement, so both unsigned waveforms (0 … 2^N−1) and
signed ones (−2^(N−1) … 2^(N−1)−1) can be written directly. Values outside
this range are rejected.

## Supported core

The HDL core is in [`rtl/WaveformGenerator`](../../rtl/WaveformGenerator)
(`WaveformGeneratorTop`).

| Generic         | Default | Meaning                                                              |
|-----------------|---------|----------------------------------------------------------------------|
| `ADDR_WIDTH`    | 13      | Size of the sample memory: 2^`ADDR_WIDTH` samples                     |
| `DOUBLE_BUFFER` | `false` | Second sample memory for glitch-free updates while playing            |
| `SYNC_MASTER`   | `true`  | `false`: after start, wait for `sync_in` before playing               |
| `ASYNC_RESET`   | `true`  | Asynchronous or synchronous reset                                     |

`sync_out` pulses at the end of every repetition while playing repeatedly
(not during a one-shot). Connected to `sync_in` of
other Waveform Generators (with `SYNC_MASTER = false`), it lets several
generators start in step.

## Building

Requirements:

* Linux, or Windows with MinGW-w64 (e.g. [MSYS2](https://www.msys2.org))
* GCC/G++ (or Clang) with C++17 support, GNU make

```sh
cd sw/WaveformGenerator
make
```

This builds the library into `bin/Release`. On Linux:

| File                            | Purpose                                         |
|---------------------------------|-------------------------------------------------|
| `libWaveformGenerator.so.0.1.0` | The library (C API and C++ class)               |
| `libWaveformGenerator.so.0`     | Symlink, SONAME used by programs at runtime     |
| `libWaveformGenerator.so`       | Symlink used when linking                       |

On Windows:

| File                          | Purpose                                         |
|-------------------------------|-------------------------------------------------|
| `libWaveformGenerator.dll`    | The library (C API and C++ class)               |
| `libWaveformGenerator.dll.a`  | Import library used when linking                |

`make test` builds the example program `bin/Release/test` (`test.exe` on
Windows, see [Example](#example)). `make clean` removes the build output.

To use the library from your own program, add `sw/WaveformGenerator` to the
include path and link with
`-L<path>/sw/WaveformGenerator/bin/Release -lWaveformGenerator`.
At runtime the library has to be found:

* Linux: the loader has to find `libWaveformGenerator.so.0`, e.g. via
  `-Wl,-rpath,<path>/sw/WaveformGenerator/bin/Release` or `LD_LIBRARY_PATH`.
* Windows: `libWaveformGenerator.dll` has to be in the directory of your
  program or in `PATH`.

The Python and Octave bindings can be built on Linux and on Windows with
MSYS2.

## C API

Header: `WaveformGenerator.h`

### Connection

| Function                                               | Description                                   |
|--------------------------------------------------------|-----------------------------------------------|
| `IpdbgWaveformGenerator_new()`                         | Create a handle. Returns `NULL` on failure.   |
| `IpdbgWaveformGenerator_open(handle, host, port)`      | Connect, reset the command interface of the core and read its widths. A playing waveform is not affected. `host` and `port` are strings, e.g. `"127.0.0.1"`, `"4243"`. |
| `IpdbgWaveformGenerator_isOpen(handle)`                | Non-zero if connected.                        |
| `IpdbgWaveformGenerator_close(handle)`                 | Close the connection. The core keeps playing. |
| `IpdbgWaveformGenerator_delete(handle)`                | Close (if open) and free the handle.          |
| `IpdbgWaveformGenerator_getLastError(handle)`          | Description of the error of the last call on this handle, `""` if it succeeded. Never `NULL`. |

### Core information

| Function                                                        | Description                                   |
|-----------------------------------------------------------------|-----------------------------------------------|
| `IpdbgWaveformGenerator_getDataWidth(handle, &bits)`            | Bits per sample.                              |
| `IpdbgWaveformGenerator_getAddressWidth(handle, &bits)`         | Address width of the sample memory.           |
| `IpdbgWaveformGenerator_getMaxSamples(handle, &samples)`        | Size of the sample memory, 2^address width.   |
| `IpdbgWaveformGenerator_getStatus(handle, &running, &doubleBuffer)` | Whether a waveform is playing (start or one-shot) and whether the core has a double buffer. Either pointer may be `NULL`. |

### Waveform and playback

| Function                                                  | Description                                   |
|-----------------------------------------------------------|-----------------------------------------------|
| `IpdbgWaveformGenerator_write(handle, samples, count)`    | Write `count` samples (1 … max samples). `samples` holds `count * ceil(data width / 8)` bytes, each sample least significant byte first. Returns after the core has received the last sample. |
| `IpdbgWaveformGenerator_start(handle)`                    | Play repeatedly.                              |
| `IpdbgWaveformGenerator_stop(handle)`                     | Stop playing.                                 |
| `IpdbgWaveformGenerator_oneShot(handle)`                  | Play once.                                    |

`start`, `stop` and `oneShot` return after the core has received the command.

### Return values

| Value       | Meaning                                                  |
|-------------|----------------------------------------------------------|
| `RET_OK`    | Success.                                                 |
| `RET_ERROR` | Communication error, invalid handle or invalid argument. |

The values are the same as in `BusAccess.h`, so both headers can be included
in the same program.

The library does not print anything. After `RET_ERROR`,
`IpdbgWaveformGenerator_getLastError()` describes what went wrong, e.g.
`unable to connect to 127.0.0.1:4243 (Connection refused)`.

### Example

`test.c` is a complete example: it prints the widths and the status of the
core, writes a sawtooth and starts the generator.

```sh
make test
bin/Release/test 127.0.0.1 4243
```

Host and port are optional, the defaults are `127.0.0.1` and `4243`.

The core of it, for a core with a data width of 12 bit (2 bytes per sample):

```c
#include <stdio.h>
#include "WaveformGenerator.h"

int main(void)
{
    struct IpdbgWaveformGeneratorHandle *wfg = IpdbgWaveformGenerator_new();
    if (!wfg)
        return 1;
    if (IpdbgWaveformGenerator_open(wfg, "127.0.0.1", "4243") != RET_OK)
    {
        printf("%s\n", IpdbgWaveformGenerator_getLastError(wfg));
        IpdbgWaveformGenerator_delete(wfg);
        return 1;
    }

    /* 4 samples: 0x000, 0x7ff, 0xfff, 0x7ff, least significant byte first */
    const uint8_t samples[] = {0x00, 0x00, 0xff, 0x07, 0xff, 0x0f, 0xff, 0x07};

    if (IpdbgWaveformGenerator_write(wfg, samples, 4) != RET_OK ||
        IpdbgWaveformGenerator_start(wfg) != RET_OK)
        printf("%s\n", IpdbgWaveformGenerator_getLastError(wfg));

    IpdbgWaveformGenerator_delete(wfg);
    return 0;
}
```

## C++ API

Header: `WaveformGeneratorCxx.h` (requires C++17)

The class `IpdbgWaveformGenerator` wraps the C API. Samples are passed as
`std::vector<int64_t>` (see [Sample values](#sample-values)). All errors
throw a `std::runtime_error` with a descriptive message.

| Method                                            | Description                                   |
|---------------------------------------------------|-----------------------------------------------|
| `open(host, port)`, `close()`, `isOpen()`         | Connection                                    |
| `getDataWidth()`, `getAddressWidth()`             | Widths in bits                                |
| `getMaxSamples()`                                 | Size of the sample memory                     |
| `isRunning()`, `hasDoubleBuffer()`                | Status of the core                            |
| `write(samples)`                                  | Write the waveform                            |
| `start()`, `stop()`, `oneShot()`                  | Playback                                      |

`write()` checks the number of samples and every value before anything is
sent. Data widths above 64 bit are only supported by the C API.

```cpp
#include <cmath>
#include <iostream>
#include <vector>
#include "WaveformGeneratorCxx.h"

int main()
{
    IpdbgWaveformGenerator wfg;
    try {
        wfg.open("127.0.0.1", "4243");

        // one period of a sine, full scale, signed
        const size_t n = wfg.getMaxSamples();
        const double amplitude = std::ldexp(1.0, wfg.getDataWidth() - 1) - 1;
        std::vector<int64_t> wave(n);
        for (size_t i = 0; i < n; ++i)
            wave[i] = std::lround(amplitude * std::sin(2 * M_PI * i / n));

        wfg.write(wave);
        wfg.start();
        wfg.close();
    } catch (const std::runtime_error &e) {
        std::cerr << e.what() << '\n';
        return 1;
    }
}
```

## Language bindings

* [Python](python/README.md)
* [Octave](octave/README.md)

## License

* Hardware (`rtl/`): [CERN-OHL-W-2.0](https://ohwr.org/cern_ohl_w_v2.txt)
* Software (`sw/`): [MPL-2.0](https://www.mozilla.org/MPL/2.0/)
