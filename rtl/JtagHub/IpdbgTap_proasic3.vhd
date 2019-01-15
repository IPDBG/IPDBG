library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library apa;

library work;
use work.IpdbgTap_pkg.ipdbg_TDI;
use work.IpdbgTap_pkg.ipdbg_TDO;
use work.IpdbgTap_pkg.ipdbg_TMS;
use work.IpdbgTap_pkg.ipdbg_TCK;
use work.IpdbgTap_pkg.ipdbg_TRSTB;

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
    signal TMS, TCK, TDI, TDO, TRSTB : std_logic;
begin

    user <= '1' when uireg = x"7f" else '0';

    TCK <= work.IpdbgTap_pkg.ipdbg_TCK;
    TDI <= work.IpdbgTap_pkg.ipdbg_TDI;
    TMS <= work.IpdbgTap_pkg.ipdbg_TMS;
    TRSTB <= work.IpdbgTap_pkg.ipdbg_TRSTB;
    work.IpdbgTap_pkg.ipdbg_TDO <= TDO;

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
            UTDO   => tdo,
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
