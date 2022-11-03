library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library altera;
use altera.altera_primitives_components.all;

entity dffpc is
    port(
        clk : in  std_logic;
        ce  : in  std_logic;
        d   : in  std_logic;
        q   : out std_logic
    );
end entity dffpc;

architecture intel_arch of dffpc is
begin
    FF_inst : DFFE
        port map
        (
        clk  => clk,
        clrn => '1',
        prn  => '1',
        ena  => ce,
        d    => d,
        q    => q
        );
end architecture intel_arch;
