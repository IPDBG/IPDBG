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

architecture ecp5 of dffpc is
	component FD1P3BX is
		port(
			Q  : out std_logic;
			CK : in  std_logic;
			SP : in  std_logic;
			PD : in  std_logic;
			D  : in  std_logic
		);
	end component FD1P3BX;
begin
    FF : FD1P3BX
        port map
        (
            Q  => q,
            CK => clk,
            SP => ce,
			PD => '0',
            D  => d
        );
end architecture ecp5;
