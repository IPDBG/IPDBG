library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity IPDBG is
    generic(
        MFF_LENGTH : natural := 3;
        DATA_WIDTH : natural := 8;        --! width of a sample
        ADDR_WIDTH : natural := 8
    );
    port(
        clk                              : in  std_logic;

        Input_DeviceunderTest_IOVIEW     : in std_logic_vector(7 downto 0);
        Output_DeviceunderTest_IOVIEW    : out std_logic_vector(7 downto 0);
-------------------------- Debugging ------------------------
        Leds            : out std_logic_vector (7 downto 0)
    );
end IPDBG;

architecture structure of IPDBG is
    component Zaehler is
        generic(
            DATA_WIDTH : natural
        );
        port(
            clk      : in  std_logic;
            rst      : in  std_logic;
            ce       : in  std_logic;
            DatenOut : out std_logic_vector(DATA_WIDTH-1 downto 0);
            Debug    : out std_logic_vector(DATA_WIDTH-1 downto 0)
        );
    end component Zaehler;



    component JtagHub is
        generic(
            MFF_LENGTH        : natural;
            TARGET_TECHNOLOGY : natural
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
            DATAIN_GDB         : in  std_logic_vector (7 downto 0)
        );
    end component JtagHub;


    component LogicAnalyserTop is
        generic(
            DATA_WIDTH : natural;
            ADDR_WIDTH : natural
        );
        port(
            clk                 : in  std_logic;
            rst                 : in  std_logic;
            ce                  : in  std_logic;
            DataInValid         : in  std_logic;
            DataIn              : in  std_logic_vector(7 downto 0);
            DataReadyOut        : in  std_logic;
            DataValidOut        : out std_logic;
            DataOut             : out std_logic_vector(7 downto 0);
            SampleEn            : in  std_logic;
            DataDeviceunderTest : in  std_logic_vector(DATA_WIDTH-1 downto 0)
        );
    end component LogicAnalyserTop;

    component IoViewTop is
        port(
            clk          : in  std_logic;
            rst          : in  std_logic;
            ce           : in  std_logic;
            DataInValid  : in  std_logic;
            DataIn       : in  std_logic_vector(7 downto 0);
            DataOutReady : in  std_logic;
            DataOutValid : out std_logic;
            DataOut      : out std_logic_vector(7 downto 0);
            ProbeInputs  : in  std_logic_vector;
            ProbeOutputs : out std_logic_vector
        );
    end component IoViewTop;


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
    signal rst          : std_logic;
    signal ce           : std_logic;

    --signal Input_DeviceunderTest_IOVIEW     : std_logic_vector(7 downto 0);
    --signal Output_DeviceunderTest_IOVIEW    : std_logic_vector(7 downto 0);
    signal DataIn_LogicAnalyser             : std_logic_vector(DATA_WIDTH-1 downto 0);
    --signal stateDebug          : std_logic_vector(7 downto 0);

    signal DATAOUT            : std_logic_vector(7 downto 0);
    signal Enable_LA          : std_logic;
    signal Enable_IOVIEW      : std_logic;
    signal Enable_GDB         : std_logic;
    signal DATAINREADY_LA     : std_logic;
    signal DATAINREADY_IOVIEW : std_logic;
    signal DATAINREADY_GDB    : std_logic;
    signal DATAINVALID_LA     : std_logic;
    signal DATAINVALID_IOVIEW : std_logic;
    signal DATAINVALID_GDB    : std_logic;
    signal DATAIN_LA          : std_logic_vector (7 downto 0);
    signal DATAIN_IOVIEW      : std_logic_vector (7 downto 0);
    signal DATAIN_GDB         : std_logic_vector (7 downto 0);

begin

    DUT : component Zaehler
        generic map(
            DATA_WIDTH => DATA_WIDTH
        )
        port map(
            clk      => clk,
            rst      => '0',
            ce       => '1',
            DatenOut => DataIn_LogicAnalyser,
            Debug    => open
        );




    la : component LogicAnalyserTop
        generic map(
            DATA_WIDTH => DATA_WIDTH,
            ADDR_WIDTH => ADDR_WIDTH
        )
        port map(
            clk                 => clk,
            rst                 => '0',
            ce                  => '1',
            DataInValid         => Enable_LA,
            DataIn              => DATAOUT,
            DataReadyOut        => DATAINREADY_LA,
            DataValidOut        => DATAINVALID_LA,
            DataOut             => DATAIN_LA,
            SampleEn            => '1',
            DataDeviceunderTest => DataIn_LogicAnalyser
        );
    --DATAINVALID_LA <= '0';
    --LEDs <= Statedebug;

    IO : component IoViewTop
        port map(
            clk          => clk,
            rst          => '0',
            ce           => '1',
            DataInValid  => Enable_IOVIEW,
            DataIn       => DATAOUT,
            DataOutReady => DATAINREADY_IOVIEW,
            DataOutValid => DATAINVALID_IOVIEW,
            DataOut      => DATAIN_IOVIEW,
            ProbeInputs  => Input_DeviceunderTest_IOVIEW,
            ProbeOutputs => Output_DeviceunderTest_IOVIEW

        );
    --LEDs <= Output_DeviceunderTest_IOVIEW;


    JTAG : component JtagHub
        generic map(
            MFF_LENGTH        => MFF_LENGTH,
            TARGET_TECHNOLOGY => 1
        )
        port map(
            clk                => clk,
            ce                 => '1',
            DATAOUT            => DATAOUT,
            Enable_LA          => Enable_LA,
            Enable_IOVIEW      => Enable_IOVIEW,
            Enable_GDB         => open,

            DATAINREADY_LA     => DATAINREADY_LA,
            DATAINREADY_IOVIEW => DATAINREADY_IOVIEW,
            DATAINREADY_GDB    => DATAINREADY_GDB,
            DATAINVALID_LA     => DATAINVALID_LA,
            DATAINVALID_IOVIEW => DATAINVALID_IOVIEW,
            DATAINVALID_GDB    => '0',
            DATAIN_LA          => DATAIN_LA,
            DATAIN_IOVIEW      => DATAIN_IOVIEW,
            DATAIN_GDB         => (others => '0')
        );



end architecture structure;
