
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity TopTestLFE is
    generic(
        MFF_LENGTH : natural             := 3;
        DATA_WIDTH : natural             := 8;        --! width of a sample
        ADDR_WIDTH : natural             := 8
    );
    port(
        RefClk                           : in  std_logic; -- 10MHz

        Input_DeviceunderTest_IOVIEW     : in  std_logic_vector(7 downto 0);
        Output_DeviceunderTest_IOVIEW    : out std_logic_vector(7 downto 0);

        Leds                             : out std_logic_vector(7 downto 0);
        debug                            : out std_logic_vector(3 downto 0)
    );
end TopTestLFE;

architecture structure of TopTestLFE is

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

    component IoViewTop is
        port(
            clk           : in  std_logic;
			rst           : in  std_logic;
			ce            : in  std_logic;

			-- host interface (JtagHub or UART or ....)
			data_in_valid  : in  std_logic;
			data_in        : in  std_logic_vector(7 downto 0);

			data_out_ready : in  std_logic;
			data_out_valid : out std_logic;
			data_out       : out std_logic_vector(7 downto 0);

			--- input & Ouput--------
			probe_inputs   : in  std_logic_vector;
			probe_outputs  : out std_logic_vector
        );
    end component IoViewTop;

	component pll0
		port (CLK: in std_logic; CLKOP: out std_logic; LOCK: out std_logic);
	end component;


    signal DataOut                       : std_logic_vector(7 downto 0);
    signal Enable_IOVIEW                 : std_logic;
    signal DATAINREADY_IOVIEW            : std_logic;
    signal DATAINVALID_IOVIEW            : std_logic;
    signal DATAIN_IOVIEW                 : std_logic_vector(7 downto 0);

    signal clk                           : std_logic;
	signal rst, rst_n                    : std_logic;
    --signal LEDS_s                        : std_logic_vector(7 downto 0) := "00000001";
    -- signal x                            :  unsigned(15 downto 0) := (others => '0');
    signal debug_s                        : std_logic_vector(debug'range);
    signal OUTPUT_DeviceUnderTest_Ioview_s : std_logic_vector(7 downto 0);
begin

    --clk <= RefClk;
--    Leds <= LEDS_s;
--
	debug <= debug_s;

	ourPll : pll0
    port map (CLK=>RefClk, CLKOP=>clk, LOCK=>rst_n);

	rst <= not rst_n;


--    process (clk, rst) begin
--	    if rst = '1' then
			debug_s <= (others => '0');
--        elsif rising_edge(clk) then
--            debug_s <= std_logic_vector(unsigned(debug_s)+1);
--        end if;
--    end process;


    leds <= OUTPUT_DeviceUnderTest_Ioview_s;



    jtag : component JtagHub
        generic map(
            MFF_LENGTH        => MFF_LENGTH,
            TARGET_TECHNOLOGY => 2 -- Lattice LFE2
        )
        port map(
            clk                => clk,
            ce                 => '1',
            DATAOUT            => DATAOUT,
            Enable_LA          => open,
            Enable_IOVIEW      => Enable_IOVIEW,
            Enable_GDB         => open,
            DATAINREADY_LA     => open,
            DATAINREADY_IOVIEW => DATAINREADY_IOVIEW,
            DATAINREADY_GDB    => open,
            DATAINVALID_LA     => '0',
            DATAINVALID_IOVIEW => DATAINVALID_IOVIEW,
            DATAINVALID_GDB    => '0',
            DATAIN_LA          => (others => '0'),
            DATAIN_IOVIEW      => DATAIN_IOVIEW,
            DATAIN_GDB         => (others => '0')
        );
    IoView : component IoViewTop
        port map(
            clk            => clk,
            rst            => rst,
            ce             => '1',
            data_in_valid  => Enable_IOVIEW,
            data_in        => DATAOUT,
            data_out_ready => DATAINREADY_IOVIEW,
            data_out_valid => DATAINVALID_IOVIEW,
            data_out       => DATAIN_IOVIEW,
            probe_inputs   => INPUT_DeviceUnderTest_Ioview,
            probe_outputs  => OUTPUT_DeviceUnderTest_Ioview_s
        );
    OUTPUT_DeviceUnderTest_Ioview <= OUTPUT_DeviceUnderTest_Ioview_s;
end;
