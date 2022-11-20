library ieee;
use ieee.std_logic_1164.all;

entity dffpc is
    port(
        clk : in  std_logic;
        ce  : in  std_logic;
        d   : in  std_logic;
        q   : out std_logic
    );
end entity dffpc;

architecture gowin_arch of dffpc is
    component DFFE
        generic (
            INIT : bit
        );
        port(
            Q   : out std_logic;
            D   : in  std_logic;
            CLK : in  std_logic;
            CE  : in  std_logic
        );
    end component;
begin
    dffe_i : DFFE
        generic map(
            INIT => '0'
        )
        port map (
            Q   => q,
            D   => d,
            CLK => clk,
            CE  => ce
        );

end architecture gowin_arch;
