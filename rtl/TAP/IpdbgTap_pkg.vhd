library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package IpdbgTap_pkg is
    signal ipdbg_TDI : std_logic;
    signal ipdbg_TDO : std_logic;
    signal ipdbg_TMS : std_logic;
    signal ipdbg_TCK : std_logic;
end IpdbgTap_pkg;
