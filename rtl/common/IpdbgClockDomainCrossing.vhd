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
----
    data_dwn_block : block
        signal data_dwn_register          : std_logic_vector(7 downto 0);
        signal data_out_register_enable   : std_logic;
        signal data_dwn_ready_host_n      : std_logic;
    begin

        data_dwn_ready_host <= not data_dwn_ready_host_n;

        jtag_clockdomain: block
            signal data_out_register_enable_jtag : std_logic;
        begin
            process (clk_host, arst_host)
                procedure assign_reset is begin
                    data_dwn_ready_host_n <= '0';
                    data_dwn_register <= (others => '-');
                end procedure assign_reset;
            begin
                if arst_host = '1' then
                    assign_reset;
                elsif rising_edge(clk_host)then
                    if srst_host = '1' then
                        assign_reset;
                    else
                        if ce_host = '1' then
                            if data_dwn_valid_host = '1' then
                                data_dwn_ready_host_n <= '1';
                                data_dwn_register <= data_dwn_host;
                            end if;
                            if data_out_register_enable_jtag = '1' then
                                data_dwn_ready_host_n <= '0';
                            end if;
                        end if;
                    end if;
                end if;
            end process;

            ff_jtag: block
                signal ff   : std_logic_vector(MFF_LENGTH downto 0);
            begin

                ff(0) <= data_out_register_enable;

                mff_flops: for K in 0 to MFF_LENGTH-1 generate begin

                    MFF : dffpc
                        port map(
                            clk => clk_host,
                            ce  => ce_host,
                            d   => ff(K),
                            q   => ff(K+1)
                        );
                end generate;
                data_out_register_enable_jtag <= ff(MFF_LENGTH);
            end block;
        end block;
------------------------------------------------------------------------------------------------------------
        clk_clock_domain : block
            signal update_synced      : std_logic;
            signal update_synced_prev : std_logic;
            signal pending            : std_logic;
        begin
            process (clk_func, arst_func) begin
                if arst_func = '1' then
                    data_out_register_enable <= '0';
                    data_dwn_valid_func <= '0';
                    data_dwn_func <= (others => '-');
                    update_synced_prev <= '-';
                    pending <= '0';
                elsif rising_edge(clk_func) then
                    if srst_func = '1' then
                        data_out_register_enable <= '0';
                        data_dwn_valid_func <= '0';
                        data_dwn_func <= (others => '-');
                        update_synced_prev <= '-';
                        pending <= '0';
                    else
                        if ce_func = '1' then
                            data_dwn_valid_func <= '0';
                            update_synced_prev <= update_synced;
                            if pending = '1' then
                                if data_dwn_ready_func = '1' then
                                    data_out_register_enable <= '1';
                                    data_dwn_valid_func <= '1';
                                    pending <= '0';
                                end if;
                            else
                                if update_synced = '1' and update_synced_prev = '0' then -- detect 0 -> 1 change
                                    data_dwn_func <= data_dwn_register;
                                    if data_dwn_ready_func = '1' then
                                        data_out_register_enable <= '1';
                                        data_dwn_valid_func <= '1';
                                    else
                                        pending <= '1';
                                    end if;
                                elsif update_synced = '0' and update_synced_prev = '1' then -- detect 1 -> 0 change
                                    data_out_register_enable <= '0';
                                end if;
                            end if;
                        end if;
                    end if;
                end if;
            end process;

            ff_clk: block
                signal ff   : std_logic_vector(MFF_LENGTH downto 0);
            begin

                ff(0) <= data_dwn_ready_host_n;

                mff_flops: for K in 0 to MFF_LENGTH-1 generate begin

                    MFF : dffpc
                        port map(
                            clk => clk_func,
                            ce  => ce_func,
                            d   => ff(K),
                            q   => ff(K+1)
                        );
                end generate;
                update_synced <= ff(MFF_LENGTH);
            end block;
        end block;
    end block;

----------------------------------------------------------------------------------------

    data_up_block: block
        signal transfer_register  : std_logic_vector(7 downto 0);
        signal pending            : std_logic;
        signal data_transmitted   : std_logic;

    begin
        clk_clockdomain : block
            signal data_send_host       : std_logic;
            signal data_send_host_prev  : std_logic;
        begin
            process (clk_func, arst_func)
                procedure assign_reset is begin
                    pending <= '0';
                    data_up_ready_func <= '1';
                    data_send_host_prev <= '-';
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
                            data_send_host_prev <= data_send_host;
                            if data_up_valid_func =  '1' then
                                transfer_register <= data_up_func;
                                data_up_ready_func <= '0';
                                pending <= '1';
                            end if;
                            if data_send_host = '1' and data_send_host_prev = '0'then
                                pending <= '0';
                            end if;
                            if data_send_host = '0' and data_send_host_prev = '1'then
                                data_up_ready_func <= '1';
                            end if;
                        end if;
                    end if;
                end if;
            end process;
            ff_clk1: block
                signal ff   : std_logic_vector(MFF_LENGTH downto 0);
            begin

                ff(0) <= data_transmitted;

                mff_flops: for K in 0 to MFF_LENGTH-1 generate begin

                    MFF : dffpc
                        port map(
                            clk => clk_func,
                            ce  => ce_func,
                            d   => ff(K),
                            q   => ff(K+1)
                        );
                end generate;
                data_send_host <= ff(MFF_LENGTH);

            end block;
        end block;

----------------------------------------------------------------------------
        clkjtag_block: block
            signal pending_host       : std_logic;
            signal pending_host_prev  : std_logic;
        begin
            process(clk_host, arst_host)
                procedure assign_reset is begin
                    data_transmitted <= '0';
                    data_up_valid_host <= '0';
                    pending_host_prev <= '-';
                    data_up_host <= (others => '-');
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
                            pending_host_prev <= pending_host;
                            if data_up_ready_host = '1' then
                                if pending_host = '1'  then
                                    data_up_valid_host <= '1';
                                    data_up_host <= transfer_register;
                                    data_transmitted <= '1';
                                end if;
                            elsif pending_host = '0' then
                                data_transmitted <= '0';
                            end if;
                        end if;
                    end if;
                end if;
            end process;

           ff_clkjtag: block
                signal ff   : std_logic_vector(MFF_LENGTH downto 0);
            begin
                ff(0) <= pending;
                mff_flops: for K in 0 to MFF_LENGTH-1 generate begin

                    MFF : dffpc
                        port map(
                            clk => clk_host,
                            ce  => ce_host,
                            d   => ff(K),
                            q   => ff(K+1)
                        );
                end generate;
                pending_host <= ff(MFF_LENGTH);

            end block;
        end block;
    end block;
end architecture behavioral;
