
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
            MFF_LENGTH       : natural;
            HANDSHAKE_ENABLE : std_logic_vector(6 downto 0)
        );
        port(
            clk                   : in  std_logic;
            ce                    : in  std_logic;
            data_dwn_ready        : in  std_logic_vector(6 downto 0);
            data_dwn_valid        : out std_logic_vector(6 downto 0);
            data_dwn_0            : out std_logic_vector(7 downto 0);
            data_dwn_1            : out std_logic_vector(7 downto 0);
            data_dwn_2            : out std_logic_vector(7 downto 0);
            data_dwn_3            : out std_logic_vector(7 downto 0);
            data_dwn_4            : out std_logic_vector(7 downto 0);
            data_dwn_5            : out std_logic_vector(7 downto 0);
            data_dwn_6            : out std_logic_vector(7 downto 0);
            data_up_ready         : out std_logic_vector(6 downto 0);
            data_up_valid         : in  std_logic_vector(6 downto 0);
            data_up_0             : in  std_logic_vector(7 downto 0);
            data_up_1             : in  std_logic_vector(7 downto 0);
            data_up_2             : in  std_logic_vector(7 downto 0);
            data_up_3             : in  std_logic_vector(7 downto 0);
            data_up_4             : in  std_logic_vector(7 downto 0);
            data_up_5             : in  std_logic_vector(7 downto 0);
            data_up_6             : in  std_logic_vector(7 downto 0)
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
            data_dwn_ready : out std_logic;
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
            data_dwn_ready : out std_logic;
            data_dwn_valid : in  std_logic;
            data_dwn       : in  std_logic_vector(7 downto 0);
            data_up_ready  : in  std_logic;
            data_up_valid  : out std_logic;
            data_up        : out std_logic_vector(7 downto 0);
            sample_enable  : in  std_logic;
            probe          : in  std_logic_vector
        );
    end component LogicAnalyserTop;
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
            data_out       : out std_logic_vector;
            first_sample   : out std_logic;
            sample_enable  : in  std_logic
        );
    end component WaveformGeneratorTop;

	component pll0
		port (CLK: in std_logic; CLKOP: out std_logic; LOCK: out std_logic);
	end component;

    signal data_dwn_la                   : std_logic_vector(7 downto 0);
    signal data_dwn_ioview               : std_logic_vector(7 downto 0);
    signal data_dwn_wfg                  : std_logic_vector(7 downto 0);

    signal data_dwn_ready                : std_logic_vector(6 downto 0);
    signal data_dwn_valid                : std_logic_vector(6 downto 0);
    signal data_up_ready                 : std_logic_vector(6 downto 0);
    signal data_up_valid                 : std_logic_vector(6 downto 0);
    signal data_dwn_ready_ioview         : std_logic;
    signal data_dwn_valid_ioview         : std_logic;
    signal data_up_ready_ioview          : std_logic;
    signal data_up_valid_ioview          : std_logic;
    signal data_up_ioview                : std_logic_vector(7 downto 0);
    signal data_dwn_ready_la             : std_logic;
    signal data_dwn_valid_la             : std_logic;
    signal data_up_ready_la              : std_logic;
    signal data_up_valid_la              : std_logic;
    signal data_up_la                    : std_logic_vector(7 downto 0);
    signal probe_la                      : std_logic_vector(8 downto 0);
    signal data_dwn_ready_wfg            : std_logic;
    signal data_dwn_valid_wfg            : std_logic;
    signal data_up_ready_wfg             : std_logic;
    signal data_up_valid_wfg             : std_logic;
    signal data_up_wfg                   : std_logic_vector(7 downto 0);
    signal data_out                      : std_logic_vector(7 downto 0);
    signal first_sample                  : std_logic;

    signal clk                           : std_logic;
	signal rst, rst_n                    : std_logic;
    signal OUTPUT_DeviceUnderTest_Ioview : std_logic_vector(7 downto 0);

    signal ce_div                        : unsigned(31 downto 0);
    constant ce_div_max                  : unsigned(31 downto 0) := (others => '1');
    signal ce                            : std_logic;
    signal count                         : std_logic_vector(11 downto 0);
begin

    data_dwn_ready <= "00" & data_dwn_ready_la & data_dwn_ready_wfg & data_dwn_ready_ioview & "00";
    data_up_valid  <= "00" & data_up_valid_la  & data_up_valid_wfg  & data_up_valid_ioview  & "00";
    data_dwn_valid_la     <= data_dwn_valid(4);
    data_dwn_valid_wfg    <= data_dwn_valid(3);
    data_dwn_valid_ioview <= data_dwn_valid(2);
    data_up_ready_la     <= data_up_ready(4);
    data_up_ready_wfg    <= data_up_ready(3);
    data_up_ready_ioview <= data_up_ready(2);

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
    probe_la <= first_sample & data_out;


    JH : component JtagHub
        generic map(
            MFF_LENGTH => MFF_LENGTH,
            HANDSHAKE_ENABLE => "0000010"
        )
        port map(
            clk                   => Clk,
            ce                    => '1',
            data_dwn_ready        => data_dwn_ready,
            data_dwn_valid        => data_dwn_valid,

            data_up_ready         => data_up_ready,
            data_up_valid         => data_up_valid,
            data_up_0             => x"00",
            data_up_1             => x"00",
            data_up_2             => data_up_ioview,
            data_up_3             => data_up_wfg,
            data_up_4             => data_up_la,
            data_up_5             => x"00",
            data_up_6             => x"00",

            data_dwn_0            => open,
            data_dwn_1            => open,
            data_dwn_2            => data_dwn_ioview,
            data_dwn_3            => data_dwn_wfg,
            data_dwn_4            => data_dwn_la,
            data_dwn_5            => open,
            data_dwn_6            => open
        );

    iov : component IoViewTop
        generic map(
            ASYNC_RESET => ASYNC_RESET
        )
        port map(
            clk            => clk,
            rst            => rst,
            ce             => '1',
            data_dwn_ready => data_dwn_ready_ioview,
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
            data_dwn_ready => data_dwn_ready_la,
            data_dwn_valid => data_dwn_valid_la,
            data_dwn       => data_dwn,
            data_up_ready  => data_up_ready_la,
            data_up_valid  => data_up_valid_la,
            data_up        => data_up_la,
            sample_enable  => '1',
            probe          => probe_la
        );
    wfg : component WaveformGeneratorTop
        generic map(
            ADDR_WIDTH  => 4,
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
            data_out       => data_out,
            first_sample   => first_sample,
            sample_enable  => '1'
        );

end;
