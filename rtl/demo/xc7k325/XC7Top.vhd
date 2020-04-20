library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity XC7Top is
    generic(
        MFF_LENGTH : natural := 3;
        DATA_WIDTH : natural := 6;        --! width of a sample
        ADDR_WIDTH : natural := 6
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
            clk                   : in  std_logic;
            ce                    : in  std_logic;
            data_dwn              : out std_logic_vector(7 downto 0);
            data_dwn_ready_la     : in  std_logic;
            data_dwn_ready_ioview : in  std_logic;
            data_dwn_ready_gdb    : in  std_logic;
            data_dwn_ready_wfg    : in  std_logic;
            data_dwn_valid_la     : out std_logic;
            data_dwn_valid_ioview : out std_logic;
            data_dwn_valid_wfg    : out std_logic;
            data_dwn_valid_gdb    : out std_logic;
            data_up_ready_la      : out std_logic;
            data_up_ready_ioview  : out std_logic;
            data_up_ready_wfg     : out std_logic;
            data_up_ready_gdb     : out std_logic;
            data_up_valid_la      : in  std_logic;
            data_up_valid_ioview  : in  std_logic;
            data_up_valid_wfg     : in  std_logic;
            data_up_valid_gdb     : in  std_logic;
            data_up_la            : in  std_logic_vector (7 downto 0);
            data_up_ioview        : in  std_logic_vector (7 downto 0);
            data_up_wfg           : in  std_logic_vector (7 downto 0);
            data_up_gdb           : in  std_logic_vector (7 downto 0)
        );
    end component JtagHub;


    component LogicAnalyserTop is
        generic(
            ADDR_WIDTH  : natural;
            ASYNC_RESET : boolean
        );
        port(
            clk            : in  std_logic;
            rst            : in  std_logic;
            ce             : in  std_logic;
            data_dwn_ready : out std_logic;
            data_dwn_valid : in  std_logic;
            data_dwn       : in  std_logic_vector(7 downto 0);
            data_up_ready  : in  std_logic;
            data_up_valid  : out std_logic;
            data_up        : out std_logic_vector(7 downto 0);
            sample_enable  : in  std_logic;
            probe          : in  std_logic_vector(DATA_WIDTH-1 downto 0)
        );
    end component LogicAnalyserTop;

    component IOViewTop is
        generic(
            ASYNC_RESET : boolean
        );
        port(
            clk            : in  std_logic;
            rst            : in  std_logic;
            ce             : in  std_logic;
            data_dwn_ready : out std_logic;
            data_dwn_valid : in  std_logic;
            data_dwn       : in  std_logic_vector(7 downto 0);
            data_up_ready  : in  std_logic;
            data_up_valid  : out std_logic;
            data_up        : out std_logic_vector(7 downto 0);
            probe_inputs   : in  std_logic_vector;
            probe_outputs  : out std_logic_vector

        );
    end component IOViewTop;

    component WaveformGeneratorTop is
        generic(
            ADDR_WIDTH  : natural;
            ASYNC_RESET : boolean
        );
        port(
            clk            : in  std_logic;
            rst            : in  std_logic;
            ce             : in  std_logic;
            data_dwn_ready : out std_logic;
            data_dwn_valid : in  std_logic;
            data_dwn       : in  std_logic_vector(7 downto 0);
            data_up_ready  : in  std_logic;
            data_up_valid  : out std_logic;
            data_up        : out std_logic_vector(7 downto 0);
            data_out       : out std_logic_vector(DATA_WIDTH-1 downto 0);
            first_sample   : out std_logic;
            sample_enable  : in  std_logic

        );
    end component WaveformGeneratorTop;

    constant ASYNC_RESET : boolean := false;

    signal Clk                : std_logic;
    signal rst                : std_logic := '1';

    signal Input_DeviceunderTest_IOVIEW : std_logic_vector(7 downto 0);
    signal DataIn_LogicAnalyser         : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal DataIn_LogicAnalyser_gdb     : std_logic_vector(DATA_WIDTH-1 downto 0);
    constant DataIn_LogicAnalyser_max   : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '1');

    signal sample_enable_wfg            : std_logic := '1';
    signal data_dwn                     : std_logic_vector(7 downto 0);

    signal data_dwn_ready_la            : std_logic;
    signal data_dwn_ready_ioview        : std_logic;
    signal data_dwn_ready_gdb           : std_logic;
    signal data_dwn_ready_wfg           : std_logic;

    signal data_dwn_valid_la            : std_logic;
    signal data_dwn_valid_ioview        : std_logic;
    signal data_dwn_valid_gdb           : std_logic;
    signal data_dwn_valid_wfg           : std_logic;

    signal data_up_ready_la             : std_logic;
    signal data_up_ready_ioview         : std_logic;
    signal data_up_ready_gdb            : std_logic;
    signal data_up_ready_wfg            : std_logic;

    signal data_up_valid_la             : std_logic;
    signal data_up_valid_ioview         : std_logic;
    signal data_up_valid_gdb            : std_logic;
    signal data_up_valid_wfg            : std_logic;

    signal data_up_la                   : std_logic_vector (7 downto 0);
    signal data_up_ioview               : std_logic_vector (7 downto 0);
    signal data_up_gdb                  : std_logic_vector (7 downto 0);
    signal data_up_wfg                  : std_logic_vector (7 downto 0);

    signal count                        : std_logic_vector (28 downto 0);
    signal output                       : std_logic_vector (7 downto 0);
    signal temp                         : std_logic_vector (7 downto 0);

    signal IoViewOutputs                : std_logic_vector(3 downto 0);

    --signal Output_DeviceunderTest_IOVIEW    : std_logic_vector(7 downto 0);
    --signal stateDebug          : std_logic_vector(7 downto 0);
begin

    Counter : process (Clk) begin
        if rising_edge(Clk) then
            if DataIn_LogicAnalyser_gdb = DataIn_LogicAnalyser_max then
                DataIn_LogicAnalyser_gdb <= (others => '0');
            else
                DataIn_LogicAnalyser_gdb <= std_logic_vector(unsigned(DataIn_LogicAnalyser_gdb)+1);
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
            ADDR_WIDTH  => ADDR_WIDTH,
            ASYNC_RESET => ASYNC_RESET
        )
        port map(
            clk            => Clk,
            rst            => rst,
            ce             => '1',

            data_dwn_ready => data_dwn_ready_la,
            data_dwn_valid => data_dwn_valid_la,
            data_dwn       => data_dwn,

            data_up_ready  => data_up_ready_la,
            data_up_valid  => data_up_valid_la,
            data_up        => data_up_la,

            sample_enable  => '1',
            probe          => DataIn_LogicAnalyser

        );

        la2 : component LogicAnalyserTop
        generic map(
            ADDR_WIDTH  => ADDR_WIDTH,
            ASYNC_RESET => ASYNC_RESET
        )
        port map(
            clk            => Clk,
            rst            => rst,
            ce             => '1',

            data_dwn_ready => data_dwn_ready_gdb,
            data_dwn_valid => data_dwn_valid_gdb,
            data_dwn       => data_dwn,

            data_up_ready  => data_up_ready_gdb,
            data_up_valid  => data_up_valid_gdb,
            data_up        => data_up_gdb,

            sample_enable  => '1',
            probe          => DataIn_LogicAnalyser_gdb

        );

    --DATAINVALID_LA <= '0';
    --LEDs <= Statedebug;

    IO : component IOViewTop
        generic map(
            ASYNC_RESET => ASYNC_RESET
        )
        port map(
            clk            => Clk,
            rst            => rst,
            ce             => '1',

            data_dwn_ready => data_dwn_ready_ioview,
            data_dwn_valid => data_dwn_valid_ioview,
            data_dwn       => data_dwn,

            data_up_ready  => data_up_ready_ioview,
            data_up_valid  => data_up_valid_ioview,
            data_up        => data_up_ioview,

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
            clk                   => Clk,
            ce                    => '1',
            data_dwn              => data_dwn,
            data_dwn_ready_la     => data_dwn_ready_la,
            data_dwn_ready_ioview => data_dwn_ready_ioview,
            data_dwn_ready_gdb    => data_dwn_ready_gdb,
            data_dwn_ready_wfg    => data_dwn_ready_wfg,

            data_dwn_valid_la     => data_dwn_valid_la,
            data_dwn_valid_ioview => data_dwn_valid_ioview,
            data_dwn_valid_wfg    => data_dwn_valid_wfg,
            data_dwn_valid_gdb    => data_dwn_valid_gdb,

            data_up_ready_la      => data_up_ready_la,
            data_up_ready_ioview  => data_up_ready_ioview,
            data_up_ready_wfg     => data_up_ready_wfg,
            data_up_ready_gdb     => data_up_ready_gdb,

            data_up_valid_la      => data_up_valid_la,
            data_up_valid_ioview  => data_up_valid_ioview,
            data_up_valid_wfg     => data_up_valid_wfg,
            data_up_valid_gdb     => data_up_valid_gdb,

            data_up_la            => data_up_la,
            data_up_ioview        => data_up_ioview,
            data_up_wfg           => data_up_wfg,
            data_up_gdb           => data_up_gdb
        );

    WFG: component WaveformGeneratorTop
        generic map(
            ADDR_WIDTH  => ADDR_WIDTH,
            ASYNC_RESET => ASYNC_RESET
        )
        port map(
            clk            => clk,
            rst            => rst,
            ce             => '1',
            data_dwn_ready => data_dwn_ready_wfg,
            data_dwn_valid => data_dwn_valid_wfg,
            data_dwn       => data_dwn,
            data_up_ready  => data_up_ready_wfg,
            data_up_valid  => data_up_valid_wfg,
            data_up        => data_up_wfg,
            data_out        => DataIn_LogicAnalyser,
            first_sample   => open,
            sample_enable  => sample_enable_wfg
        );
    sample_enable_wfg <= '1';

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
    --DATAIN_GDB <= (others => '-');
    --DATAINVALID_GDB <= '0';


end architecture structure;
