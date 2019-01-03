library ieee;
use ieee.std_logic_1164.all;

library apa;

entity dffpc is
    port(
        clk : in  std_logic;
        ce  : in  std_logic;
        d   : in  std_logic;
        q   : out std_logic
    );
end entity dffpc;

architecture proasic3 of dffpc is
    component DFN1E1
        port(
            CLK : in  std_logic;
            D   : in  std_logic;
            E   : in  std_logic;
            Q   : out std_logic
        );
    end component DFN1E1;
begin
    FF : DFN1E1
        port map
        (
            CLK => clk,
            D   => d,
            E   => ce,
            Q   => q
        );
end architecture proasic3;
