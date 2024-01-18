library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dffpcac is
    port(
        clk : in  std_logic;
        rst : in  std_logic;
        ce  : in  std_logic;
        d   : in  std_logic;
        q   : out std_logic
    );
end entity;

architecture iCE40_arch of dffpcac is
    component SB_DFFER
        port(
            d : in  std_logic;
            c : in  std_logic;
            e : in  std_logic;
            r : in  std_logic;
            q : out std_logic
        );
    end component;
begin
    SB_DFF_inst: SB_DFFER
        port map (
            C => clk,-- Clock
            R => rst,-- reset
            E => ce, -- clock enable
            D => d,  -- Data
            Q => q   -- Registered Output
        );
end architecture iCE40_arch;
