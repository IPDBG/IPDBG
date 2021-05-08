library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ipdbg_interface_pkg.all;

entity tb_top is

end entity tb_top;

architecture structure of tb_top is

    component LogicAnalyserTop is
        generic(
            ADDR_WIDTH      : natural;
            ASYNC_RESET     : boolean;
            USE_EXT_TRIGGER : boolean
        );
        port(
            clk           : in  std_logic;
            rst           : in  std_logic;
            ce            : in  std_logic;
            dn_lines      : in  ipdbg_dn_lines;
            up_lines      : out ipdbg_up_lines;
            sample_enable : in  std_logic;
            probe         : in  std_logic_vector;
            ext_trigger   : in  std_logic
        );
    end component LogicAnalyserTop;

    component WaveformGeneratorTop is
        generic(
            ADDR_WIDTH    : natural;
            ASYNC_RESET   : boolean;
            DOUBLE_BUFFER : boolean
        );
        port(
            clk           : in  std_logic;
            rst           : in  std_logic;
            ce            : in  std_logic;
            dn_lines      : in  ipdbg_dn_lines;
            up_lines      : out ipdbg_up_lines;
            data_out      : out std_logic_vector;
            first_sample  : out std_logic;
            sample_enable : in  std_logic;
            output_active : out std_logic
        );
    end component WaveformGeneratorTop;

    component JtagHub is
        generic(
            MFF_LENGTH : natural
        );
        port(
            clk        : in  std_logic;
            ce         : in  std_logic;
            dn_lines_0 : out ipdbg_dn_lines;
            dn_lines_1 : out ipdbg_dn_lines;
            dn_lines_2 : out ipdbg_dn_lines;
            dn_lines_3 : out ipdbg_dn_lines;
            dn_lines_4 : out ipdbg_dn_lines;
            dn_lines_5 : out ipdbg_dn_lines;
            dn_lines_6 : out ipdbg_dn_lines;
            up_lines_0 : in  ipdbg_up_lines := unused_up_lines;
            up_lines_1 : in  ipdbg_up_lines := unused_up_lines;
            up_lines_2 : in  ipdbg_up_lines := unused_up_lines;
            up_lines_3 : in  ipdbg_up_lines := unused_up_lines;
            up_lines_4 : in  ipdbg_up_lines := unused_up_lines;
            up_lines_5 : in  ipdbg_up_lines := unused_up_lines;
            up_lines_6 : in  ipdbg_up_lines := unused_up_lines
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
            dn_lines             : in  ipdbg_dn_lines;
            up_lines             : out ipdbg_up_lines;
            probe_inputs         : in  std_logic_vector;
            probe_outputs        : out std_logic_vector;
            probe_outputs_update : out std_logic
        );
    end component IoViewTop;

    signal clk, rst, ce   : std_logic;

    constant DATA_WIDTH   : natural := 12;
    constant ASYNC_RESET  : boolean := true;

    signal dn_lines_la    : ipdbg_dn_lines;
    signal up_lines_la    : ipdbg_up_lines;
    signal dn_lines_wfg   : ipdbg_dn_lines;
    signal up_lines_wfg   : ipdbg_up_lines;
    signal dn_lines_iov   : ipdbg_dn_lines;
    signal up_lines_iov   : ipdbg_up_lines;

    constant T            : time := 10 ns;

    signal first_sample   : std_logic;
    signal data_out_wfg   : std_logic_vector(15 downto 0);
    signal data_in_la     : std_logic_vector(15 downto 0);

    signal sample_enable  : std_logic;
    signal output_active  : std_logic;

    signal ext_trigger    : std_logic;
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
            clk        => clk,
            ce         => ce,
            dn_lines_0 => dn_lines_la,
            dn_lines_1 => dn_lines_wfg,
            dn_lines_2 => dn_lines_iov,
            dn_lines_3 => open,
            dn_lines_4 => open,
            dn_lines_5 => open,
            dn_lines_6 => open,
            up_lines_0 => up_lines_la,
            up_lines_1 => up_lines_wfg,
            up_lines_2 => up_lines_iov
        );

    la: component LogicAnalyserTop
        generic map(
            ADDR_WIDTH      => 10,
            ASYNC_RESET     => ASYNC_RESET,
            USE_EXT_TRIGGER => false
        )
        port map(
            clk           => clk,
            rst           => rst,
            ce            => ce,
            dn_lines      => dn_lines_la,
            up_lines      => up_lines_la,
            sample_enable => sample_enable,
            probe         => data_in_la,
            ext_trigger   => ext_trigger
        );
    process(clk)begin
        if rising_Edge(clk)then
            if sample_enable = '1' then
                ext_trigger <= '0';
                if data_in_la = x"7f" then
                    ext_trigger <= '1';
                end if;
            end if;
        end if;
    end process;

--    process begin
--        --sample_enable <= '0';
--        data_in_la <= x"0000";
--        wait until rst = '0';
--        wait until rising_edge(clk);
--        wait for T/5;
--
--        while true loop
--            --sample_enable <= '0';
--            --wait for T;
--            --sample_enable <= '1';
--            data_in_la <= std_logic_vector(unsigned(data_in_la)+1);
--            wait for T;
--        end loop;
--
--        wait;
--    end process;

    sample_enable <= '1';
    data_in_la <= data_out_wfg when output_active = '1' else x"0000";

    wfg: component WaveformGeneratorTop
        generic map(
            ADDR_WIDTH    => 9,
            ASYNC_RESET   => ASYNC_RESET,
            DOUBLE_BUFFER => false
        )
        port map(
            clk           => clk,
            rst           => rst,
            ce            => ce,
            dn_lines      => dn_lines_wfg,
            up_lines      => up_lines_wfg,
            data_out      => data_out_wfg,
            first_sample  => first_sample,
            sample_enable => '1',
            output_active => output_active
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
                dn_lines             => dn_lines_iov,
                up_lines             => up_lines_iov,
                probe_inputs         => probe_inputs_iov,
                probe_outputs        => probe_outputs_iov,
                probe_outputs_update => open
            );
        probe_inputs_iov <= probe_outputs_iov & probe_outputs_iov;
    end block test_iov;
end architecture structure;

