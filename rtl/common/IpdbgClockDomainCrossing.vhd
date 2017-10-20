library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity IpdbgClockDomainCrossing is
    generic(
        ASYNC_RESET: boolean := true;
        MFF_LENGTH : natural := 3
    );
    port(
        clk       : in  std_logic;
        clk_jtag  : in  std_logic;
        rst       : in  std_logic;
        rst_jtag  : in  std_logic;
        ce        : in  std_logic;
        ce_jtag   : in  std_logic;

        data_dwn_valid_jtag : in  std_logic;
        data_dwn_jtag       : in  std_logic_vector(7 downto 0);
        data_dwn_ready_jtag : out std_logic;

        data_dwn_valid      : out std_logic;
        data_dwn            : out std_logic_vector(7 downto 0);

        data_up_ready_jtag  : in  std_logic;
        data_up_valid_jtag  : out std_logic;
        data_up_jtag        : out std_logic_vector(7 downto 0);

        data_up_ready       : out std_logic;
        data_up_valid       : in  std_logic;
        data_up             : in  std_logic_vector(7 downto 0)

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
        arst_host <= rst_jtag;
        srst_host <= '0';
    end generate async_init_host;
    sync_init_host: if not ASYNC_RESET generate begin
        arst_host <= '0';
        srst_host <= rst_jtag;
    end generate sync_init_host;

    async_init_func: if ASYNC_RESET generate begin
        arst_func <= rst;
        srst_func <= '0';
    end generate async_init_func;
    sync_init_func: if not ASYNC_RESET generate begin
        arst_func <= '0';
        srst_func <= rst;
    end generate sync_init_func;

    data_dwn_block : block
        signal data_dwn_register          : std_logic_vector(7 downto 0);
        signal data_out_register_enable   : std_logic;
        signal data_dwn_ready_jtag_n      : std_logic;
    begin

        data_dwn_ready_jtag <= not data_dwn_ready_jtag_n;

        jtag_clockdomain: block
            signal data_out_register_enable_jtag : std_logic := '0';
        begin
            process (clk_jtag, arst_host)
                procedure assign_reset is begin
                    data_dwn_ready_jtag_n <= '0';
                end procedure assign_reset;
            begin
                if arst_host = '1' then
                    assign_reset;
                elsif rising_edge(clk_jtag)then
                    if ce_jtag = '1' then
                        if data_dwn_valid_jtag = '1' then
                            data_dwn_ready_jtag_n <= '1';
                            data_dwn_register <= data_dwn_jtag;
                        end if;
                        if data_out_register_enable_jtag = '1' then
                            data_dwn_ready_jtag_n <= '0';
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
                            clk => clk_jtag,
                            ce  => ce_jtag,
                            d   => ff(K),
                            q   => ff(K+1)
                        );
                end generate;
                data_out_register_enable_jtag <= ff(MFF_LENGTH);
            end block;
        end block;
------------------------------------------------------------------------------------------------------------
        clk_clockDomain : block
            signal update_synced                : std_logic;
            signal update_synced_prev           : std_logic;
        begin
            process (clk) begin
                if rising_edge(clk) then
                    if ce = '1' then
                        data_dwn_valid <= '0';
                        update_synced_prev <= update_synced;
                        if update_synced = '1' and update_synced_prev = '0' then -- detect 0 -> 1 change
                            data_out_register_enable <= '1';
                            data_dwn_valid <= '1';
                            data_dwn <= data_dwn_register;
                        elsif update_synced = '0' and update_synced_prev = '1' then -- detect 1 -> 0 change
                            data_out_register_enable <= '0';
                        end if;
                    end if;
                end if;
            end process;

            ff_clk: block
                signal ff   : std_logic_vector(MFF_LENGTH downto 0);
            begin

                ff(0) <= data_dwn_ready_jtag_n;

                mff_flops: for K in 0 to MFF_LENGTH-1 generate begin

                    MFF : dffpc
                        port map(
                            clk => clk,
                            ce  => ce,
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
        signal jtag_ready         : std_logic;

    begin
        clk_clockdomain : block
            signal ready_set            : std_logic;
            signal set_pending          : std_logic;
            signal data_send_jtag       : std_logic;
            signal ff                   : std_logic_vector(MFF_LENGTH downto 0);
            signal ff_e                 : std_logic_vector(MFF_LENGTH downto 0);
            signal data_up_ready_jtag_s : std_logic;
            signal probe                : std_logic;
            signal data_send_jtag_prev  : std_logic;


        begin
            process (clk, arst_func)
                procedure assign_reset is begin
                    set_pending <= '0';
                    pending <= '0';
                    data_up_ready <= '1';
                    ready_set <= '0';
                end procedure assign_reset;
            begin
                if arst_func = '1' then
                    assign_reset;
                elsif rising_edge(clk) then
                    set_pending <= '0';
                    if data_up_ready_jtag_s = '1' then
                        if ready_set = '1' then
                            data_up_ready <= '1';
                            ready_set <= '0';
                        end if;
                        if data_up_valid =  '1' then
                            transfer_register <= data_up;
                            data_up_ready <= '0';
                            pending <= '1';
                        end if;
                    else
                        data_up_ready <= '0';
                        ready_set <= '1';
                    end if;

                    data_send_jtag_prev <= data_send_jtag;
                    if data_send_jtag = '1' then
                        pending <= '0';
                    elsif data_send_jtag = '0' and data_send_jtag_prev = '1' then
                        ready_set <= '1';
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
                            clk => clk,
                            ce  => ce,
                            d   => ff(K),
                            q   => ff(K+1)
                        );
                end generate;
                data_send_jtag <= ff(MFF_LENGTH);

            end block;
            ff_clk2: block
                signal ff       : std_logic_vector(MFF_LENGTH downto 0);
            begin

                ff(0) <= jtag_ready;

                mff_flops: for K in 0 to MFF_LENGTH-1 generate begin

                    MFF : dffpc
                        port map(
                            clk => clk,
                            ce  => ce,
                            d   => ff(K),
                            q   => ff(K+1)
                        );
                end generate;
                data_up_ready_jtag_s <= ff(MFF_LENGTH);

            end block;

        end block;

----------------------------------------------------------------------------
        clkjtag_block: block
            signal pending_jtag       : std_logic;
            signal pending_jtag_prev  : std_logic;


        begin
            process(clk_jtag) begin
                if rising_edge(clk_jtag) then
                    data_up_valid_jtag <= '0';
                    pending_jtag_prev <= pending_jtag;
                    if pending_jtag = '1' and pending_jtag_prev = '0' then
                        data_up_valid_jtag <= '1';
                        data_up_jtag <= transfer_register;
                        data_transmitted <= '1';
                    elsif pending_jtag = '0' and pending_jtag_prev = '1' then
                        data_transmitted <= '0';
                    end if;
                    if data_up_ready_jtag = '1' then
                        jtag_ready <= '1';
                    else
                        jtag_ready <= '0';
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
                            clk => clk_jtag,
                            ce  => ce_jtag,
                            d   => ff(K),
                            q   => ff(K+1)
                        );
                end generate;
                pending_jtag <= ff(MFF_LENGTH);

            end block;
        end block;
    end block;
end architecture behavioral;
