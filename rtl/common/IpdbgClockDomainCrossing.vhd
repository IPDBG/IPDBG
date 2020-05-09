library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity IpdbgClockDomainCrossing is
    generic(
        ASYNC_RESET: boolean := false;
        MFF_LENGTH : natural := 3
    );
    port(
        clk_func            : in  std_logic;
        rst_func            : in  std_logic;
        ce_func             : in  std_logic;
        clk_host            : in  std_logic;
        rst_host            : in  std_logic;
        ce_host             : in  std_logic;

        data_dwn_valid_host : in  std_logic;
        data_dwn_host       : in  std_logic_vector(7 downto 0);
        data_dwn_ready_host : out std_logic;

        data_dwn_valid_func : out std_logic;
        data_dwn_ready_func : in  std_logic;
        data_dwn_func       : out std_logic_vector(7 downto 0);

        data_up_ready_host  : in  std_logic;
        data_up_valid_host  : out std_logic;
        data_up_host        : out std_logic_vector(7 downto 0);

        data_up_ready_func  : out std_logic;
        data_up_valid_func  : in  std_logic;
        data_up_func        : in  std_logic_vector(7 downto 0)

    );
end entity IpdbgClockDomainCrossing;

architecture behavioral of IpdbgClockDomainCrossing is

    component dffpc is
        port(
            clk : in  std_logic;
            ce  : in  std_logic;
            d   : in  std_logic;
            q   : out std_logic
        );
    end component dffpc;

     signal arst_host, srst_host        : std_logic;
     signal arst_func, srst_func        : std_logic;

begin
    async_init_host: if ASYNC_RESET generate begin
        arst_host <= rst_host;
        srst_host <= '0';
    end generate async_init_host;
    sync_init_host: if not ASYNC_RESET generate begin
        arst_host <= '0';
        srst_host <= rst_host;
    end generate sync_init_host;

    async_init_func: if ASYNC_RESET generate begin
        arst_func <= rst_func;
        srst_func <= '0';
    end generate async_init_func;
    sync_init_func: if not ASYNC_RESET generate begin
        arst_func <= '0';
        srst_func <= rst_func;
    end generate sync_init_func;

    data_dwn_block : block
        signal transfer_register : std_logic_vector(7 downto 0);
        signal request           : std_logic;
        signal acknowledge       : std_logic;
    begin
        host_clock_domain : block
            signal acknowledge_synced      : std_logic;
            signal acknowledge_synced_prev : std_logic;
        begin
            process (clk_host, arst_host)
                procedure assign_reset is begin
                    request <= '0';
					data_dwn_ready_host <= '1';
                    acknowledge_synced_prev <= '0';
                    transfer_register <= (others => '-');
                end procedure assign_reset;
            begin
                if arst_host = '1' then
                    assign_reset;
                elsif rising_edge(clk_host)then
                    if srst_host = '1' then
                        assign_reset;
                    else
                        if ce_host = '1' then
                            acknowledge_synced_prev <= acknowledge_synced;
                            if data_dwn_valid_host = '1' then
                                request <= '1';
                                transfer_register <= data_dwn_host;
								data_dwn_ready_host <= '0';
                            else
                                if acknowledge_synced = '1' and acknowledge_synced_prev = '0' then
                                    request <= '0';
                                end if;
                                if acknowledge_synced = '0' and acknowledge_synced_prev = '1' then
                                    data_dwn_ready_host <= '1';
                                end if;
                            end if;
                        end if;
                    end if;
                end if;
            end process;

            ff_jtag: block
                signal ff : std_logic_vector(MFF_LENGTH downto 0);
            begin
                ff(0) <= acknowledge;
                mff_flops: for K in 0 to MFF_LENGTH-1 generate begin
                    MFF : dffpc
                        port map(
                            clk => clk_host,
                            ce  => ce_host,
                            d   => ff(K),
                            q   => ff(K+1)
                        );
                end generate;
                acknowledge_synced <= ff(MFF_LENGTH);
            end block;
        end block;

        function_clock_domain : block
            signal request_synced      : std_logic;
            signal request_synced_prev : std_logic;
            signal pending             : std_logic;
        begin
            process (clk_func, arst_func)
				procedure assign_reset is begin
                    acknowledge <= '0';
                    data_dwn_valid_func <= '0';
                    data_dwn_func <= (others => '-');
                    request_synced_prev <= '0';
                    pending <= '0';
                end procedure assign_reset;
			begin
                if arst_func = '1' then
					assign_reset;
                elsif rising_edge(clk_func) then
                    if srst_func = '1' then
                        assign_reset;
                    else
                        if ce_func = '1' then
                            data_dwn_valid_func <= '0';
                            request_synced_prev <= request_synced;
                            if pending = '1' then
                                if data_dwn_ready_func = '1' then
                                    acknowledge <= '1';
                                    data_dwn_valid_func <= '1';
                                    pending <= '0';
                                end if;
                            else
                                if request_synced = '1' and request_synced_prev = '0' then -- detect 0 -> 1 change
                                    data_dwn_func <= transfer_register;
                                    if data_dwn_ready_func = '1' then
                                        acknowledge <= '1';
                                        data_dwn_valid_func <= '1';
                                    else
                                        pending <= '1';
                                    end if;
                                elsif request_synced = '0' and request_synced_prev = '1' then -- detect 1 -> 0 change
                                    acknowledge <= '0';
                                end if;
                            end if;
                        end if;
                    end if;
                end if;
            end process;

            ff_clk: block
                signal ff   : std_logic_vector(MFF_LENGTH downto 0);
            begin
                ff(0) <= request;
                mff_flops: for K in 0 to MFF_LENGTH-1 generate begin
                    MFF : dffpc
                        port map(
                            clk => clk_func,
                            ce  => ce_func,
                            d   => ff(K),
                            q   => ff(K+1)
                        );
                end generate;
                request_synced <= ff(MFF_LENGTH);
            end block;
        end block;
    end block;

    data_up_block: block
        signal transfer_register : std_logic_vector(7 downto 0);
        signal request           : std_logic;
        signal acknowledge       : std_logic;
    begin
        function_clock_domain : block
            signal acknowledge_synced      : std_logic;
            signal acknowledge_synced_prev : std_logic;
        begin
            process (clk_func, arst_func)
                procedure assign_reset is begin
                    request <= '0';
                    data_up_ready_func <= '1';
                    acknowledge_synced_prev <= '0';
                    transfer_register <= (others => '-');
                end procedure assign_reset;
            begin
                if arst_func = '1' then
                    assign_reset;
                elsif rising_edge(clk_func) then
                    if srst_func = '1' then
                        assign_reset;
                    else
                        if ce_func = '1' then
                            acknowledge_synced_prev <= acknowledge_synced;
                            if data_up_valid_func = '1' then
                                request <= '1';
                                transfer_register <= data_up_func;
                                data_up_ready_func <= '0';
                            else
                                if acknowledge_synced = '1' and acknowledge_synced_prev = '0'then
                                    request <= '0';
                                end if;
                                if acknowledge_synced = '0' and acknowledge_synced_prev = '1'then
                                    data_up_ready_func <= '1';
                                end if;
                            end if;
                        end if;
                    end if;
                end if;
            end process;

            ff_clk1: block
                signal ff   : std_logic_vector(MFF_LENGTH downto 0);
            begin
                ff(0) <= acknowledge;
                mff_flops: for K in 0 to MFF_LENGTH-1 generate begin
                    MFF : dffpc
                        port map(
                            clk => clk_func,
                            ce  => ce_func,
                            d   => ff(K),
                            q   => ff(K+1)
                        );
                end generate;
                acknowledge_synced <= ff(MFF_LENGTH);
            end block;
        end block;

        host_clock_domain: block
            signal request_synced      : std_logic;
            signal request_synced_prev : std_logic;
            signal pending             : std_logic;
        begin
            process(clk_host, arst_host)
                procedure assign_reset is begin
                    acknowledge <= '0';
                    data_up_valid_host <= '0';
                    data_up_host <= (others => '-');
                    request_synced_prev <= '0';
                    pending <= '0';
                end procedure assign_reset;
            begin
                if arst_host= '1' then
                    assign_reset;
                elsif rising_edge(clk_host) then
                    if srst_host = '1' then
                         assign_reset;
                    else
                        if ce_host = '1' then
                            data_up_valid_host <= '0';
                            request_synced_prev <= request_synced;
                            if pending = '1' then
                                if data_up_ready_host = '1' then
                                    acknowledge <= '1';
                                    data_up_valid_host <= '1';
                                    pending <= '0';
                                end if;
                            else
                                if request_synced = '1' and request_synced_prev = '0' then -- detect 0 -> 1 change
                                    data_up_host <= transfer_register;
                                    if data_up_ready_host = '1' then
                                        acknowledge <= '1';
                                        data_up_valid_host <= '1';
                                    else
                                        pending <= '1';
                                    end if;
                                elsif request_synced = '0' and request_synced_prev = '1' then -- detect 1 -> 0 change
                                    acknowledge <= '0';
                                end if;
                            end if;
                        end if;
                    end if;
                end if;
            end process;

           ff_clkjtag: block
                signal ff   : std_logic_vector(MFF_LENGTH downto 0);
            begin
                ff(0) <= request;
                mff_flops: for K in 0 to MFF_LENGTH-1 generate begin
                    MFF : dffpc
                        port map(
                            clk => clk_host,
                            ce  => ce_host,
                            d   => ff(K),
                            q   => ff(K+1)
                        );
                end generate;
                request_synced <= ff(MFF_LENGTH);
            end block;
        end block;
    end block;
end architecture behavioral;
