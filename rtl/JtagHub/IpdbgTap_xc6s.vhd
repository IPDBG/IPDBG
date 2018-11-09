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

    BSCAN_SPARTAN6_inst:  BSCAN_SPARTAN6
    port  map  (
        CAPTURE     =>  capture, -- CAPTURE  output  from  TAP  controller
        DRCK        =>  drclk,   -- Data  register  output  for  USER1  functions
        RESET       =>  open,   -- Reset  output  from  TAP  controller
        RUNTEST     => open,
        SEL         =>  user,    -- USER1  active  output
        SHIFT       =>  shift,   -- SHIFT  output  from  TAP  controller
        TDI         =>  tdi,     -- TDI  output  from  TAP  controller
        UPDATE      =>  update,  -- UPDATE  output  from  TAP  controller
        TDO         =>  tdo     -- Data  input  for  USER1  function
    );

end architecture xc3s_BSCAN;
