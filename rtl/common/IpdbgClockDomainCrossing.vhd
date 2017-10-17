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
        data_dwn_ready      : out std_logic;

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

begin
    data_dwn_block : block
        signal data_dwn_register          : std_logic_vector(7 downto 0);
        signal update_synced_prev         : std_logic;
        signal ff_s                       : std_logic_vector(MFF_LENGTH downto 0);
        signal data_up_valid_jtag_s       : std_logic;
        signal data_dwn_valid_jtag_s      : std_logic;
        signal data_dwn_valid_jtag_e      : std_logic;
        signal data_trasmitted            : std_logic;
        signal update_synced              : std_logic;
        signal data_out_register_enable_s : std_logic;
    begin

        other_clockdomain: block
        begin
            process (clk_jtag) begin
                if rising_edge(clk_jtag)then
                    if ce_jtag = '1' then
                        if data_dwn_valid_jtag = '1' then
                            data_dwn_valid_jtag_s <= '1';
                            data_dwn_register <= data_dwn_jtag;
                            data_dwn_ready <= '0';
                        end if;
                        if data_out_register_enable_s = '1' then
                            data_dwn_ready <= '1' ;
                        end if;
                    end if;
                end if;
                if ff_s(1) = '1' then
                    data_dwn_valid_jtag_s <= '0';
                end if;
            end process;
        end block;

        outputControl : block
            signal data_out_register_enable : std_logic;
        begin
            process (clk) begin
                if rising_edge(clk) then
                    if ce = '1' then
                        data_out_register_enable <= '0';
                        update_synced_prev       <= update_synced;
                        if update_synced = '1' and update_synced_prev = '0' then -- detect 0 -> 1 change
                            data_out_register_enable <= '1';
                        end if;
                    end if;
                end if;
            end process;

            process (clk) begin
                if rising_edge(clk) then
                    if ce = '1' then
                        data_dwn_valid <= '0';
                        if data_out_register_enable = '1' then
                            data_dwn_valid <= '1';
                        end if;
                    end if;
                end if;
            end process;

            process (clk) begin
                if rising_edge(clk) then
                    if ce = '1' then
                        if data_out_register_enable = '1' then
                            data_dwn <= data_dwn_register;
                        end if;
                    end if;
                end if;
            end process;
            data_out_register_enable_s <= data_out_register_enable;
        end block;

        cdc: block
            component dffpc is
                port(
                    clk : in  std_logic;
                    ce  : in  std_logic;
                    d   : in  std_logic;
                    q   : out std_logic
                );
            end component dffpc;
        begin

            ff_s(0) <= data_dwn_valid_jtag_s;

            mff_flops: for K in 0 to MFF_LENGTH-1 generate begin

                MFF : dffpc
                    port map(
                        clk => clk,
                        ce  => ce,
                        d   => ff_s(K),
                        q   => ff_s(K+1)
                    );
            end generate;
            update_synced <= ff_s(MFF_LENGTH);

        end block;

    end block;



    data_up_block: block
        signal ff_s               : std_logic_vector(MFF_LENGTH downto 0);
        signal pending_jtag       : std_logic;
        signal pending_jtag_prev  : std_logic;
        signal data_send_jtag2    : std_logic;
        signal data_send_jtag     : std_logic;
        signal ready_set          : std_logic;
        signal set_pending        : std_logic;
        signal pending            : std_logic;
        signal data_up_ready_s    : std_logic;
        signal probe              : std_logic;
        signal transfer_register  : std_logic_vector(7 downto 0);


    begin
        data_up_ready <= data_up_ready_s;
        process (clk, rst) begin
            if (rst = '1') then
                set_pending <= '0';
                pending <= '0';
                data_up_ready_s <= '1';
                ready_set <= '0';
                probe <= '0';
            elsif rising_edge(clk) then
                set_pending <= '0';
                if data_up_ready_jtag = '1' then --
                    if ready_set = '1' then
                        data_up_ready_s <= '1';
                        ready_set <= '0';
                        probe <= '1';
                    end if;
                    if data_up_valid =  '1' then
                        transfer_register <= data_up;
                        set_pending <= '1';
                        data_up_ready_s <= '0';
                    end if;
                    if set_pending = '1' then
                        pending <= '1';
                    end if;
                    if ff_s(1) = '1' then
                        pending <= '0';
                    end if;
                    if data_send_jtag2 = '1' then
                        data_up_ready_s <= '1';
                    end if;
                else
                    data_up_ready_s <= '0';
                    ready_set <= '1';
                end if;
            end if;
        end process;
        process(clk_jtag) begin
            if rising_edge(clk_jtag) then
                data_send_jtag <= '0';
                pending_jtag_prev <= pending_jtag;
                if pending_jtag = '1' and  pending_jtag_prev = '0' then
                    data_send_jtag <= '1';
                    data_send_jtag2 <= '1';
                end if;
                if data_up_ready_s = '1' then
                    data_send_jtag2 <= '0';
                end if;

            end if;
        end process;

        process(clk_jtag) begin
            if rising_edge(clk_jtag) then
                data_up_valid_jtag <= '0';
                if data_send_jtag = '1' then
                    data_up_valid_jtag <= '1';
                end if;
            end if;
        end process;

        process(clk_jtag) begin
            if rising_edge(clk_jtag) then
                if data_send_jtag = '1' then
                    data_up_jtag <= transfer_register;
                end if;
            end if;
        end process;

        receive: block
            component dffpc is
                port(
                    clk : in  std_logic;
                    ce  : in  std_logic;
                    d   : in  std_logic;
                    q   : out std_logic
                );
            end component dffpc;
        begin

            ff_s(0) <= pending;

            mff_flops: for K in 0 to MFF_LENGTH-1 generate begin

                MFF : dffpc
                    port map(
                        clk => clk_jtag,
                        ce  => ce_jtag,
                        d   => ff_s(K),
                        q   => ff_s(K+1)
                    );
            end generate;
            pending_jtag <= ff_s(MFF_LENGTH);

        end block;
    end block;
end architecture behavioral;
