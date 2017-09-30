
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity TopTestLFE is
    generic(
        MFF_LENGTH  : natural := 3;
        ASYNC_RESET : boolean := true
    );
    port(
        RefClk                           : in  std_logic; -- 10MHz

        leds                             : out std_logic_vector(6 downto 0);

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
            data_dwn_valid_wfg    : out std_logic;
            data_up_ready_la      : out std_logic;
            data_up_ready_ioview  : out std_logic;
            data_up_ready_gdb     : out std_logic;
            data_up_ready_wfg     : out std_logic;
            data_up_valid_la      : in  std_logic;
            data_up_valid_ioview  : in  std_logic;
            data_up_valid_gdb     : in  std_logic;
            data_up_valid_wfg     : in  std_logic;
            data_up_la            : in  std_logic_vector(7 downto 0);
            data_up_ioview        : in  std_logic_vector(7 downto 0);
            data_up_gdb           : in  std_logic_vector(7 downto 0);
            data_up_wfg           : in  std_logic_vector(7 downto 0)
        );
    end component JtagHub;
    component IoViewTop is
        generic(
            ASYNC_RESET    : boolean
        );
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
    component LogicAnalyserTop is
        generic(
            ADDR_WIDTH  : natural;
            ASYNC_RESET : boolean
        );
        port(
            clk            : in  std_logic;
            rst            : in  std_logic;
            ce             : in  std_logic;
            data_dwn_valid : in  std_logic;
            data_dwn       : in  std_logic_vector(7 downto 0);
            data_up_ready  : in  std_logic;
            data_up_valid  : out std_logic;
            data_up        : out std_logic_vector(7 downto 0);
            sample_enable  : in  std_logic;
            probe          : in  std_logic_vector
        );
    end component LogicAnalyserTop;

	component pll0
		port (CLK: in std_logic; CLKOP: out std_logic; LOCK: out std_logic);
	end component;

    signal data_dwn                      : std_logic_vector(7 downto 0);
    signal data_dwn_valid_ioview         : std_logic;
    signal data_up_ready_ioview          : std_logic;
    signal data_up_valid_ioview          : std_logic;
    signal data_up_ioview                : std_logic_vector(7 downto 0);
    signal data_dwn_valid_la             : std_logic;
    signal data_up_ready_la              : std_logic;
    signal data_up_valid_la              : std_logic;
    signal data_up_la                    : std_logic_vector(7 downto 0);
    signal probe_la                      : std_logic_vector(11 downto 0);

    signal clk                           : std_logic;
	signal rst, rst_n                    : std_logic;
    signal OUTPUT_DeviceUnderTest_Ioview : std_logic_vector(7 downto 0);

    signal ce_div                        : unsigned(31 downto 0);
    constant ce_div_max                  : unsigned(31 downto 0) := (others => '1');
    signal ce                            : std_logic;
    signal count                         : std_logic_vector(11 downto 0);
begin

	debug <= (others => '0');

	ourPll : pll0
    port map (CLK=>RefClk, CLKOP=>clk, LOCK=>rst_n);

	rst <= not rst_n;

    leds <= OUTPUT_DeviceUnderTest_Ioview(leds'range);

    process(clk, rst)begin
        if rst = '1' then
            ce_div <= (others => '0');
            ce <= '0';
            count <= (others => '-');
        elsif rising_edge(clk) then
            ce <= '0';
            if ce_div = ce_div_max then
                ce_div <= (others => '0');
                ce <= '1';
            else
                ce_div <= ce_div+1;
            end if;
            if ce = '1' then
                count <= std_logic_vector(unsigned(count) +1);
            end if;
        end if;
    end process;
    probe_la <= std_logic_vector(ce_div(probe_la'range));



    jh : component JtagHub
        generic map(
            MFF_LENGTH => MFF_LENGTH
        )
        port map(
            clk                   => clk,
            ce                    => '1',
            data_dwn              => data_dwn,
            data_dwn_valid_la     => data_dwn_valid_la,
            data_dwn_valid_ioview => data_dwn_valid_ioview,
            data_dwn_valid_gdb    => open,
            data_dwn_valid_wfg    => open,
            data_up_ready_la      => data_up_ready_la,
            data_up_ready_ioview  => data_up_ready_ioview,
            data_up_ready_gdb     => open,
            data_up_ready_wfg     => open,
            data_up_valid_la      => data_up_valid_la,
            data_up_valid_ioview  => data_up_valid_ioview,
            data_up_valid_gdb     => '0',
            data_up_valid_wfg     => '0',
            data_up_la            => data_up_la,
            data_up_ioview        => data_up_ioview,
            data_up_gdb           => (others => '0'),
            data_up_wfg           => (others => '0')
        );

    iov : component IoViewTop
        generic map(
            ASYNC_RESET => ASYNC_RESET
        )
        port map(
            clk            => clk,
            rst            => rst,
            ce             => '1',
            data_dwn_valid => data_dwn_valid_ioview,
            data_dwn       => data_dwn,
            data_up_ready  => data_up_ready_ioview,
            data_up_valid  => data_up_valid_ioview,
            data_up        => data_up_ioview,
            probe_inputs   => count,
            probe_outputs  => OUTPUT_DeviceUnderTest_Ioview
        );
    la : component LogicAnalyserTop
        generic map(
            ADDR_WIDTH  => 9,
            ASYNC_RESET => ASYNC_RESET
        )
        port map(
            clk            => clk,
            rst            => rst,
            ce             => '1',
            data_dwn_valid => data_dwn_valid_la,
            data_dwn       => data_dwn,
            data_up_ready  => data_up_ready_la,
            data_up_valid  => data_up_valid_la,
            data_up        => data_up_la,
            sample_enable  => '1',
            probe          => probe_la
        );

end;
