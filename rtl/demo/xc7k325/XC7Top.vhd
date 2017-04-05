library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library unisim;
use unisim.vcomponents.all;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use ieee.std_logic_arith;

entity XC7Top is
    generic(
        MFF_LENGTH : natural := 3;
        DATA_WIDTH : natural := 8;        --! width of a sample
        ADDR_WIDTH : natural := 8
    );
    port(
        --clk                              : in  std_logic;
        Clk200M_P       : in std_logic;
        Clk200M_N       : in std_logic;

        --Input_DeviceunderTest_IOVIEW     : in std_logic_vector(7 downto 0);
        Output_DeviceunderTest_IOVIEW    : out std_logic_vector(3 downto 0)
-------------------------- Debugging ------------------------
        --Leds            : out std_logic_vector (7 downto 0)
    );
end XC7Top;

architecture structure of XC7Top is

    component JTAGHUB is
        generic(
            MFF_LENGTH : natural;
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
           --DRCLK              : out std_logic;
            DATAIN_GDB         : in  std_logic_vector (7 downto 0)
        );
    end component JTAGHUB;


    component The_LogicAnalyser is
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
            DataDeviceunderTest : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            stateDebug          : out std_logic_vector(7 downto 0)

        );
    end component The_LogicAnalyser;

    component IOView is
        port(
            clk                             : in  std_logic;
            rst                             : in  std_logic;
            ce                              : in  std_logic;
            DataInValid                     : in  std_logic;
            DataIn                          : in  std_logic_vector(7 downto 0);
            DataOutReady                    : in  std_logic;
            DataOutValid                    : out std_logic;
            DataOut                         : out std_logic_vector(7 downto 0);
            ProbeInputs                     : in  std_logic_vector;
            ProbeOutputs                    : out std_logic_vector

        );
    end component IOView;

    signal Clk                : std_logic;

    signal Input_DeviceunderTest_IOVIEW     : std_logic_vector(7 downto 0);
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
    signal count              : std_logic_vector (28 downto 0);
    signal output             : std_logic_vector (7 downto 0);
    signal temp               : std_logic_vector(7 downto 0);
    
    signal IoViewOutputs      : std_logic_vector(3 downto 0);

begin
    
        Counter : process (Clk) begin
            if rising_edge(Clk) then
                if output = "11111111" then
                    output <= "00000000";
                end if;
                if count =   "10111110101111000010000000000" then
                    count <= "00000000000000000000000000000";
                    output <= output +1;
                else
                    count <= count +1;
                end if;
            end if;
        end process;
        Input_DeviceunderTest_IOVIEW <= output;
        --Output_DeviceunderTest_IOVIEW <= count(3 downto 0); 

    la : component The_LogicAnalyser
        generic map(
            DATA_WIDTH => DATA_WIDTH,
            ADDR_WIDTH => ADDR_WIDTH
        )
        port map(
            clk                 => Clk,
            rst                 => '0',
            ce                  => '1',
            DataInValid         => Enable_LA,
            DataIn              => DATAOUT,

            DataReadyOut        => DATAINREADY_LA,
            DataValidOut        => DATAINVALID_LA,
            DataOut             => DATAIN_LA,

            SampleEn            => '1',
            DataDeviceunderTest => DataIn_LogicAnalyser,

            stateDebug          => open

        );
    --DATAINVALID_LA <= '0';
    --LEDs <= Statedebug;

    IO : component IOView
        port map(
            clk                             => Clk,
            rst                             => '0',
            ce                              => '1',

            DataInValid                     => Enable_IOVIEW,
            DataIn                          => DATAOUT,

            DataOutReady                    => DATAINREADY_IOVIEW,
            DataOutValid                    => DATAINVALID_IOVIEW,
            DataOut                         => DATAIN_IOVIEW,

            ProbeInputs    => Input_DeviceunderTest_IOVIEW,
            ProbeOutputs   => IoViewOutputs

        );
    Output_DeviceunderTest_IOVIEW <= IoViewOutputs;
    --LEDs <= Output_DeviceunderTest_IOVIEW;


    JTAG : component JTAGHUB
        generic map(
            MFF_LENGTH => MFF_LENGTH,
            TARGET_TECHNOLOGY => 3 --Kintex7
            
        )
        port map(
            clk                => Clk,
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
        
        Clk_fpga_gen: block
            signal  buffOut: std_logic;
        begin
            InputBufferInst: IBUFGDS
                generic map
                (
                    DIFF_TERM    => true,
                    IBUF_LOW_PWR => false
                )
                port map
                (
                    I  => Clk200M_P,
                    IB => Clk200M_N,
                    O  => buffOut
                );
            GlobalBufferInst : BUFG
                port map
                (
                    I => buffOut,
                    O => Clk
                );
        end block;



end architecture structure;
