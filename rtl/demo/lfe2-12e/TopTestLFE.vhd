
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
            MFF_LENGTH : natural
        );
        port(
            clk                   : in  std_logic;
            ce                    : in  std_logic;
            data_dwn              : out std_logic_vector(7 downto 0);
            data_dwn_valid_la     : out std_logic;
            data_dwn_valid_ioview : out std_logic;
            data_dwn_valid_gdb    : out std_logic;
            data_up_ready_la      : out std_logic;
            data_up_ready_ioview  : out std_logic;
            data_up_ready_gdb     : out std_logic;
            data_up_valid_la      : in  std_logic;
            data_up_valid_ioview  : in  std_logic;
            data_up_valid_gdb     : in  std_logic;
            data_up_la            : in  std_logic_vector(7 downto 0);
            data_up_ioview        : in  std_logic_vector(7 downto 0);
            data_up_gdb           : in  std_logic_vector(7 downto 0)
        );
    end component JtagHub;
    component IoViewTop is
        port(
            clk            : in  std_logic;
            rst            : in  std_logic;
            ce             : in  std_logic;
            data_dwn_valid : in  std_logic;
            data_dwn       : in  std_logic_vector(7 downto 0);
            data_up_ready  : in  std_logic;
            data_up_valid  : out std_logic;
            data_up        : out std_logic_vector(7 downto 0);
            probe_inputs   : in  std_logic_vector;
            probe_outputs  : out std_logic_vector
        );
    end component IoViewTop;


	component pll0
		port (CLK: in std_logic; CLKOP: out std_logic; LOCK: out std_logic);
	end component;

    signal data_dwn              : std_logic_vector(7 downto 0);
    signal data_dwn_valid_ioview : std_logic;
    signal data_up_ready_ioview  : std_logic;
    signal data_up_valid_ioview  : std_logic;
    signal data_up_ioview        : std_logic_vector(7 downto 0);

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


    jh : component JtagHub
        generic map(
            MFF_LENGTH => MFF_LENGTH
        )
        port map(
            clk                   => clk,
            ce                    => '1',
            data_dwn              => data_dwn,
            data_dwn_valid_la     => open,
            data_dwn_valid_ioview => data_dwn_valid_ioview,
            data_dwn_valid_gdb    => open,
            data_up_ready_la      => open,
            data_up_ready_ioview  => data_up_ready_ioview,
            data_up_ready_gdb     => open,
            data_up_valid_la      => '0',
            data_up_valid_ioview  => data_up_valid_ioview,
            data_up_valid_gdb     => '0',
            data_up_la            => (others => '-'),
            data_up_ioview        => data_up_ioview,
            data_up_gdb           => (others => '-')
        );

    iov : component IoViewTop
        port map(
            clk            => clk,
            rst            => rst,
            ce             => '1',
            data_dwn_valid => data_dwn_valid_ioview,
            data_dwn       => data_dwn,
            data_up_ready  => data_up_ready_ioview,
            data_up_valid  => data_up_valid_ioview,
            data_up        => data_up_ioview,
            probe_inputs   => INPUT_DeviceUnderTest_Ioview,
            probe_outputs  => OUTPUT_DeviceUnderTest_Ioview_s
        );



    OUTPUT_DeviceUnderTest_Ioview <= OUTPUT_DeviceUnderTest_Ioview_s;
end;
