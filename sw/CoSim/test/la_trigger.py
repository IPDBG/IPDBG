# SPDX-FileCopyrightText: The IPDBG authors
# SPDX-License-Identifier: MPL-2.0

"""The Waveform Generator plays a ramp 0..255, the Logic Analyzer captures it
with different triggers. Each capture must be the ramp, with the expected
value at the trigger (sample 255, sigrok's default capture ratio of 50 %)."""

from cosim_test import capture, expect_periodic, fail, play

RAMP = list(range(256))
TRIGGER_POS = 255


def value(v, bits=16):
    return [f"CH{i}={(v >> i) & 1}" for i in range(bits)]


CASES = [
    # name, triggers, possible values at the trigger
    ("value-0000", value(0x0000), {0x0000}),
    ("value-00a5", value(0x00a5), {0x00a5}),
    ("rising", ["CH7=r"], {0x0080}),
    ("falling", ["CH7=f"], {0x0000}),
    ("falling-and-value", ["CH4=f", "CH5=1", "CH6=1", "CH7=0"], {0x0060}),
    # either edge of CH2 with the other low bits 0001_x000: 0x10 or 0x14
    ("edge-and-value", ["CH2=e"] + [c for c in value(0x10, 8) if not c.startswith("CH2=")], {0x0010, 0x0014}),
]

play(RAMP)
for name, triggers, at_trigger in CASES:
    got = capture("la-" + name, triggers=",".join(triggers))
    if len(got) != 512:
        fail(f"{name}: {len(got)} samples, expected 512")
    expect_periodic(name, got, RAMP, TRIGGER_POS, at_trigger)
    print(f"{name}: ok")
