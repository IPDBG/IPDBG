library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity JtagHub is
    generic(
        MFF_LENGTH        : natural := 3
    );
    port(
       clk                : in  std_logic;
       ce                 : in  std_logic;

       DATAOUT            : out std_logic_vector(7 downto 0);

       Enable_LA          : out std_logic;
       Enable_IOVIEW      : out std_logic;
       Enable_GDB         : out std_logic;

       DATAINREADY_LA     : out std_logic;
       DATAINREADY_IOVIEW : out std_logic;
       DATAINREADY_GDB    : out std_logic;
       DATAINVALID_LA     : in  std_logic;
       DATAINVALID_IOVIEW : in  std_logic;
       DATAINVALID_GDB    : in  std_logic;
       DATAIN_LA          : in  std_logic_vector(7 downto 0);
       DATAIN_IOVIEW      : in  std_logic_vector(7 downto 0);
       DATAIN_GDB         : in  std_logic_vector(7 downto 0)
    );
end entity JtagHub;

architecture structure of JtagHub is
    component JtagCdc is
        generic(
            MFF_LENGTH : natural
        );
        port(
            clk                : in  std_logic;
            ce                 : in  std_logic;

            DATAOUT            : out std_logic_vector(7 downto 0);
            Enable_LA          : out std_logic;
            Enable_IOVIEW      : out std_logic;
            Enable_GDB         : out std_logic;

            DATAINREADY_LA     : out std_logic;
            DATAINREADY_IOVIEW : out std_logic;
            DATAINREADY_GDB    : out std_logic;
            DATAINVALID_LA     : in  std_logic;
            DATAINVALID_IOVIEW : in  std_logic;
            DATAINVALID_GDB    : in  std_logic;
            DATAIN_LA          : in  std_logic_vector (7 downto 0);
            DATAIN_IOVIEW      : in  std_logic_vector (7 downto 0);
            DATAIN_GDB         : in  std_logic_vector (7 downto 0);

            DRCLK              : in  std_logic;
            USER               : in  std_logic;
            UPDATE             : in  std_logic;
            CAPTURE            : in  std_logic;
            SHIFT              : in  std_logic;
            TDI                : in  std_logic;
            TDO                : out std_logic
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
            clk                => clk,
            ce                 => ce,

            DATAOUT            => DATAOUT,
            Enable_LA          => Enable_LA,
            Enable_IOVIEW      => Enable_IOVIEW,
            Enable_GDB         => Enable_GDB,

            DATAINREADY_LA     => DATAINREADY_LA,
            DATAINREADY_IOVIEW => DATAINREADY_IOVIEW,
            DATAINREADY_GDB    => DATAINREADY_GDB,
            DATAINVALID_LA     => DATAINVALID_LA,
            DATAINVALID_IOVIEW => DATAINVALID_IOVIEW,
            DATAINVALID_GDB    => DATAINVALID_GDB,
            DATAIN_LA          => DATAIN_LA,
            DATAIN_IOVIEW      => DATAIN_IOVIEW,
            DATAIN_GDB         => DATAIN_GDB,

            DRCLK              => DRCLK,
            USER               => USER,
            UPDATE             => UPDATE,
            CAPTURE            => CAPTURE,
            SHIFT              => SHIFT,
            TDI                => TDI,
            TDO                => TDO
        );

end architecture structure;
