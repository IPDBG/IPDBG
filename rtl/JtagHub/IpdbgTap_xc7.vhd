library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library  UNISIM;
use  UNISIM.vcomponents.all;

entity IpdbgTap is
    port(
        capture : out std_logic;
        drclk   : out std_logic;
        user    : out std_logic;
        shift   : out std_logic;
        update  : out std_logic;
        tdi     : out std_logic;
        tdo     : in  std_logic
    );
end entity;


architecture SevenSeries_BSCAN2 of IpdbgTap is


begin

    BSCAN_7Series_inst  :  BSCANE2
    generic map (
        JTAG_CHAIN => 1 --  Value for USER command.
    )
    port  map  (
        CAPTURE     => capture, --  CAPTURE  output  from  TAP  controller
        DRCK        => drclk,   --  Data  register  output  for  USER1  functions
        RESET       => open,    --  Reset  output  from  TAP  controller
        RUNTEST     => open,
        SEL         => user,    --  USER1  active  output
        SHIFT       => shift,   --  SHIFT  output  from  TAP  controller
        TCK         => open,
        TDI         => tdi,     --  TDI  output  from  TAP  controller
        TMS         => open,
        UPDATE      => update,
        TDO         => tdo      --  Data  input  for  USER1  function
    );

end architecture SevenSeries_BSCAN2;



