library ieee;
use ieee.std_logic_1164.all;

library efxphysicallib;
use efxphysicallib.efxcomponents.all;

entity dffpc is
    port(
        clk : in  std_logic;
        ce  : in  std_logic;
        d   : in  std_logic;
        q   : out std_logic
    );
end entity dffpc;

architecture efinix of dffpc is
begin
    EFX_FF_inst : EFX_FF
        generic map (
            CLK_POLARITY     => 1,
            CE_POLARITY      => 1,
            SR_POLARITY      => 1,
            D_POLARITY       => 1,
            SR_SYNC          => 1,
            SR_VALUE         => 0,
            SR_SYNC_PRIORITY => 1
        )
        port map (
            D   => d,
            CE  => ce,
            CLK => clk,
            SR  => '0',
            Q   => q
        );
end architecture efinix;
