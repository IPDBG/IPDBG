library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dffp is
    port(
        clk     : in  std_logic;
        ce      : in  std_logic;

        d       : in  std_logic;
        q       : out std_logic
    );
end entity;


architecture behavioral of dffp is
    -- WARNING this is only useful for the simulation!
begin
    -- pragma translate_off
    gen: process (clk) begin
        if rising_edge(clk) then
            if ce = '1' then
                q <= d;
            end if;
        end if;
    end process;
    -- pragma translate_on

end architecture behavioral;



