# SPDX-FileCopyrightText: The IPDBG authors
# SPDX-License-Identifier: MPL-2.0

"""The IoProbe inputs show the 9 outputs twice."""

import BusAccess
from cosim_test import HOST, PORT_IOPROBE, TIMEOUT_MS, fail

p = BusAccess.IpdbgBusAccess()
p.open(HOST, str(PORT_IOPROBE))
p.setTimeout(TIMEOUT_MS)
if p.getCoreType() != BusAccess.CORE_TYPE_IOPROBE:
    fail(f"core type {p.getCoreType()}")
for v in (0x000, 0x1ff, 0x155, 0x0aa):
    p.write(0, v)
    r = p.read(0)
    if r != (v << 9) | v:
        fail(f"outputs {v:#05x}: inputs {r:#07x}, expected {(v << 9) | v:#07x}")
p.write(0, 0)
p.close()
print("ok")
