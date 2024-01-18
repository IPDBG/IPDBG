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
end entity dffpcac;

architecture behavioral of dffpcac is
    -- WARNING this is only useful for the simulation!
begin
    -- pragma translate_off
    gen: process (rst, clk) begin
        if rst = '1' then
            q <= '0';
        elsif rising_edge(clk) then
            if ce = '1' then
                q <= d;
            end if;
        end if;
    end process;
    -- pragma translate_on
end architecture behavioral;
