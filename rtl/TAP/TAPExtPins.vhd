library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.TAP_pkg.ipdbg_TDI;
use work.TAP_pkg.ipdbg_TDO;
use work.TAP_pkg.ipdbg_TMS;
use work.TAP_pkg.ipdbg_TCK;

entity TAPExtPins is
    port(
        TDI     : in  std_logic;
        TDO     : out std_logic;
        TMS     : in  std_logic;
        TCK     : in  std_logic
    );
end entity TAPExtPins;

architecture rtl of TAPExtPins is
begin
    TDO <= ipdbg_TDO;
    ipdbg_TDI <= TDI;
    ipdbg_TMS <= TMS;
    ipdbg_TCK <= TCK;
end architecture rtl;
