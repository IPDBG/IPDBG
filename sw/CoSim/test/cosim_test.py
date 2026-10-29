# SPDX-FileCopyrightText: The IPDBG authors
# SPDX-License-Identifier: MPL-2.0

"""Common parts of the CoSim checks: the ports of the demo design, the
Waveform Generator and captures with sigrok-cli."""

import os
import subprocess
import sys

HOST = "127.0.0.1"
PORT_LA = 4242
PORT_WFG = 4243
PORT_IOPROBE = 4244
PORT_BUSACCESS = 4245
PORT_LA_RL = 4246

SIGROK_CLI = os.environ.get("SIGROK_CLI", "sigrok-cli")
WORK = os.environ.get("COSIM_WORK")  # run.sh keeps the captures there
TIMEOUT_MS = 60000


def fail(message):
    print(message)
    sys.exit(1)


def play(samples):
    """Writes samples to the Waveform Generator and starts it."""
    import WaveformGenerator
    wfg = WaveformGenerator.IpdbgWaveformGenerator()
    wfg.open(HOST, str(PORT_WFG))
    wfg.setTimeout(TIMEOUT_MS)
    wfg.write(list(samples))
    wfg.start()
    wfg.close()


def sigrok(*args):
    """Runs sigrok-cli, returns its standard output."""
    r = subprocess.run([SIGROK_CLI, *args], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if r.returncode != 0:
        fail(f"sigrok-cli {' '.join(args)}: exit status {r.returncode}\n{r.stderr.decode(errors='replace')}")
    return r.stdout


def capture(name, port=PORT_LA, samples=512, triggers=None):
    """Captures with the Logic Analyzer on port, returns the 16 bit samples."""
    args = [f"--driver=ipdbg-la:conn=tcp-raw/{HOST}/{port}", "--samples", str(samples), "-O", "binary"]
    if triggers:
        args += ["--triggers", triggers]
    data = sigrok(*args)
    if WORK:
        with open(os.path.join(WORK, name + ".bin"), "wb") as f:
            f.write(data)
    if not data:
        fail(f"{name}: sigrok-cli returned no samples")
    return [int.from_bytes(data[i:i + 2], "little") for i in range(0, len(data) - 1, 2)]


def expect_periodic(name, got, wave, trigger_pos=None, at_trigger=None):
    """Checks that got is a part of the periodic waveform wave. With
    trigger_pos, the sample there must be one of at_trigger."""
    n = len(wave)
    if trigger_pos is not None:
        if got[trigger_pos] not in at_trigger:
            fail(f"{name}: sample {trigger_pos} (trigger) is {got[trigger_pos]:#06x}, "
                 f"expected {' or '.join(f'{v:#06x}' for v in at_trigger)}")
    for start in range(n):
        if all(got[i] == wave[(start + i) % n] for i in range(len(got))):
            return start
    # the longest matching start, for the message
    best, best_len = 0, -1
    for start in range(n):
        k = 0
        while k < len(got) and got[k] == wave[(start + k) % n]:
            k += 1
        if k > best_len:
            best, best_len = start, k
    fail(f"{name}: {len(got)} samples are not the waveform; sample {best_len} is "
         f"{got[best_len]:#06x}, expected {wave[(best + best_len) % n]:#06x}")
