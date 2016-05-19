library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library  UNISIM;
use  UNISIM.vcomponents.all;

entity BSCAN is
    port(
        capture         : out  std_logic;
        DRCLK1          : out  std_logic;
        DRCLK2          : out  std_logic;
        RESET           : out  std_logic;
        USER1           : out  std_logic;
        USER2           : out  std_logic;
        SHIFT           : out  std_logic;
        TDI             : out  std_logic;
        Update          : out  std_logic;
        TDO1            : in  std_logic;
        TDO2            : in  std_logic
    );
end entity;


architecture xc3s of BSCAN is


begin

    BSCAN_SPARTAN3_inst  :  BSCAN_SPARTAN3
    port  map  (
        CAPTURE     =>  capture,            --  CAPTURE  output  from  TAP  controller
        DRCK1       =>  DRCLK1,             --  Data  register  output  for  USER1  functions
        DRCK2       =>  DRCLK2,             --  Data  register  output  for  USER2  functions
        RESET       =>  RESET,              --  Reset  output  from  TAP  controller
        SEL1        =>  USER1,              --  USER1  active  output
        SEL2        =>  USER2,              --  USER2  active  output
        SHIFT       =>  SHIFT,              --  SHIFT  output  from  TAP  controller
        TDI         =>  TDI,                --  TDI  output  from  TAP  controller
        UPDATE      =>  Update,             --  UPDATE  output  from  TAP  controller
        TDO1        =>  TDO1,               --  Data  input  for  USER1  function
        TDO2        =>  TDO2                --  Data  input  for  USER2  function
    );



end architecture xc3s;



