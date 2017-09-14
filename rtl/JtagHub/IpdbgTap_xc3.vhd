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

architecture xc3s_BSCAN of IpdbgTap is

begin

    BSCAN_SPARTAN3_inst:  BSCAN_SPARTAN3
    port  map  (
        CAPTURE     =>  capture, -- CAPTURE  output  from  TAP  controller
        DRCK1       =>  drclk,   -- Data  register  output  for  USER1  functions
        DRCK2       =>  open,    -- Data  register  output  for  USER2  functions
        RESET       =>  open,    -- Reset  output  from  TAP  controller
        SEL1        =>  user,    -- USER1  active  output
        SEL2        =>  open,    -- USER2  active  output
        SHIFT       =>  shift,   -- SHIFT  output  from  TAP  controller
        TDI         =>  tdi,     -- TDI  output  from  TAP  controller
        UPDATE      =>  update,  -- UPDATE  output  from  TAP  controller
        TDO1        =>  tdo,     -- Data  input  for  USER1  function
        TDO2        =>  '0'      -- Data  input  for  USER2  function
    );

end architecture xc3s_BSCAN;
