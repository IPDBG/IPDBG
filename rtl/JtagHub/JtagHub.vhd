library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity JtagHub is
    generic(
        MFF_LENGTH        : natural := 3
    );
    port(
        clk                  : in  std_logic;
        ce                   : in  std_logic;

        data_dwn             : out std_logic_vector(7 downto 0);

        data_dwn_valid_la    : out std_logic;
        data_dwn_valid_ioview: out std_logic;
        data_dwn_valid_gdb   : out std_logic;
        data_dwn_valid_wfg   : out std_logic;

        data_up_ready_la     : out std_logic;
        data_up_ready_ioview : out std_logic;
        data_up_ready_gdb    : out std_logic;
        data_up_ready_wfg    : out std_logic;

        data_up_valid_la     : in  std_logic;
        data_up_valid_ioview : in  std_logic;
        data_up_valid_gdb    : in  std_logic;
        data_up_valid_wfg    : in  std_logic;

        data_up_la           : in  std_logic_vector(7 downto 0);
        data_up_ioview       : in  std_logic_vector(7 downto 0);
        data_up_wfg          : in  std_logic_vector(7 downto 0);
        data_up_gdb          : in  std_logic_vector(7 downto 0)
    );
end entity JtagHub;

architecture structure of JtagHub is
    component JtagCdc is
        generic(
            MFF_LENGTH : natural
        );
        port(
            clk                  : in  std_logic;
            ce                   : in  std_logic;

            data_dwn             : out std_logic_vector(7 downto 0);
            data_dwn_valid_la    : out std_logic;
            data_dwn_valid_ioview: out std_logic;
            data_dwn_valid_gdb   : out std_logic;
            data_dwn_valid_wfg   : out std_logic;

            data_up_ready_la     : out std_logic;
            data_up_ready_ioview : out std_logic;
            data_up_ready_gdb    : out std_logic;
            data_up_ready_wfg    : out std_logic;

            data_up_valid_la     : in  std_logic;
            data_up_valid_ioview : in  std_logic;
            data_up_valid_gdb    : in  std_logic;
            data_up_valid_wfg    : in  std_logic;

            data_up_la           : in  std_logic_vector (7 downto 0);
            data_up_ioview       : in  std_logic_vector (7 downto 0);
            data_up_gdb          : in  std_logic_vector (7 downto 0);
            data_up_wfg          : in  std_logic_vector (7 downto 0);

            DRCLK                : in  std_logic;
            USER                 : in  std_logic;
            UPDATE               : in  std_logic;
            CAPTURE              : in  std_logic;
            SHIFT                : in  std_logic;
            TDI                  : in  std_logic;
            TDO                  : out std_logic
        );
    end component JtagCdc;
    component IpdbgTap is
        port(
            capture         : out std_logic;
            drclk           : out std_logic;
            user            : out std_logic;
            shift           : out std_logic;
            update          : out std_logic;
            tdi             : out std_logic;
            tdo             : in  std_logic
        );
    end component IpdbgTap;

    signal DRCLK        : std_logic;
    signal USER         : std_logic;
    signal UPDATE       : std_logic;
    signal CAPTURE      : std_logic;
    signal SHIFT        : std_logic;
    signal TDI          : std_logic;
    signal TDO          : std_logic;

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
            MFF_LENGTH => MFF_LENGTH
        )
        port map(
            clk                   => clk,
            ce                    => ce,

            data_dwn              => data_dwn,
            data_dwn_valid_la     => data_dwn_valid_la,
            data_dwn_valid_ioview => data_dwn_valid_ioview,
            data_dwn_valid_gdb    => data_dwn_valid_gdb,
            data_dwn_valid_wfg    => data_dwn_valid_wfg,

            data_up_ready_la      => data_up_ready_la,
            data_up_ready_ioview  => data_up_ready_ioview,
            data_up_ready_gdb     => data_up_ready_gdb,
            data_up_ready_wfg     => data_up_ready_wfg,

            data_up_valid_la      => data_up_valid_la,
            data_up_valid_ioview  => data_up_valid_ioview,
            data_up_valid_gdb     => data_up_valid_gdb,
            data_up_valid_wfg     => data_up_valid_wfg,

            data_up_la            => data_up_la,
            data_up_ioview        => data_up_ioview,
            data_up_gdb           => data_up_gdb,
            data_up_wfg           => data_up_wfg,

            DRCLK                 => DRCLK,
            USER                  => USER,
            UPDATE                => UPDATE,
            CAPTURE               => CAPTURE,
            SHIFT                 => SHIFT,
            TDI                   => TDI,
            TDO                   => TDO
        );

end architecture structure;
