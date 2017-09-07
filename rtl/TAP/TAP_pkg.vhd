library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package TAP_pkg is
    signal ipdbg_TDI : std_logic;
    signal ipdbg_TDO : std_logic;
    signal ipdbg_TMS : std_logic;
    signal ipdbg_TCK : std_logic;
end TAP_pkg;
