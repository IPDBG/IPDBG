library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;


entity dffp is
    port(
        clk     : in  std_logic;
        ce      : in  std_logic;

        d       : in  std_logic;
        q       : out std_logic
    );
end entity;


architecture iCE40 of dffp is

    component SB_DFFE
        port(
            d : in  std_logic;
            c : in  std_logic;
            e : in  std_logic;
            q : out std_logic
        );
    end component;

begin

    SB_DFF_inst: SB_DFF
    port map (
        E => ce,    -- clock enable
        Q => q,     -- Registered Output
        C => clk,   -- Clock
        D => d      -- Data
    );


end architecture iCE40;



