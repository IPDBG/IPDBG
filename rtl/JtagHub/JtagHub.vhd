library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ipdbg_interface_pkg.all;

entity JtagHub is
    generic(
        MFF_LENGTH          : natural := 3;
        FLOW_CONTROL_ENABLE : std_logic_vector(6 downto 0)
    );
    port(
        clk        : in  std_logic;
        ce         : in  std_logic;

        dn_lines_0 : out ipdbg_dn_lines;
        dn_lines_1 : out ipdbg_dn_lines;
        dn_lines_2 : out ipdbg_dn_lines;
        dn_lines_3 : out ipdbg_dn_lines;
        dn_lines_4 : out ipdbg_dn_lines;
        dn_lines_5 : out ipdbg_dn_lines;
        dn_lines_6 : out ipdbg_dn_lines;
        up_lines_0 : in  ipdbg_up_lines := unused_up_lines;
        up_lines_1 : in  ipdbg_up_lines := unused_up_lines;
        up_lines_2 : in  ipdbg_up_lines := unused_up_lines;
        up_lines_3 : in  ipdbg_up_lines := unused_up_lines;
        up_lines_4 : in  ipdbg_up_lines := unused_up_lines;
        up_lines_5 : in  ipdbg_up_lines := unused_up_lines;
        up_lines_6 : in  ipdbg_up_lines := unused_up_lines
    );
end entity JtagHub;

architecture structure of JtagHub is
    component JtagCdc is
        generic(
            MFF_LENGTH          : natural;
            FLOW_CONTROL_ENABLE : std_logic_vector(6 downto 0)
        );
        port(
            clk        : in  std_logic;
            ce         : in  std_logic;

            dn_lines_0 : out ipdbg_dn_lines;
            dn_lines_1 : out ipdbg_dn_lines;
            dn_lines_2 : out ipdbg_dn_lines;
            dn_lines_3 : out ipdbg_dn_lines;
            dn_lines_4 : out ipdbg_dn_lines;
            dn_lines_5 : out ipdbg_dn_lines;
            dn_lines_6 : out ipdbg_dn_lines;

            up_lines_0 : in  ipdbg_up_lines;
            up_lines_1 : in  ipdbg_up_lines;
            up_lines_2 : in  ipdbg_up_lines;
            up_lines_3 : in  ipdbg_up_lines;
            up_lines_4 : in  ipdbg_up_lines;
            up_lines_5 : in  ipdbg_up_lines;
            up_lines_6 : in  ipdbg_up_lines;

            DRCLK      : in  std_logic;
            USER       : in  std_logic;
            UPDATE     : in  std_logic;
            CAPTURE    : in  std_logic;
            SHIFT      : in  std_logic;
            TDI        : in  std_logic;
            TDO        : out std_logic
        );
    end component JtagCdc;
    component IpdbgTap is
        port(
            capture : out std_logic;
            drclk   : out std_logic;
            user    : out std_logic;
            shift   : out std_logic;
            update  : out std_logic;
            tdi     : out std_logic;
            tdo     : in  std_logic
        );
    end component IpdbgTap;

    signal DRCLK   : std_logic;
    signal USER    : std_logic;
    signal UPDATE  : std_logic;
    signal CAPTURE : std_logic;
    signal SHIFT   : std_logic;
    signal TDI     : std_logic;
    signal TDO     : std_logic;

begin

    TT: component IpdbgTap
        port map (
            capture => CAPTURE,
            drclk   => DRCLK,
            user    => USER,
            shift   => SHIFT,
            update  => UPDATE,
            tdi     => TDI,
            tdo     => TDO
        );

    CDC : component JtagCdc
        generic map(
            MFF_LENGTH          => MFF_LENGTH,
            FLOW_CONTROL_ENABLE => FLOW_CONTROL_ENABLE
        )
        port map(
            clk        => clk,
            ce         => ce,
            dn_lines_0 => dn_lines_0,
            dn_lines_1 => dn_lines_1,
            dn_lines_2 => dn_lines_2,
            dn_lines_3 => dn_lines_3,
            dn_lines_4 => dn_lines_4,
            dn_lines_5 => dn_lines_5,
            dn_lines_6 => dn_lines_6,
            up_lines_0 => up_lines_0,
            up_lines_1 => up_lines_1,
            up_lines_2 => up_lines_2,
            up_lines_3 => up_lines_3,
            up_lines_4 => up_lines_4,
            up_lines_5 => up_lines_5,
            up_lines_6 => up_lines_6,
            DRCLK      => DRCLK,
            USER       => USER,
            UPDATE     => UPDATE,
            CAPTURE    => CAPTURE,
            SHIFT      => SHIFT,
            TDI        => TDI,
            TDO        => TDO
        );

end architecture structure;
