library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library  UNISIM;
use  UNISIM.vcomponents.all;

entity dffp is
    port(
        clk     : in  std_logic;
        ce      : in  std_logic;

        d       : in  std_logic;
        q       : out std_logic
    );
end entity;


architecture SevenSeries of dffp is


begin

    FF : FDRE
        generic map
        (
            INIT => '0'
        )
        port map
        (
          Q  => q,
          C  => clk,
          CE => ce,
          D  => d,
          R  => '0'
        );


end architecture SevenSeries;



