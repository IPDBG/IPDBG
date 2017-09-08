library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library  UNISIM;
use  UNISIM.vcomponents.all;

entity dffpc is
    port(
        clk : in  std_logic;
        ce  : in  std_logic;
        d   : in  std_logic;
        q   : out std_logic
    );
end entity dffpc;

architecture xc3s of dffpc is
begin
    FF : FDRSE
        generic map
        (
            INIT => '0'
        )
        port map
        (
            Q  => q,
            C  => clk,
            CE => ce,
            D  => d,
            R  => '0',
            S  => '0'
        );
end architecture xc3s;
