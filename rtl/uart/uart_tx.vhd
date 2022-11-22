library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity uart_tx is
    generic(
        CLOCKS_PER_ONE_SIXTEENTH_BIT : positive := 54;
        NUM_META_FLOPS               : positive := 3;
        PARITY                       : natural range 0 to 2; -- 0: none; 1: odd; 2: even
        STOP_BITS                    : natural range 1 to 3; -- 1, 1.5, 2
        ASYNC_RESET                  : boolean := true;
        HW_HS                        : boolean
    );
    port(
        clk        : in  std_logic;
        rst        : in  std_logic;
        ce         : in  std_logic;

        txd        : out std_logic;
        cts        : in  std_logic := '0';

        data       : in  std_logic_vector;
        data_valid : in  std_logic;
        data_ready : out std_logic
    );
end entity uart_tx;

architecture behavioral of uart_tx is
    signal arst, srst   : std_logic;
    constant DATA_WIDTH : natural := data'length;

    pure function tx_reg_length return natural is
        variable res : natural := DATA_WIDTH;
    begin
        --if PARITY > 0
        --    res := res + 1;
        --end if;
        return res;
    end function;

    signal cts_sync         : std_logic;

    signal tx_reg           : std_logic_vector(tx_reg_length - 1 downto 0);
    constant div_cntr_width : natural := integer(ceil(log2(real(CLOCKS_PER_ONE_SIXTEENTH_BIT*16))));
    signal div_counter      : unsigned(div_cntr_width - 1 downto 0);
    signal counter          : unsigned(2 downto 0);
    type states_t           is (idle, tx_start, tx_data, tx_parity, tx_stop);
    signal state            : states_t;
    signal start_enabler    : std_logic;
    signal enable           : std_logic_vector(1 downto 0);
    signal parity_sum       : std_logic;
begin
    async_init: if ASYNC_RESET generate begin
        arst <= rst;
        srst <= '0';
    end generate async_init;
    sync_init: if not ASYNC_RESET generate begin
        arst <= '0';
        srst <= rst;
    end generate sync_init;

    synchronizer: if HW_HS generate
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
        sync(0) <= cts;
        gen_mffs: for I in 1 to NUM_META_FLOPS generate begin
            ff_i: component dffpc
                port map(
                    clk => clk,
                    ce  => ce,
                    d   => sync(I - 1),
                    q   => sync(I)
                );
        end generate;
        cts_sync <= sync(NUM_META_FLOPS);
    end generate;
    ho_hs: if not HW_HS generate begin
        cts_sync <= '0';
    end generate;

    divider: block
    begin
        process(clk) begin
            if rising_edge(clk) then
                if ce = '1' then
                    if start_enabler = '1' then
                        div_counter <= to_unsigned(2, div_counter'length);
                    elsif to_01(div_counter) = CLOCKS_PER_ONE_SIXTEENTH_BIT * 16 - 1 then
                        div_counter <= (others => '0');
                    else
                        div_counter <= to_01(div_counter) + 1;
                    end if;
                    enable <= "00";
                    if to_01(div_counter) = CLOCKS_PER_ONE_SIXTEENTH_BIT * 16 - 1 then
                        enable <= "11";
                    elsif to_01(div_counter) = CLOCKS_PER_ONE_SIXTEENTH_BIT * 8 - 1 then
                        enable <= "01";
                    end if;
                end if;
            end if;
        end process;
    end block;

    process(arst, clk)
        procedure reset_assignments is begin
            state <= idle;
            data_ready <= '0';
            tx_reg <= (others => '-');
            counter <= (others => '-');
            parity_sum <= '-';
            start_enabler <= '-';
            txd <= '1';
        end procedure reset_assignments;
    begin
        if arst = '1' then
            reset_assignments;
        elsif rising_edge(clk) then
            if srst = '1' then
                reset_assignments;
            else
                if ce = '1' then
                    start_enabler <= '0';
                    case state is
                    when idle =>
                        data_ready <= not cts_sync;
                        if data_valid = '1' and cts_sync = '0' then
                            state <= tx_start;
                            tx_reg <= data;
                            txd <= '0';
                            start_enabler <= '1';
                            data_ready <= '0';
                        end if;
                        if PARITY = 1 then -- odd
                            parity_sum <= '1';
                        else
                            parity_sum <= '0';
                        end if;
                    when tx_start =>
                        if enable(1) = '1' then
                            counter <= (others => '0');
                            txd <= tx_reg(0);
                            tx_reg <= '-' & tx_reg(tx_reg'left downto 1);
                            parity_sum <= parity_sum xor tx_reg(0);
                            state <= tx_data;
                        end if;
                    when tx_data =>
                        if enable(1) = '1' then
                            counter <= to_01(counter) + 1;
                            txd <= tx_reg(0);
                            tx_reg <= '-' & tx_reg(tx_reg'left downto 1);
                            parity_sum <= parity_sum xor tx_reg(0);
                            if counter = DATA_WIDTH - 1 then
                                if PARITY > 0 then
                                    state <= tx_parity;
                                    txd <= parity_sum;
                                else
                                    state <= tx_stop;
                                    txd <= '1';
                                end if;
                                counter <= (others => '0');
                            end if;
                        end if;
                    when tx_parity =>
                        if enable(1) = '1' then
                            state <= tx_stop;
                            txd <= '1';
                        end if;
                    when tx_stop =>
                        if enable(0) = '1' then
                            counter <= to_01(counter) + 1;
                            if counter = STOP_BITS then
                                state <= idle;
                                data_ready <= not cts_sync;
                            end if;
                        end if;
                    end case;
                end if;
            end if;
        end if;
    end process;


end behavioral;
