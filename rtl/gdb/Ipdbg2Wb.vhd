library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity Ipdbg2Wb is
    generic(
         ASYNC_RESET : boolean
    );
    port(
        clk                     : in  std_logic;
        rst                     : in  std_logic;
        ce                      : in  std_logic;
        -- wishbone slave
        cyc_i                   : in  std_logic;
        stb_i                   : in  std_logic;
        we_i                    : in  std_logic;
        adr_i                   : in  std_logic_vector(2 downto 2);
        dat_i                   : in  std_logic_vector(31 downto 0);
        dat_o                   : out std_logic_vector(31 downto 0);
        ack_o                   : out std_logic;

        break                   : out std_logic;

        -- host interface
        data_dwn_valid          : in  std_logic;
        data_dwn                : in  std_logic_vector(7 downto 0);
        data_up_ready           : in  std_logic;
        data_up_valid           : out std_logic;
        data_up                 : out std_logic_vector(7 downto 0)
    );
end entity Ipdbg2Wb;


architecture behavioral of Ipdbg2Wb is
    component Fifo is
        generic(
            EXTRA_LEVEL_COUNTER : boolean;
            ASYNC_RESET         : boolean;
            MEM_DEPTH           : integer
        );
        port(
            clk               : in  std_logic;
            rst               : in  std_logic;
            ce                : in  std_logic;
            full              : out std_logic;
            write_data_enable : in  std_logic;
            write_data        : in  std_logic_vector;
            empty             : out std_logic;
            read_data_enable  : in  std_logic;
            read_data         : out std_logic_vector
        );
    end component Fifo;

    signal fifo_full              : std_logic;
    signal fifo_write_data_enable : std_logic;
    signal fifo_write_data        : std_logic_vector(7 downto 0);
    signal fifo_empty             : std_logic;
    signal fifo_read_data_enable  : std_logic;
    signal fifo_read_data         : std_logic_vector(7 downto 0);

    signal TxReady                : std_logic;

    signal arst, srst             : std_logic;
    signal ack_wr                 : std_logic;
    signal ack_rd                 : std_logic;
begin

    gen_arst: if ASYNC_RESET generate begin
        arst <= rst;
        srst <= '0';
    end generate gen_arst;
    gen_srst:  if not ASYNC_RESET generate begin
        arst <= '0';
        srst <= rst;
    end generate gen_srst;

    break_handling : block
        signal break_enable : std_logic;
        signal break_local  : std_logic;
    begin
        break <= break_local and break_enable;

        process (clk) begin
            if rising_edge(clk) then
                if ce = '1' then
                    break_local <= '0';
                    if fifo_full = '0' and data_dwn_valid = '1' then -- data received from jtag if
                        break_local <= '1';
                    end if;
                end if;
            end if;
        end process;

        process (clk, arst) begin
            if arst = '1' then
                break_enable <= '1';
            elsif rising_edge(clk) then
                if srst = '1' then
                    break_enable <= '1';
                else
                    if ce = '1' then
                        if (break_local and break_enable) = '1' then
                            break_enable <= '0'; -- clear after activation
                        end if;
                        if (cyc_i and stb_i) = '1' and we_i = '1' and adr_i = "1" and ack_wr = '0' then
                            break_enable <= dat_i(0);
                        end if;
                    end if;
                end if;
            end if;
        end process;
    end block;

    ack_o <= ack_wr or ack_rd;

    output_wb: block
        signal valid                         : std_logic;
        signal clear_valid                   : std_logic;
        signal fifo_read_data_enable_delayed : std_logic;
        signal data_o_local                  : std_logic_vector(7 downto 0);
    begin
        dat_o <= x"00000" & "00" & TxReady & valid & data_o_local;
        process (clk, arst)
            procedure rd_reset_assignment is begin
                valid <= '0';
                ack_rd <= '0';
                clear_valid <= '-';
                fifo_read_data_enable <= '-';
                fifo_read_data_enable_delayed <= '-';
            end procedure rd_reset_assignment;
        begin
            if arst = '1' then
                rd_reset_assignment;
            elsif rising_edge(clk) then
                if srst = '1' then
                    rd_reset_assignment;
                else
                    if ce = '1' then
                        fifo_read_data_enable_delayed <= fifo_read_data_enable;
                        clear_valid <= '0';
                        ack_rd <= '0';

                        if (cyc_i and stb_i) = '1' and we_i = '0' and ack_rd = '0' then
                            ack_rd <= '1';
                            if adr_i = "0" then
                                clear_valid <= '1';
                            end if;
                        end if;

                        if fifo_read_data_enable_delayed = '1' then
                            data_o_local <= fifo_read_data;
                            valid <= '1';
                        elsif clear_valid = '1' then
                            valid <= '0';
                        end if;

                        if fifo_empty = '0' and valid = '0' and fifo_read_data_enable = '0' and fifo_read_data_enable_delayed = '0' then
                            fifo_read_data_enable <= '1';
                        else
                            fifo_read_data_enable <= '0';
                        end if;
                    end if;
                end if;
            end if;
        end process;
    end block;

    input_wb: block
        signal empty               : std_logic;
        signal empty_delay         : std_logic;
        signal data_up_valid_local : std_logic;
        signal ack_wr_data_buffer  : std_logic;
        signal data_i_local        : std_logic_vector(7 downto 0 );
    begin

        process (clk, arst)
            procedure wr_reset_assignment is begin
                empty <= '1';
                ack_wr <= '0';
                ack_wr_data_buffer <= '0';
                data_i_local  <= (others => '-');
                data_up  <= (others => '-');
                data_up_valid_local <= '0';
            end procedure wr_reset_assignment;
        begin
            if arst = '1' then
                wr_reset_assignment;
            elsif rising_edge(clk) then
                if srst = '1' then
                    wr_reset_assignment;
                else
                    if ce = '1' then
                        ack_wr_data_buffer <= '0';
                        if (cyc_i and stb_i) = '1' and we_i = '1' and ack_wr = '0' and (empty = '1' or adr_i = "1") then
                            ack_wr <= '1';
                            if adr_i = "0" then
                                data_i_local <= dat_i(data_i_local'range);
                                ack_wr_data_buffer <= '1';
                            end if;
                        else
                            ack_wr <= '0';
                        end if;

                        if ack_wr_data_buffer = '1' then
                            empty <= '0';
                        elsif data_up_valid_local = '1' then
                            empty <= '1';
                        end if;

                        if data_up_ready = '1' and empty = '0' and data_up_valid_local = '0' then
                            data_up_valid_local <= '1';
                            data_up <= data_i_local;
                        else
                            data_up_valid_local <= '0';
                        end if;
                    end if;
                end if;
            end if;
        end process;
        data_up_valid <= data_up_valid_local;
        TxReady <= empty;
    end block;

    our_fifo : component Fifo
        generic map(
            EXTRA_LEVEL_COUNTER => false,
            ASYNC_RESET         => ASYNC_RESET,
            MEM_DEPTH           => 4
        )
        port map(
            clk               => clk,
            rst               => rst,
            ce                => ce,
            full              => fifo_full,
            write_data_enable => fifo_write_data_enable,
            write_data        => fifo_write_data,
            empty             => fifo_empty,
            read_data_enable  => fifo_read_data_enable,
            read_data         => fifo_read_data
        );

    fill_fifo:  process(clk)begin
        if rising_edge(clk) then
            if ce = '1' then
                fifo_write_data <= data_dwn;
                if fifo_full = '0' then
                    fifo_write_data_enable <= data_dwn_valid;
                else
                    fifo_write_data_enable <= '0';
                end if;
            end if;
        end if;
    end process;

end architecture behavioral;
