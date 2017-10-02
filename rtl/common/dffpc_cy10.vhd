library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dffpc is
    port(
        clk : in  std_logic;
        ce  : in  std_logic;
        d   : in  std_logic;
        q   : out std_logic
    );
end entity dffpc;

architecture cyc10 of dffpc is
    component DFFE
        port (
                d    : in  std_logic;   -- Data input
                clk  : in  std_logic;   -- Clock
                clrn : in  std_logic;   -- Clear (Reset, low-active)
                prn  : in  std_logic;   -- Preset (low-active)
                ena  : in  std_logic;   -- (Clock) Enable
                q    : out std_logic    -- Data output
        );
    end component DFFE;
begin
    FF : component DFFE
         port map(
                d    => d,
                clk  => clk,
                clrn => '1',
                prn  => '1',
                ena  => ce,
                q    => q
            );
end architecture cyc10;
