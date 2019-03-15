library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart is
    generic (
        DIV_BAUD    : positive := 40;
        ASYNC_RESET : boolean
    );
    port (
        clk                 : in  std_logic;
        rst                 : in  std_logic;
        ce                  : in  std_logic;
        -- host interface
        data_dwn_valid      : out std_logic;
        data_dwn            : out std_logic_vector(7 downto 0);
        data_up_ready       : out std_logic;
        data_up_valid       : in  std_logic;
        data_up             : in  std_logic_vector(7 downto 0);

        tx                  : out std_logic;
        rx                  : in  std_logic
    );
end uart;

architecture behavioral of uart is


    signal arst, srst             : std_logic;

    signal tx_local               : std_logic;


    signal baud_clk               : std_logic;
    signal baud_clk_tx            : std_logic;

    signal start_bit_valid        : std_logic;

begin
    tx <= tx_local;


    gen_arst: if ASYNC_RESET generate begin
        arst <= rst;
        srst <= '0';
    end generate gen_arst;

    gen_srst:  if not ASYNC_RESET generate begin
        arst <= '0';
        srst <= rst;
    end generate gen_srst;

    baud_ce_gen:block
        signal baud_counter    : natural range 0 to DIV_BAUD-1;
    begin
        gen_baud_clk: process(clk) begin
            if rising_edge(clk) then
                if baud_counter = DIV_BAUD-1 then
                    baud_clk <= '1';
                    baud_counter <= 0;
                else
                    baud_clk <= '0';
                    baud_counter <= baud_counter +1;
                end if;
            end if;
        end process;
    end block;

    receive_data : block

        type rx_states is (
            idle,
            rx_data,
            send
        );
        signal rx_state         : rx_states := idle;
        signal rx_data_vector   : std_logic_vector(7 downto 0);
        signal data_lvl_counter : natural range 0 to 16;
        signal rx_bit_counter   : unsigned(4 downto 0);
        signal rx_clk_divider   : unsigned(3 downto 0);
        signal rx_dat           : std_logic_vector(15 downto 0);
        signal rx_notsynced     : std_logic_vector (4 downto 0);
        signal rx_synced        : std_logic;
        signal d                : std_logic;
        signal q                : std_logic;

        component dffpc is
            port(
                clk : in  std_logic;
                ce  : in  std_logic;
                d   : in  std_logic;
                q   : out std_logic
            );
        end component dffpc;
    begin
        rx_notsynced(0) <=rx ;
        mff_flops: for i in 0 to 3 generate begin
            ou_dffpc : component dffpc
                port map(
                    clk => clk,
                    ce  => ce,
                    d   => rx_notsynced(i),
                    q   => rx_notsynced(i +1)
                );
        end generate;
        rx_synced <= rx_notsynced(4);
        process(clk,arst)
            procedure rx_data_reset_assignment is begin
                data_dwn_valid <= '0';
                data_lvl_counter <= 16;
                rx_dat <= (others => '1');
                rx_state <= idle;
                rx_bit_counter <= (others => '-');
                rx_clk_divider <= (others => '-');
                rx_data_vector <= (others => '-');
                data_dwn <= (others => '-');
            end procedure rx_data_reset_assignment;
        begin
            if arst = '1' then
                rx_data_reset_assignment;
            elsif rising_edge(clk) then
                if srst = '1' then
                    rx_data_reset_assignment;
                else
                    data_dwn_valid <= '0';
                    if baud_clk = '1' then
                        rx_dat <= rx_dat(14 downto 0) & rx_synced;

                        if rx_synced = '0' and rx_dat(15) = '1' then
                            data_lvl_counter <= data_lvl_counter - 1;
                        elsif rx_synced = '1' and rx_dat(15) = '0' then
                            data_lvl_counter <= data_lvl_counter + 1;
                        end if;
                    end if;

                    if baud_clk = '1' then
                        case rx_state is
                        when idle => -- waiting on startbit
                            if data_lvl_counter < 4 then
                                rx_clk_divider <= (others => '0');
                                rx_state <= rx_data;
                                rx_bit_counter <= (others => '0');
                            end if;
                        when rx_data =>
                            if rx_clk_divider = 15 then
                                if data_lvl_counter >= 8 then
                                    rx_data_vector <= '1' & rx_data_vector(7 downto 1);
                                else
                                    rx_data_vector <= '0' & rx_data_vector(7 downto 1);
                                end if;
                                if rx_bit_counter = 7 then
                                    rx_state <= send;
                                else
                                    rx_bit_counter <= rx_bit_counter + 1;
                                end if;

                                rx_clk_divider <= (others => '0');
                            else
                                rx_clk_divider <= rx_clk_divider + 1;
                            end if;
                        when send =>
                            if rx_clk_divider = 15 then
                                data_dwn <= rx_data_vector;
                                data_dwn_valid <= '1';
                                rx_clk_divider <= (others => '0');
                                rx_state <= idle;
                            else
                                rx_clk_divider <= rx_clk_divider + 1;
                            end if;

                        end case;
                    end if;
                end if;
            end if;
        end process;
    end block;

    send_data : block
         type tx_states is (
            --idle,
            start_bit,
            send_dat,
            stop_bit
        );
        signal tx_state          : tx_states;
        signal data_send_counter : natural range 0 to 8;
        signal tx_data_vector    : std_logic_vector ( 7 downto 0 );
        signal baud_counter_tx   : natural range 0 to 16;

        signal data_up_ready_local    : std_logic;

    begin
        process(clk,arst)
            procedure send_data_reset_assignment is begin
                tx_local <= '1';
                tx_state <= start_bit;
                data_up_ready_local <= '1';
                tx_data_vector <= (others => '-');
            end procedure send_data_reset_assignment;
        begin
            if arst = '1' then
                send_data_reset_assignment;
            elsif rising_edge(clk) then
                if srst = '1' then
                    send_data_reset_assignment;
                else
                    if data_up_ready_local = '1' then
                        if data_up_valid = '1' then
                            data_up_ready_local <= '0';
                            tx_state <= start_bit;
                            tx_data_vector <= data_up;
                            tx_state <= start_bit;
                        end if;
                        baud_clk_tx <= '1';
                        baud_counter_tx <= 0;
                        data_send_counter <= 0;
                    else
                        if baud_clk = '1' then
                            if baud_counter_tx = 15 then
                                baud_clk_tx <= '1';
                                baud_counter_tx <= 0;
                            else
                                baud_counter_tx <= baud_counter_tx +1;
                                baud_clk_tx <= '0';
                            end if;
                            if baud_clk_tx = '1' then
                                case tx_state is
                                when start_bit =>
                                    tx_local <= '0'; -- value of sb
                                    tx_state <= send_dat;
                                when send_dat =>
                                    tx_local <= tx_data_vector(0);
                                    tx_data_vector <= '1' & tx_data_vector(7 downto 1);
                                    if data_send_counter = 8 then
                                        data_send_counter <= 0;
                                        tx_state <= stop_bit;
                                    else
                                        data_send_counter <= data_send_counter +1;
                                    end if;
                                when stop_bit =>
                                    data_up_ready_local <= '1'; -- idle
                                end case;
                            end if;
                        end if;
                    end if;
                end if;
            end if;
        end process;
        data_up_ready <= data_up_ready_local;
    end block;




end architecture behavioral;
