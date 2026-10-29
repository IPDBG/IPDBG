# SPDX-FileCopyrightText: The IPDBG authors
# SPDX-License-Identifier: MPL-2.0

"""The register behind the Wishbone master: it answers at every address,
each sel bit selects 16 bits."""

import BusAccess
from cosim_test import HOST, PORT_BUSACCESS, TIMEOUT_MS, fail

b = BusAccess.IpdbgBusAccess()
b.open(HOST, str(PORT_BUSACCESS))
b.setTimeout(TIMEOUT_MS)


def expect(address, value):
    r = b.read(address)
    if r != value:
        fail(f"read {address:#06x}: {r:#010x}, expected {value:#010x}")


b.setStrobe(0b11)
b.write(0x1234, 0xcafe1234)
expect(0x1234, 0xcafe1234)
b.setStrobe(0b01)
b.write(0x0000, 0xffffffff)
expect(0x0000, 0xcafeffff)
b.setStrobe(0b10)
b.write(0xffff, 0x5555aaee)  # 0x55 and 0xEE are escaped
expect(0xffff, 0x5555ffff)
b.setStrobe(0b11)
b.close()
print("ok")
