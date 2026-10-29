# SPDX-FileCopyrightText: The IPDBG authors
# SPDX-License-Identifier: MPL-2.0

"""The Waveform Generator plays values that repeat 1 to 8 times, the Logic
Analyzer with run-length compression (port 4246) captures them. The 512
stored samples must give more than 512 samples, and these must be the
waveform."""

from cosim_test import PORT_LA_RL, capture, expect_periodic, play

WAVE = [v for v in range(64) for _ in range(1 + v % 8)]  # 288 samples

play(WAVE)
got = capture("la-rl", port=PORT_LA_RL)
if len(got) <= 512:
    print(f"{len(got)} samples, expected more than 512 from 512 compressed samples")
    raise SystemExit(1)
expect_periodic("la-rl", got, WAVE)
print(f"{len(got)} samples: ok")
