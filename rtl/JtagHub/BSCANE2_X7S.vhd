library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library  UNISIM;
use  UNISIM.vcomponents.all;

entity BSCAN is
    port(
        capture         : out  std_logic;
        DRCLK1          : out  std_logic;
        RESET           : out  std_logic;
        USER1           : out  std_logic;
        SHIFT           : out  std_logic;
        TCK             : out  std_logic;
        TDI             : out  std_logic;
        TMS             : out  std_logic;
        TDO1            : in   std_logic
    );
end entity;


architecture SevenSeries of BSCAN is


begin

    BSCAN_7Series_inst  :  BSCANE2
    generic map (
        JTAG_CHAIN => 1 --  Value for USER command.
    )
    port  map  (
        CAPTURE     => capture,            --  CAPTURE  output  from  TAP  controller
        DRCK        => DRCLK1,             --  Data  register  output  for  USER1  functions
        RESET       => RESET,              --  Reset  output  from  TAP  controller
        RUNTEST     => open,
        SEL         => USER1,              --  USER1  active  output
        SHIFT       => SHIFT,              --  SHIFT  output  from  TAP  controller
        TCK         => TCK,
        TDI         => TDI,                --  TDI  output  from  TAP  controller
        TMS         => TMS,
        TDO         => TDO1,               --  Data  input  for  USER1  function
    );



end architecture SevenSeries;



