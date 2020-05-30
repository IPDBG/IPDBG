library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity IurtController is
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

        break_o                 : out std_logic;

        -- host interface
        data_dwn_ready          : out std_logic;
        data_dwn_valid          : in  std_logic;
        data_dwn                : in  std_logic_vector(7 downto 0);
        data_up_ready           : in  std_logic;
        data_up_valid           : out std_logic;
        data_up                 : out std_logic_vector(7 downto 0)
    );
end entity IurtController;


architecture behavioral of IurtController is
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
        break_o <= break_local and break_enable;

        process (clk) begin
            if rising_edge(clk) then
                if ce = '1' then
                    break_local <= data_dwn_valid;
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

    ipdbg_to_wb: block
        signal valid                : std_logic;
        signal set_ready            : std_logic;
        signal data_dwn_ready_local : std_logic;
        signal data_o_local         : std_logic_vector(7 downto 0);
    begin
        dat_o <= x"00000" & "00" & TxReady & valid & data_o_local;
        data_dwn_ready <= data_dwn_ready_local;
        valid <= not data_dwn_ready_local;
        process (clk, arst)
            procedure rd_reset_assignment is begin
                ack_rd <= '0';
                set_ready <= '-';
                data_dwn_ready_local <= '1';
                data_o_local <= (others => '-');
            end procedure rd_reset_assignment;
        begin
            if arst = '1' then
                rd_reset_assignment;
            elsif rising_edge(clk) then
                if srst = '1' then
                    rd_reset_assignment;
                else
                    if ce = '1' then
                        set_ready <= '0';
                        ack_rd <= '0';

                        if (cyc_i and stb_i) = '1' and we_i = '0' and ack_rd = '0' then
                            ack_rd <= '1';
                            if adr_i = "0" then
                                set_ready <= '1';
                            end if;
                        end if;

                        if data_dwn_valid = '1' then
                            data_o_local <= data_dwn;
                            data_dwn_ready_local <= '0';
                        elsif set_ready = '1' then
                            data_dwn_ready_local <= '1';
                        end if;
                    end if;
                end if;
            end if;
        end process;
    end block;

    wb_to_ipdbg: block
        signal buffer_empty : std_logic;
        signal data_buffer  : std_logic_vector(7 downto 0);
    begin
        TxReady <= buffer_empty;

        process (clk, arst)
            procedure wr_reset_assignment is begin
                buffer_empty <= '1';
                ack_wr <= '0';
                data_buffer<= (others => '-');
                data_up  <= (others => '-');
                data_up_valid <= '0';
            end procedure wr_reset_assignment;
        begin
            if arst = '1' then
                wr_reset_assignment;
            elsif rising_edge(clk) then
                if srst = '1' then
                    wr_reset_assignment;
                else
                    if ce = '1' then
                        data_up_valid <= '0';
                        if data_up_ready = '1' and buffer_empty = '0' then
                            buffer_empty <= '1';
                            data_up_valid <= '1';
                            data_up <= data_buffer;
                        end if;

                        ack_wr <= '0';
                        if (cyc_i and stb_i) = '1' and we_i = '1' and ack_wr = '0' and (buffer_empty = '1' or adr_i = "1") then
                            ack_wr <= '1';
                            if adr_i = "0" then
                                data_buffer <= dat_i(data_buffer'range);
                                buffer_empty <= '0';
                            end if;
                        end if;

                    end if;
                end if;
            end if;
        end process;
    end block;


end architecture behavioral;
