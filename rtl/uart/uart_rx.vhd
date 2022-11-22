library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity uart_rx is
    generic(
        CLOCKS_PER_ONE_SIXTEENTH_BIT : positive := 54;
        NUM_META_FLOPS               : positive := 3;
        PARITY                       : natural range 0 to 2; -- 0: none; 1: odd; 2: even
        --STOP_BITS                    : natural range 1 to 3; -- 1, 1.5, 2
        ASYNC_RESET                  : boolean := true;
        HW_HS                        : boolean
    );
    port(
        clk        : in  std_logic;
        rst        : in  std_logic;
        ce         : in  std_logic;

        rxd        : in  std_logic;
        rts        : out std_logic;

        data       : out std_logic_vector;
        data_valid : out std_logic;
        data_ready : in  std_logic;
        data_err   : out std_logic
    );
end entity uart_rx;

architecture behavioral of uart_rx is
    signal arst, srst     : std_logic;
    constant DATA_WIDTH   : natural := data'length;
    constant OVERSAMPLING : natural := 16;

    signal sample_en      : std_logic;

    signal rxd_sync       : std_logic;
    signal rxd_major      : std_logic;

begin
    async_init: if ASYNC_RESET generate begin
        arst <= rst;
        srst <= '0';
    end generate async_init;
    sync_init: if not ASYNC_RESET generate begin
        arst <= '0';
        srst <= rst;
    end generate sync_init;

    synchronizer: block
        component dffpc is
            port(
                clk : in  std_logic;
                ce  : in  std_logic;
                d   : in  std_logic;
                q   : out std_logic
            );
        end component dffpc;
        signal sync: std_logic_vector(NUM_META_FLOPS downto 0);
    begin
        sync(0) <= rxd;
        gen_mffs: for I in 1 to NUM_META_FLOPS generate begin
            ff_i: component dffpc
                port map(
                    clk => clk,
                    ce  => ce,
                    d   => sync(I - 1),
                    q   => sync(I)
                );
        end generate;
        rxd_sync <= sync(NUM_META_FLOPS);
    end block;

    clk_divider: block
        constant div_cntr_width : natural := integer(ceil(log2(real(CLOCKS_PER_ONE_SIXTEENTH_BIT))));
        signal div_counter      : unsigned(div_cntr_width - 1 downto 0);
    begin
        process(clk)begin
            if rising_edge(clk) then
                if ce = '1' then
                    sample_en <= '0';
                    if to_01(div_counter) = CLOCKS_PER_ONE_SIXTEENTH_BIT - 1 then
                        div_counter <= (others => '0');
                        sample_en <= '1';
                    else
                        div_counter <= to_01(div_counter) + 1;
                    end if;
                end if;
            end if;
        end process;
    end block;

    majority_counter: block
        signal cnt : unsigned(integer(ceil(log2(real(OVERSAMPLING + 1)))) downto 0);
        signal sr  : std_logic_vector(OVERSAMPLING - 1 downto 0);
    begin
        process(clk) begin
            if rising_edge(clk) then
                if ce = '1' then
                    if sample_en = '1' then
                        if to_01(cnt) >= OVERSAMPLING / 2 then
                            rxd_major <= '1';
                        else
                            rxd_major <= '0';
                        end if;

                        sr <= sr(sr'left - 1 downto 0) & rxd_sync;
                        if rxd_sync = '1' and sr(sr'left) = '0' and to_01(cnt) < 16 then
                            cnt <= to_01(cnt) + 1;
                        elsif rxd_sync = '0' and sr(sr'left) = '1' and to_01(cnt) > 0 then
                            cnt <= to_01(cnt) - 1;
                        end if;
                    end if;
                end if;
            end if;
        end process;
    end block;


    receiver: block
        type states_t            is (idle, rx_start, rx_data, rx_parity, rx_stop);
        signal state             : states_t;
        constant smpl_cntr_width : natural := integer(ceil(log2(real(OVERSAMPLING))));
        signal smpl_counter      : unsigned(smpl_cntr_width - 1 downto 0);
        constant bit_cntr_width  : natural := integer(ceil(log2(real(DATA_WIDTH))));
        signal bit_counter       : unsigned(bit_cntr_width - 1 downto 0);
        signal smpl              : std_logic;
        signal rx_reg            : std_logic_vector(DATA_WIDTH - 1 downto 0);
        signal parity_sum        : std_logic;
    begin
        process(arst, clk)
            procedure reset_assignments is begin
                state <= idle;
                bit_counter <= (others => '-');
                smpl_counter <= (others => '-');
                smpl <= '-';
                data_err <= '-';
                rx_reg <= (others => '-');
                data <= (others => '-');
                data_valid <= '0';
                rts <= '1';
            end procedure reset_assignments;
        begin
            if arst = '1' then
                reset_assignments;
            elsif rising_edge(clk) then
                if srst = '1' then
                    reset_assignments;
                else
                    if ce = '1' then
                        data_valid <= '0';
                        if sample_en = '1' then
                            smpl <= '0';
                            if smpl_counter = OVERSAMPLING - 1 then
                                smpl_counter <=  (others => '0');
                                smpl <= '1';
                            else
                                smpl_counter <= smpl_counter + 1;
                            end if;
                            case state is
                            when idle =>
                                rts <= '0';
                                bit_counter <= (others => '0');
                                smpl_counter <= to_unsigned(1, smpl_counter'length);
                                -- detect falling edge
                                if rxd_sync = '0' then
                                    state <= rx_start;
                                end if;
                                if PARITY = 1 then -- odd
                                    parity_sum <= '1';
                                else
                                    parity_sum <= '0';
                                end if;
                            when rx_start =>
                                if smpl = '1' then
                                    if rxd_major = '0' then
                                        state <= rx_data;
                                    else
                                        state <= idle; -- just a glitch detected
                                    end if;
                                end if;
                            when rx_data =>
                                if smpl = '1' then
                                    if bit_counter = DATA_WIDTH - 1 then
                                        if PARITY > 0 then
                                            state <= rx_parity;
                                        else
                                            state <= rx_stop;
                                        end if;
                                    end if;
                                    bit_counter <= bit_counter + 1;
                                    rx_reg <= rxd_major & rx_reg(rx_reg'left downto 1);

                                    parity_sum <= parity_sum xor rxd_major;
                                end if;
                            when rx_parity =>
                                if smpl = '1' then
                                    parity_sum <= parity_sum xor rxd_major;
                                    state <= rx_stop;
                                end if;
                            when rx_stop =>
                                -- no need to wait for all the stop bits
                                state <= idle;
                                data <= rx_reg;
                                data_valid <= '1';
                                if PARITY = 0 then
                                    data_err <= '0';
                                else
                                    data_err <= parity_sum;
                                end if;
                            end case;
                        end if;
                    end if;
                end if;
            end if;
        end process;
    end block;

end behavioral;
