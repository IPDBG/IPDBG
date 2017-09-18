library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity XC7Top is
    generic(
        MFF_LENGTH : natural := 3;
        DATA_WIDTH : natural := 11;        --! width of a sample
        ADDR_WIDTH : natural := 14
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

    component JtagHub is
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
            DATAIN_GDB         : in  std_logic_vector (7 downto 0)
        );
    end component JtagHub;


    component LogicAnalyserTop is
        generic(
            DATA_WIDTH : natural;
            ADDR_WIDTH : natural
        );
        port(
            clk            : in  std_logic;
            rst            : in  std_logic;
            ce             : in  std_logic;
            data_in_valid  : in  std_logic;
            data_in        : in  std_logic_vector(7 downto 0);
            data_out_ready : in  std_logic;
            data_out_valid : out std_logic;
            data_out       : out std_logic_vector(7 downto 0);
            sample_en      : in  std_logic;
            probe          : in  std_logic_vector(DATA_WIDTH-1 downto 0)
        );
    end component LogicAnalyserTop;

    component IOViewTop is
        port(
            clk            : in  std_logic;
            rst            : in  std_logic;
            ce             : in  std_logic;
            data_in_valid  : in  std_logic;
            data_in        : in  std_logic_vector(7 downto 0);
            data_out_ready : in  std_logic;
            data_out_valid : out std_logic;
            data_out       : out std_logic_vector(7 downto 0);
            probe_inputs   : in  std_logic_vector;
            probe_outputs  : out std_logic_vector

        );
    end component IOViewTop;

    signal Clk                : std_logic;
    signal rst                : std_logic := '1';

    signal Input_DeviceunderTest_IOVIEW     : std_logic_vector(7 downto 0);
    --signal Output_DeviceunderTest_IOVIEW    : std_logic_vector(7 downto 0);
    signal DataIn_LogicAnalyser             : std_logic_vector(DATA_WIDTH-1 downto 0);
    constant DataIn_LogicAnalyser_max       : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '1');
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
            if DataIn_LogicAnalyser = DataIn_LogicAnalyser_max then
                DataIn_LogicAnalyser <= (others => '0');
            else
                DataIn_LogicAnalyser <= std_logic_vector(unsigned(DataIn_LogicAnalyser)+1);
            end if;

            if count =   "10111110101111000010000000000" then
                count <= "00000000000000000000000000000";
                 if output = "11111111" then
                     output <= "00000000";
                 else
                    output <= std_logic_vector(unsigned(output) + 1);
                 end if;
            else
                count <= std_logic_vector(unsigned(count) + 1);
            end if;
        end if;
    end process;
    Input_DeviceunderTest_IOVIEW <= output;
    --Output_DeviceunderTest_IOVIEW <= count(3 downto 0);

    la : component LogicAnalyserTop
        generic map(
            DATA_WIDTH => DATA_WIDTH,
            ADDR_WIDTH => ADDR_WIDTH
        )
        port map(
            clk            => Clk,
            rst            => rst,
            ce             => '1',
            data_in_valid  => Enable_LA,
            data_in        => DATAOUT,

            data_out_ready => DATAINREADY_LA,
            data_out_valid => DATAINVALID_LA,
            data_out       => DATAIN_LA,

            sample_en      => '1',
            probe          => DataIn_LogicAnalyser

        );
    --DATAINVALID_LA <= '0';
    --LEDs <= Statedebug;

    IO : component IOViewTop
        port map(
            clk            => Clk,
            rst            => rst,
            ce             => '1',

            data_in_valid  => Enable_IOVIEW,
            data_in        => DATAOUT,

            data_out_ready => DATAINREADY_IOVIEW,
            data_out_valid => DATAINVALID_IOVIEW,
            data_out       => DATAIN_IOVIEW,

            probe_inputs   => Input_DeviceunderTest_IOVIEW,
            probe_outputs  => IoViewOutputs
        );
    Output_DeviceunderTest_IOVIEW <= IoViewOutputs;
    --LEDs <= Output_DeviceunderTest_IOVIEW;


    JH : component JtagHub
        generic map(
            MFF_LENGTH => MFF_LENGTH
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

    rstgen:block
        component clk_wiz_0
        port
            (-- Clock in ports
            -- Clock out ports
            clk_out1          : out    std_logic;
            -- Status and control signals
            locked            : out    std_logic;
            clk_in1           : in     std_logic
        );
        end component;
        signal rst_n : std_logic;
    begin
        instance_name : clk_wiz_0
            port map (
                -- Clock out ports
                clk_out1 => open,
                -- Status and control signals
                locked => rst_n,
                -- Clock in ports
                clk_in1 => clk
            );
        rst <= not rst_n;
    end block;




end architecture structure;
