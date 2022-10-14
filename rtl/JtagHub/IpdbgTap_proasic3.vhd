library ieee;
use ieee.std_logic_1164.all;

library apa;

entity IpdbgTap is
    port(
        TCK     : in  std_logic;
        TMS     : in  std_logic;
        TDI     : in  std_logic;
        TDO     : out std_logic;
        TRSTB   : in  std_logic;

        capture : out std_logic;
        drclk   : out std_logic;
        user    : out std_logic;
        shift   : out std_logic;
        update  : out std_logic;
        tdi_o   : out std_logic;
        tdo_i   : in  std_logic
    );
end entity IpdbgTap;

architecture proascic3 of IpdbgTap is
    component UJTAG
        port(
            UTDO   : in std_logic;
            TMS    : in std_logic;
            TDI    : in std_logic;
            TCK    : in std_logic;
            TRSTB  : in std_logic;
            URSTB  : out std_logic;
            UDRCK  : out std_logic;
            UDRCAP : out std_logic;
            UDRSH  : out std_logic;
            UDRUPD : out std_logic;
            UTDI   : out std_logic;
            UIREG0 : out std_logic;
            UIREG1 : out std_logic;
            UIREG2 : out std_logic;
            UIREG3 : out std_logic;
            UIREG4 : out std_logic;
            UIREG5 : out std_logic;
            UIREG6 : out std_logic;
            UIREG7 : out std_logic;
            TDO    : out std_logic
        );
    end component UJTAG;

    signal uireg : std_logic_vector(7 downto 0);
begin

    user <= '1' when uireg = x"7f" else '0';

    ujtag_inst: component UJTAG
        port map(
            -- must be routed to the top level and connected to
            -- ports named TCK, TMS, TDI, TDO, and
            -- TRSTB. There is no need to connect them to io pins
            TMS    => TMS,
            TDI    => TDI,
            TCK    => TCK,
            TDO    => TDO,
            TRSTB  => TRSTB,

            URSTB  => open,
            UDRCK  => drclk,
            UDRCAP => capture,
            UDRSH  => shift,
            UDRUPD => update,
            UTDI   => tdi,
            UTDO   => tdo_i,
            UIREG0 => uireg(0),
            UIREG1 => uireg(1),
            UIREG2 => uireg(2),
            UIREG3 => uireg(3),
            UIREG4 => uireg(4),
            UIREG5 => uireg(5),
            UIREG6 => uireg(6),
            UIREG7 => uireg(7)
        );

end architecture proascic3;
