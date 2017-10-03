library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.IpdbgTap_pkg.ipdbg_TDI;
use work.IpdbgTap_pkg.ipdbg_TDO;
use work.IpdbgTap_pkg.ipdbg_TMS;
use work.IpdbgTap_pkg.ipdbg_TCK;
use work.IpdbgTap_pkg.ipdbg_TRSTB;

entity IpdbgTapExtPins is
    port(
        TMS     : in  std_logic;
        TCK     : in  std_logic;
        TDI     : in  std_logic;
        TDO     : out std_logic;
        TRSTB   : in  std_logic -- TRSTB is not used with IPDBG's own TAP
    );
end entity IpdbgTapExtPins;

architecture rtl of IpdbgTapExtPins is begin

    TDO         <= ipdbg_TDO;
    ipdbg_TDI   <= TDI;
    ipdbg_TMS   <= TMS;
    ipdbg_TCK   <= TCK;
    ipdbg_TRSTB <= TRSTB;

end architecture rtl;
