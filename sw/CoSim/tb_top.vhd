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
            ADDR_WIDTH             : natural;
            ASYNC_RESET            : boolean;
            USE_EXT_TRIGGER        : boolean;
            RUN_LENGTH_COMPRESSION : natural range 0 to 32
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
            output_active : out std_logic;
            one_shot      : in  std_logic;
            sync_out      : out std_logic;
            sync_in       : in  std_logic
        );
    end component WaveformGeneratorTop;

    component JtagHub is
        generic(
            MFF_LENGTH          : natural := 3;
            FLOW_CONTROL_ENABLE : std_logic_vector(6 downto 0)
        );
        port(
            TCK        : in  std_logic;
            TMS        : in  std_logic;
            TDI        : in  std_logic;
            TDO        : out std_logic;

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

    component WbMaster is
        generic (
            ASYNC_RESET : boolean
        );
        port (
            clk      : in    std_logic;
            rst      : in    std_logic;
            ce       : in    std_logic;

            --      host interface (UART or ....)
            dn_lines : in    ipdbg_dn_lines;
            up_lines : out   ipdbg_up_lines;

            -- wishbone interface
            -- stall_i  : in    std_logic;
            lock_o   : out   std_logic;
            cyc_o    : out   std_logic;
            stb_o    : out   std_logic;
            ack_i    : in    std_logic;
            rty_i    : in    std_logic := '0';
            err_i    : in    std_logic := '0';
            we_o     : out   std_logic;
            adr_o    : out   std_logic_vector;
            sel_o    : out   std_logic_vector;
            dat_o    : out   std_logic_vector;
            dat_i    : in    std_logic_vector
        );
    end component WbMaster;

    component JtagAdapter is
        port(
            TMS  : out std_logic;
            TCK  : out std_logic;
            TDI  : out std_logic;
            TDO  : in  std_logic;
            TRST : out std_logic;
            SRST : out std_logic
        );
    end component JtagAdapter;

    signal TMS            : std_logic;
    signal TCK            : std_logic;
    signal TDI            : std_logic;
    signal TDO            : std_logic;

    signal clk, rst, ce   : std_logic;

    constant DATA_WIDTH   : natural := 12;
    constant ASYNC_RESET  : boolean := true;

    signal dn_lines_la    : ipdbg_dn_lines;
    signal up_lines_la    : ipdbg_up_lines;
    signal dn_lines_wfg   : ipdbg_dn_lines;
    signal up_lines_wfg   : ipdbg_up_lines;
    signal dn_lines_iov   : ipdbg_dn_lines;
    signal up_lines_iov   : ipdbg_up_lines;
    signal dn_lines_bm    : ipdbg_dn_lines;
    signal up_lines_bm    : ipdbg_up_lines;

    constant T            : time := 10 ns;

    signal first_sample   : std_logic;
    signal data_out_wfg   : std_logic_vector(15 downto 0);
    signal data_in_la     : std_logic_vector(17 downto 0);

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

    adapter: component JtagAdapter
        port map(
            TMS  => TMS,
            TCK  => TCK,
            TDI  => TDI,
            TDO  => TDO,
            TRST => open,
            SRST => open
        );

    jh: component JtagHub
        generic map(
            MFF_LENGTH => 3,
            FLOW_CONTROL_ENABLE => "1000000"
        )
        port map(
            TMS        => TMS,
            TCK        => TCK,
            TDI        => TDI,
            TDO        => TDO,
            clk        => clk,
            ce         => ce,
            dn_lines_0 => dn_lines_la,
            dn_lines_1 => dn_lines_wfg,
            dn_lines_2 => dn_lines_iov,
            dn_lines_3 => dn_lines_bm,
            dn_lines_4 => open,
            dn_lines_5 => open,
            dn_lines_6 => open,
            up_lines_0 => up_lines_la,
            up_lines_1 => up_lines_wfg,
            up_lines_2 => up_lines_iov,
            up_lines_3 => up_lines_bm
        );

    la: component LogicAnalyserTop
        generic map(
            ADDR_WIDTH             => 5,
            ASYNC_RESET            => ASYNC_RESET,
            USE_EXT_TRIGGER        => false,
            RUN_LENGTH_COMPRESSION => 0
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
--    process(clk)begin
--        if rising_Edge(clk)then
--            if sample_enable = '1' then
--                ext_trigger <= '0';
--                if data_in_la = x"7f" then
                    ext_trigger <= '1';
--                end if;
--            end if;
--        end if;
--    end process;

    process
        variable counter : integer range 0 to 3;
    begin
        --sample_enable <= '0';
        data_in_la <= (others => '0');
        wait until rst = '0';
        wait until rising_edge(clk);
        wait for T/5;
        counter := 0;

        while true loop
            --sample_enable <= '0';
            --wait for T;
            --sample_enable <= '1';
            if counter = 3 then
                data_in_la <= std_logic_vector(unsigned(data_in_la) + 1);
                counter := 0;
            else
                counter := counter + 1;
            end if;
            wait for T;
        end loop;

        wait;
    end process;

    sample_enable <= '1';
    --data_in_la <= data_out_wfg when output_active = '1' else x"0000";

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
            output_active => output_active,
            one_shot      => '0',
            sync_out      => open,
            sync_in       => '0'
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

    ba: block
        signal reg    : std_logic_vector(31 downto 0) := (others => '0');
        signal wr_dat : std_logic_vector(31 downto 0);
        signal rd_dat : std_logic_vector(31 downto 0);
        signal cyc    : std_logic;
        signal stb    : std_logic;
        signal ack    : std_logic;
        signal we     : std_logic;
        signal adr    : std_logic_vector(15 downto 0);
        signal sel    : std_logic_vector(1 downto 0);
        signal lock   : std_logic;
    begin

        bus_access: component WbMaster
            generic map (
                ASYNC_RESET => ASYNC_RESET
            )
            port map (
                clk      => clk,
                rst      => rst,
                ce       => ce,
                dn_lines => dn_lines_bm,
                up_lines => up_lines_bm,
                lock_o   => lock,
                cyc_o    => cyc,
                stb_o    => stb,
                ack_i    => ack,
                we_o     => we,
                adr_o    => adr,
                sel_o    => sel,
                dat_o    => wr_dat,
                dat_i    => rd_dat
            );

        rd_dat <= reg;
        ack <= stb;

        process(clk)
        begin
            if rising_edge(clk) then
                if ce = '1' then
                    if stb = '1' and cyc = '1' then
                        if we = '1' then
                            if sel(0) = '1' then
                                reg( 7 downto 0) <= wr_dat( 7 downto 0);
                                report "write to address " & integer'image(to_integer(unsigned(adr))) & " value: " &
                                integer'image(to_integer(unsigned(wr_dat)));
                            end if;
                            if sel(1) = '1' then
                                reg(15 downto 8) <= wr_dat(15 downto 8);
                            end if;
                        end if;
                    end if;
                end if;
            end if;
        end process;

    end block;

end architecture structure;

