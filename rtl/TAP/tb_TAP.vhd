library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_TAP is
end tb_TAP ;

architecture test of tb_TAP  is

    component TAP is
        port(
            --clk     : out std_logic;
            --reset   : out std_logic;
            Capture : out std_logic;
            Shift   : out std_logic;
            Update  : out std_logic;
            TDI_o   : out std_logic;
            TDO_i   : in  std_logic;
            SEL     : out std_logic;
            DRCK    : out std_logic;
            TDI_i   : in  std_logic;
            TDO_o   : out std_logic;
            TMS     : in  std_logic;
            TCK     : in  std_logic
        );
    end component TAP;

    constant T                 : time := 10 ns;

    signal Capture : std_logic;
    signal Shift   : std_logic;
    signal Update  : std_logic;
    signal TDI_o   : std_logic;
    signal TDO_i   : std_logic;
    signal SEL     : std_logic;
    signal DRCK    : std_logic;
    signal TDI_i   : std_logic;
    signal TDO_o   : std_logic;
    signal TMS     : std_logic;
    signal TCK     : std_logic;


begin
    process begin
        TCK <= '0';
        wait for T/2;
        TCK <= '1';
        wait for (T-(T/2));
    end process;
    process begin
        wait for T;
        TMS <= '1';
        wait for T;
        TMS <= '1';
        wait for T;
        TMS <= '0';
        wait for T;
        TMS <= '0';
        wait for T;

        wait for T;
        TMS <= '0';
        TDI_i <= '1';
        wait for T;
        TMS <= '0';
        TDI_i <= '0';
        wait for T;
        TMS <= '0';
        TDI_i <= '1';
        wait for T;
        TMS <= '0';
        TDI_i <= '0';
        wait for T;
        TMS <= '0';
        TDI_i <= '1';
        wait for T;
        TMS <= '0';
        TDI_i <= '0';
        wait for T;
        TMS <= '0';
        TDI_i <= '1';
        wait for T;
        TMS <= '1';
        TDI_i <= '0';

        --wait for T;
        --TMS <= '1';
        wait for T;
        TMS <= '1';
        wait for T;
        TMS <= '1';

        wait for T;
        TMS <= '0';
        wait for T;
        TMS <= '0';

        wait for T;
        TMS <= '0';
        TDI_i <= '1';
        wait for T;
        TMS <= '0';
        TDI_i <= '1';
        wait for T;
        TMS <= '0';
        TDI_i <= '1';
        wait for T;
        TMS <= '0';
        TDI_i <= '1';
        wait for T;
        TMS <= '0';
        TDI_i <= '1';
        wait for T;
        TMS <= '0';
        TDI_i <= '1';
        wait for T;
        TMS <= '0';
        TDI_i <= '1';
        wait for T;
        TMS <= '0';
        TDI_i <= '1';
        wait for T;
        TMS <= '0';
        TDI_i <= '1';

        wait for T;
        TMS <= '1';
        wait for T;
        TMS <= '1';
        wait for T;
        TMS <= '1';
--------------------

    end process;





    UUT : component TAP
        port map(
            --clk     => clk,
            --reset   => reset,
            Capture => Capture,
            Shift   => Shift,
            Update  => Update,
            TDI_o   => TDI_o,
            TDO_i   => TDO_i,
            SEL     => SEL,
            DRCK    => DRCK,
            TDI_i   => TDI_i,
            TDO_o   => TDO_o,
            TMS     => TMS,
            TCK     => TCK
        );




end architecture test;
