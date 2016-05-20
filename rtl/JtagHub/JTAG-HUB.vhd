library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity JTAG_HUB is
    generic(
        MFF_LENGTH : natural
    );
    port(
       clk                : in  std_logic;
       rst                : in  std_logic;
       ce                 : in  std_logic;
       DATAOUT            : out std_logic_vector(7 downto 0);

       Enable_LA          : out std_logic;
       Enable_IOVIEW      : out std_logic;
       Enable_GDB         : out std_logic;

       DATAINREADY_LA        : out std_logic;
       DATAINREADY_IOVIEW        : out std_logic;
       DATAINREADY_GDB        : out std_logic;
       DATAINVALID_LA     : in  std_logic;
       DATAINVALID_IOVIEW : in  std_logic;
       DATAINVALID_GDB    : in  std_logic;
       DATAIN_LA          : in  std_logic_vector (7 downto 0);
       DATAIN_IOVIEW      : in  std_logic_vector (7 downto 0);
       DATAIN_GDB         : in  std_logic_vector (7 downto 0)
    );
end JTAG_HUB;

architecture structure of JTAG_HUB is
    component JTAG_CDC_Komponente is
        generic(
            MFF_LENGTH : natural
        );
        port(
            clk                : in  std_logic;
            rst                : in  std_logic;
            ce                 : in  std_logic;

            DATAOUT            : out std_logic_vector(7 downto 0);
            Enable_LA          : out std_logic;
            Enable_IOVIEW      : out std_logic;
            Enable_GDB         : out std_logic;

            DATAINREADY_LA        : out std_logic;
            DATAINREADY_IOVIEW        : out std_logic;
            DATAINREADY_GDB        : out std_logic;
            DATAINVALID_LA     : in  std_logic;
            DATAINVALID_IOVIEW : in  std_logic;
            DATAINVALID_GDB    : in  std_logic;
            DATAIN_LA          : in  std_logic_vector (7 downto 0);
            DATAIN_IOVIEW      : in  std_logic_vector (7 downto 0);
            DATAIN_GDB         : in  std_logic_vector (7 downto 0);

            DRCLK1             : in  std_logic;
            DRCLK2             : in  std_logic;
            USER1              : in  std_logic;
            USER2              : in  std_logic;
            UPDATE             : in  std_logic;
            CAPTURE            : in  std_logic;
            SHIFT              : in  std_logic;
            TDI                : in  std_logic;
            TDO1               : out std_logic;
            TDO2               : out std_logic;
            LEDS               : out std_logic_vector(7 downto 0)
        );
    end component JTAG_CDC_Komponente;


    component BSCAN is
        port(
            capture : out std_logic;
            DRCLK1  : out std_logic;
            DRCLK2  : out std_logic;
            RESET   : out std_logic;
            USER1   : out std_logic;
            USER2   : out std_logic;
            SHIFT   : out std_logic;
            TDI     : out std_logic;
            Update  : out std_logic;
            TDO1    : in  std_logic;
            TDO2    : in  std_logic
        );
    end component BSCAN;



    signal DRCLK1       : std_logic;
    signal DRCLK2       : std_logic;
    signal RESET        : std_logic;
    signal USER1        : std_logic;
    signal USER2        : std_logic;
    signal UPDATE       : std_logic;
    signal CAPTURE      : std_logic;
    signal SHIFT        : std_logic;
    signal TDI          : std_logic;
    signal TDO1         : std_logic;
    signal TDO2         : std_logic;

begin


    bscan_inst : component BSCAN
        port map(
            capture => CAPTURE,
            DRCLK1  => DRCLK1,
            DRCLK2  => DRCLK2,
            RESET   => RESET,
            USER1   => USER1,
            USER2   => USER2,
            SHIFT   => SHIFT,
            TDI     => TDI,
            Update  => UPDATE,
            TDO1    => TDO1,
            TDO2    => TDO2

        );


    CDC : component JTAG_CDC_Komponente
        generic map(
            MFF_LENGTH => MFF_LENGTH
        )
        port map(
            clk                => clk,
            rst                => rst,
            ce                 => ce,

            DATAOUT            => DATAOUT,
            Enable_LA          => Enable_LA,
            Enable_IOVIEW      => Enable_IOVIEW,
            Enable_GDB         => Enable_GDB,

            DATAINREADY_LA        => DATAINREADY_LA,
            DATAINREADY_IOVIEW        => DATAINREADY_IOVIEW,
            DATAINREADY_GDB        => DATAINREADY_GDB,
            DATAINVALID_LA     => DATAINVALID_LA,
            DATAINVALID_IOVIEW => DATAINVALID_IOVIEW,
            DATAINVALID_GDB    => DATAINVALID_GDB,
            DATAIN_LA          => DATAIN_LA,
            DATAIN_IOVIEW      => DATAIN_IOVIEW,
            DATAIN_GDB         => DATAIN_GDB,

            DRCLK1             => DRCLK1,
            DRCLK2             => DRCLK2,
            USER1              => USER1,
            USER2              => USER2,
            UPDATE             => UPDATE,
            CAPTURE            => CAPTURE,
            SHIFT              => SHIFT,
            TDI                => TDI,
            TDO1               => TDO1,
            TDO2               => TDO2,
            LEDS               => open
        );





end architecture structure;
