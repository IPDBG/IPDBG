library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity tb_top is

end entity tb_top;

architecture structure of tb_top is

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

    component WaveformGeneratorTop is
        generic(
            ADDR_WIDTH : natural;
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
            data_out       : out std_logic_vector;
            first_sample   : out std_logic;
            sample_enable  : in  std_logic;
            output_active  : out std_logic
        );
    end component WaveformGeneratorTop;

    component JtagHub is
        generic(
            MFF_LENGTH : natural
        );
        port(
            clk                  : in  std_logic;
            ce                   : in  std_logic;
            data_dwn             : out std_logic_vector(7 downto 0);
            data_dwn_valid_la    : out std_logic;
            data_dwn_valid_ioview: out std_logic;
            data_dwn_valid_gdb   : out std_logic;
            data_dwn_valid_wfg   : out std_logic;
            data_up_ready_la     : out std_logic;
            data_up_ready_ioview : out std_logic;
            data_up_ready_gdb    : out std_logic;
            data_up_ready_wfg    : out std_logic;
            data_up_valid_la     : in  std_logic;
            data_up_valid_ioview : in  std_logic;
            data_up_valid_gdb    : in  std_logic;
            data_up_valid_wfg    : in  std_logic;
            data_up_la           : in  std_logic_vector(7 downto 0);
            data_up_ioview       : in  std_logic_vector(7 downto 0);
            data_up_gdb          : in  std_logic_vector(7 downto 0);
            data_up_wfg          : in  std_logic_vector(7 downto 0)
        );
    end component JtagHub;


    component IoViewTop is
        generic(
            ASYNC_RESET : boolean := true
        );
        port(
            clk                  : in  std_logic;
            rst                  : in  std_logic;
            ce                   : in  std_logic;
            data_dwn_valid       : in  std_logic;
            data_dwn             : in  std_logic_vector(7 downto 0);
            data_up_ready        : in  std_logic;
            data_up_valid        : out std_logic;
            data_up              : out std_logic_vector(7 downto 0);
            probe_inputs         : in  std_logic_vector;
            probe_outputs        : out std_logic_vector;
            probe_outputs_update : out std_logic
        );
    end component IoViewTop;

    signal clk, rst, ce  : std_logic;


    constant DATA_WIDTH       : natural := 12;
    constant ADDR_WIDTH       : natural := 9;
    constant ASYNC_RESET      : boolean := true;

    signal data_dwn           : std_logic_vector(7 downto 0);
    signal data_dwn_valid_la  : std_logic;
    signal data_up_ready_la   : std_logic;
    signal data_up_valid_la   : std_logic;
    signal data_up_la         : std_logic_vector(7 downto 0);
    signal data_dwn_valid_wfg : std_logic;
    signal data_up_ready_wfg  : std_logic;
    signal data_up_valid_wfg  : std_logic;
    signal data_up_wfg        : std_logic_vector(7 downto 0);
    signal data_dwn_valid_iov : std_logic;
    signal data_up_ready_iov  : std_logic;
    signal data_up_valid_iov  : std_logic;
    signal data_up_iov        : std_logic_vector(7 downto 0);

    constant T                : time := 10 ns;

    signal count              : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal count_max          : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '1');

    signal first_sample       : std_logic;
    signal data_out_wfg       : std_logic_vector(31 downto 0);
    signal data_in_la         : std_logic_vector(17 downto 0);

    signal sample_enable      : std_logic;
    signal output_active      : std_logic;

begin
    process begin
        clk <= '0';
        wait for T/2;
        clk <= '1';
        wait for (T-(T/2));-- to avoid rounding differences
    end process;
    process begin
        rst <= '1';
        wait for 3/2*T;
        rst <= '0';
        wait;
    end process;

    ce <= '1';
--    process(clk, rst)begin
--        if rst = '1' then
--            count <= (others => '0');
--        elsif rising_edge(clk) then
--            if count = count_max then
--                count <= (others => '0');
--            else
--                count <= std_logic_vector(unsigned(count) + 1);
--            end if;
--        end if;
--    end process;


    jh: component JtagHub
        generic map(
            MFF_LENGTH => 3
        )
        port map(
            clk                   => clk,
            ce                    => ce,
            data_dwn              => data_dwn,
            data_dwn_valid_la     => data_dwn_valid_la,
            data_dwn_valid_ioview => data_dwn_valid_iov,
            data_dwn_valid_gdb    => open,
            data_dwn_valid_wfg    => data_dwn_valid_wfg,
            data_up_ready_la      => data_up_ready_la,
            data_up_ready_ioview  => data_up_ready_iov,
            data_up_ready_gdb     => open,
            data_up_ready_wfg     => data_up_ready_wfg,
            data_up_valid_la      => data_up_valid_la,
            data_up_valid_ioview  => data_up_valid_iov,
            data_up_valid_gdb     => '0',
            data_up_valid_wfg     => data_up_valid_wfg,
            data_up_la            => data_up_la,
            data_up_ioview        => data_up_iov,
            data_up_gdb           => (others => '-'),
            data_up_wfg           => data_up_wfg
        );

    la: component LogicAnalyserTop
        generic map(
            ADDR_WIDTH  => ADDR_WIDTH,
            ASYNC_RESET => ASYNC_RESET
        )
        port map(
            clk            => clk,
            rst            => rst,
            ce             => ce,
            data_dwn_valid => data_dwn_valid_la,
            data_dwn       => data_dwn,
            data_up_ready  => data_up_ready_la,
            data_up_valid  => data_up_valid_la,
            data_up        => data_up_la,
            sample_enable  => sample_enable,
            probe          => data_in_la
        );
    sample_enable <= not data_out_wfg(18);
    data_in_la <= data_out_wfg(17 downto 0);
    wfg: component WaveformGeneratorTop
        generic map(
            ADDR_WIDTH  => 9,
            ASYNC_RESET => ASYNC_RESET
        )
        port map(
            clk            => clk,
            rst            => rst,
            ce             => ce,
            data_dwn_valid => data_dwn_valid_wfg,
            data_dwn       => data_dwn,
            data_up_ready  => data_up_ready_wfg,
            data_up_valid  => data_up_valid_wfg,
            data_up        => data_up_wfg,
            data_out       => data_out_wfg,
            first_sample   => first_sample,
            sample_enable  => '1',
            output_active  => output_active
        );
    test_iov: block
        signal probe_inputs_iov   : std_logic_vector(17 downto 0);
        signal probe_outputs_iov  : std_logic_vector(8 downto 0);
    begin
        iov: component IoViewTop
            generic map(
                ASYNC_RESET => ASYNC_RESET
            )
            port map(
                clk                  => clk,
                rst                  => rst,
                ce                   => ce,
                data_dwn_valid       => data_dwn_valid_iov,
                data_dwn             => data_dwn,
                data_up_ready        => data_up_ready_iov,
                data_up_valid        => data_up_valid_iov,
                data_up              => data_up_iov,
                probe_inputs         => probe_inputs_iov,
                probe_outputs        => probe_outputs_iov,
                probe_outputs_update => open
            );
        probe_inputs_iov <= probe_outputs_iov & probe_outputs_iov;
    end block test_iov;
end architecture structure;

