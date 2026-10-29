# SPDX-FileCopyrightText: The IPDBG authors
# SPDX-License-Identifier: MPL-2.0

"""sigrok-cli sets a square wave with the ipdbg-awg driver: sample rate 512
and frequency 32 give 512 samples with a period of 16, amplitude 1.0 gives
0x7fff and -0x7fff. The Logic Analyzer captures it with a trigger on the
rising edge of bit 15."""

from cosim_test import HOST, PORT_WFG, capture, expect_periodic, sigrok

HIGH, LOW = 0x7fff, 0x10000 - 0x7fff
WAVE = [HIGH] * 8 + [LOW] * 8

sigrok(f"--driver=ipdbg-awg:conn=tcp-raw/{HOST}/{PORT_WFG}",
       "--config", "samplerate=512:output_frequency=32:pattern=Rectangle:amplitude=1:enabled=true",
       "--set")
got = capture("awg", triggers="CH15=r")
expect_periodic("awg", got, WAVE, 255, {LOW})
print("ok")
