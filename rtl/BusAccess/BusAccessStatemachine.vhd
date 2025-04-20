library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;
use work.ipdbg_interface_pkg.all;

entity BusAccessStatemachine is
    generic (
        ASYNC_RESET   : boolean;
        ADDRESS_WIDTH : natural;
        R_DATA_WIDTH  : positive;
        W_DATA_WIDTH  : positive;
        STROBE_WIDTH  : natural;
        MISC_WIDTH    : natural;
        MISC_INIT     : std_logic_vector
    );
    port (
        clk           : in    std_logic;
        rst           : in    std_logic;
        ce            : in    std_logic;
        dn_lines      : in    ipdbg_dn_lines;
        up_lines      : out   ipdbg_up_lines;
        reset         : out   std_logic; -- reset from ipdbg protocol escaping
        address       : out   std_logic_vector;
        read_data     : in    std_logic_vector;
        write_data    : out   std_logic_vector;
        strobe        : out   std_logic_vector;
        miscellaneous : out   std_logic_vector;
        start_write   : out   std_logic;
        start_read    : out   std_logic;
        write_done    : in    std_logic;
        read_done     : in    std_logic;
        access_error  : in    std_logic;
        lock          : out   std_logic
    );
end entity BusAccessStatemachine;

architecture behavioral of BusAccessStatemachine is
    signal   arst, srst          : std_logic;
    constant HOST_WORD_SIZE      : natural                       := 8;
    constant VERSION_AND_ID      : std_logic_vector(31 downto 0) := x"0000001D";

    pure function round_up (num : natural; den : positive) return natural is
    begin
        return (num + den - 1) / den;
    end function;

    constant ADDRESS_WIDTH_BYTES : natural                       := round_up(ADDRESS_WIDTH, HOST_WORD_SIZE);
    constant R_DATA_WIDTH_BYTES  : natural                       := round_up(R_DATA_WIDTH, HOST_WORD_SIZE);
    constant W_DATA_WIDTH_BYTES  : natural                       := round_up(W_DATA_WIDTH, HOST_WORD_SIZE);
    constant STROBE_WIDTH_BYTES  : natural                       := round_up(STROBE_WIDTH, HOST_WORD_SIZE);
    constant MISC_WIDTH_BYTES    : natural                       := round_up(MISC_WIDTH, HOST_WORD_SIZE);
    constant ADDRESS_WIDTH_SLV   : std_logic_vector(31 downto 0) := std_logic_vector(to_unsigned(ADDRESS_WIDTH, 32));
    constant R_DATA_WIDTH_SLV    : std_logic_vector(31 downto 0) := std_logic_vector(to_unsigned(R_DATA_WIDTH, 32));
    constant W_DATA_WIDTH_SLV    : std_logic_vector(31 downto 0) := std_logic_vector(to_unsigned(W_DATA_WIDTH, 32));
    constant STROBE_WIDTH_SLV    : std_logic_vector(31 downto 0) := std_logic_vector(to_unsigned(STROBE_WIDTH, 32));
    constant MISC_WIDTH_SLV      : std_logic_vector(31 downto 0) := std_logic_vector(to_unsigned(MISC_WIDTH, 32));

    constant READ_WIDTHS_CMD     : std_logic_vector(7 downto 0) := x"AB";
    constant WRITE_CMD_LOCK      : std_logic_vector(7 downto 0) := x"BE";
    constant WRITE_CMD_UNLOCK    : std_logic_vector(7 downto 0) := x"BF";
    constant READ_CMD_LOCK       : std_logic_vector(7 downto 0) := x"CE";
    constant READ_CMD_UNLOCK     : std_logic_vector(7 downto 0) := x"CF";
    constant SET_ADDR_CMD        : std_logic_vector(7 downto 0) := x"D0";
    constant SET_MISC_CMD        : std_logic_vector(7 downto 0) := x"E5";
    constant SET_STRB_CMD        : std_logic_vector(7 downto 0) := x"92";
    constant ACK_RESP            : std_logic_vector(7 downto 0) := x"55";
    constant NACK_RESP           : std_logic_vector(7 downto 0) := x"33";

    -- lock is set at the start of an access when lock is '1'
    -- lock is cleared after the access when lock is '0'

    pure function bytes_transmitted_width return natural is
        constant WIDTH : natural := integer(ceil(log2(real(R_DATA_WIDTH + 1))));
        variable res   : natural := 2; -- must be able to tx at least 4 bytes for the widths
    begin
        if R_DATA_WIDTH > 0 then
            if res < WIDTH then
                res := WIDTH;
            end if;
        end if;

        return res;
    end function;

    pure function calc_max_bits_to_receive return natural is
        variable res : natural := 0;
    begin
        if res < ADDRESS_WIDTH then
            res := ADDRESS_WIDTH;
        end if;

        if res < W_DATA_WIDTH then
            res := W_DATA_WIDTH;
        end if;

        if res < STROBE_WIDTH then
            res := STROBE_WIDTH;
        end if;

        if res < MISC_WIDTH then
            res := MISC_WIDTH;
        end if;

        return res;
    end function;

    pure function bytes_received_width return natural is
        variable rx_bytes : natural := round_up(calc_max_bits_to_receive, HOST_WORD_SIZE);
    begin
        assert calc_max_bits_to_receive > 0
            report "no outputs to drive?"
            severity warning;
        return integer(ceil(log2(real(rx_bytes + 1))));
    end function;
    type     states              is (idle, read_width, write_access, read_access, set_address, set_misc, set_strb);
    type     rd_widths_substates is (rd_version_id, rd_write, rd_read, rd_addr, rd_misc, rd_strb);
    type     handshake_states    is (start, mem, shift, next_data);
    constant MAX_BYTES_RECEIVE   : natural := round_up(calc_max_bits_to_receive, HOST_WORD_SIZE);
    signal   state               : states;
    signal   rd_widths_substate  : rd_widths_substates;
    signal   handshake_state     : handshake_states;

    signal   bytes_received      : unsigned(bytes_received_width - 1 downto 0);
    signal   expected_bytes      : unsigned(bytes_received_width - 1 downto 0);
    signal   bytes_transmitted   : unsigned(bytes_transmitted_width - 1 downto 0);
    alias    bytes_txed_lsbs     : unsigned(1 downto 0) is bytes_transmitted(1 downto 0);
    signal   next_lock           : std_logic;
    signal   data_in_reg         : std_logic_vector(HOST_WORD_SIZE - 1 downto 0);
    signal   data_in_reg_valid   : std_logic;
    signal   data_in_reg_laddr   : std_logic;
    signal   data_in_reg_lwdat   : std_logic;
    signal   data_in_reg_lstrb   : std_logic;
    signal   data_in_reg_lmisc   : std_logic;
    signal   write_busy          : std_logic;
    signal   wait_response       : std_logic;
    signal   resp_pending        : std_logic;
    signal   read_data_reg       : std_logic_vector(R_DATA_WIDTH - 1 downto 0);
begin
    async_init : if ASYNC_RESET generate
    begin
        arst <= rst;
        srst <= '0';
    end generate async_init;
    sync_init : if not ASYNC_RESET generate
    begin
        arst <= '0';
        srst <= rst;
    end generate sync_init;

    assert MISC_INIT'length = miscellaneous'length
        report "MISC_INIT and miscellaneous must have the same width"
        severity failure;
    assert MISC_WIDTH = miscellaneous'length or MISC_WIDTH = 0
        report "MISC_WIDTH has to match the width of miscellaneous"
        severity failure;
    assert STROBE_WIDTH = strobe'length or STROBE_WIDTH = 0
        report "STROBE_WIDTH has to match the width of strobe"
        severity failure;
    assert R_DATA_WIDTH = read_data'length or R_DATA_WIDTH = 0
        report "R_DATA_WIDTH has to match the width of read_data"
        severity failure;
    assert W_DATA_WIDTH = write_data'length or W_DATA_WIDTH = 0
        report "W_DATA_WIDTH has to match the width of write_data"
        severity failure;
    assert ADDRESS_WIDTH = address'length or ADDRESS_WIDTH = 0
        report "ADDRESS_WIDTH has to match the width of address"
        severity failure;

    up_lines.dnlink_ready <= '1';

    process (clk, arst)
        procedure shift_read_data_reg is begin
            read_data_reg(read_data_reg'left - 8 downto 0) <= read_data_reg(read_data_reg'left downto 8);
        end procedure;
        procedure update_read_data_reg is begin
            if read_data_reg'length > 8 then
                shift_read_data_reg;
            end if;
        end procedure;
        procedure reset_assignment is begin
            state                 <= idle;
            rd_widths_substate    <= rd_version_id;
            handshake_state       <= start;
            up_lines.uplink_valid <= '0';
            up_lines.uplink_data  <= (others => '-');
            next_lock             <= '-';
            write_busy            <= '-';
            wait_response         <= '-';
            bytes_received        <= (others => '-');
            bytes_transmitted     <= (others => '-');
            data_in_reg           <= (others => '-');
            read_data_reg         <= (others => '-');
            data_in_reg_valid     <= '0';
            data_in_reg_laddr     <= '0';
            data_in_reg_lstrb     <= '0';
            data_in_reg_lmisc     <= '0';
            data_in_reg_lwdat     <= '0';
            start_write           <= '0';
            lock                  <= '0';
            start_read            <= '0';
            resp_pending          <= '-';
        end procedure reset_assignment;
        variable tmp_rd_size : std_logic_vector(31 downto 0);
    begin
        if arst = '1' then
            reset_assignment;
        elsif rising_edge(clk) then
            if srst = '1' then
                reset_assignment;
            else
                if ce = '1' then
                    up_lines.uplink_valid <= '0';
                    data_in_reg_valid     <= '0';
                    data_in_reg_laddr     <= '0';
                    data_in_reg_lstrb     <= '0';
                    data_in_reg_lmisc     <= '0';
                    data_in_reg_lwdat     <= '0';

                    start_write           <= '0';
                    start_read            <= '0';
                    case state is
                    when idle =>
                        bytes_received     <= (others => '0');
                        bytes_transmitted  <= (others => '0');
                        write_busy         <= '0';
                        wait_response      <= '0';
                        rd_widths_substate <= rd_version_id;
                        handshake_state    <= start;
                        resp_pending       <= '0';
                        if dn_lines.dnlink_valid = '1' then
                            if dn_lines.dnlink_data = READ_WIDTHS_CMD then
                                state <= read_width;
                            end if;
                            if W_DATA_WIDTH > 0 and
                               (dn_lines.dnlink_data = WRITE_CMD_LOCK or dn_lines.dnlink_data = WRITE_CMD_UNLOCK) then
                                state     <= write_access;
                                next_lock <= dn_lines.dnlink_data(0);
                            end if;
                            if R_DATA_WIDTH > 0 and
                               (dn_lines.dnlink_data = READ_CMD_LOCK or dn_lines.dnlink_data = READ_CMD_UNLOCK) then
                                state         <= read_access;
                                lock          <= dn_lines.dnlink_data(0);
                                start_read    <= '1';
                                wait_response <= '1';
                            end if;
                            if ADDRESS_WIDTH > 0 and dn_lines.dnlink_data = SET_ADDR_CMD then
                                state          <= set_address;
                                expected_bytes <= to_unsigned(ADDRESS_WIDTH_BYTES - 1, bytes_received_width);
                            end if;
                            if MISC_WIDTH > 0 and dn_lines.dnlink_data = SET_MISC_CMD then
                                state          <= set_misc;
                                expected_bytes <= to_unsigned(MISC_WIDTH_BYTES - 1, bytes_received_width);
                            end if;
                            if STROBE_WIDTH > 0 and dn_lines.dnlink_data = SET_STRB_CMD then
                                state          <= set_strb;
                                expected_bytes <= to_unsigned(STROBE_WIDTH_BYTES - 1, bytes_received_width);
                            end if;
                        end if;
                    when read_width =>
                        tmp_rd_size := (others => '0');
                        -- vsg_off case_012 case_005
                        case rd_widths_substate is
                        when rd_version_id => tmp_rd_size := VERSION_AND_ID;
                        when rd_write      => tmp_rd_size := W_DATA_WIDTH_SLV;
                        when rd_read       => tmp_rd_size := R_DATA_WIDTH_SLV;
                        when rd_addr       => tmp_rd_size := ADDRESS_WIDTH_SLV;
                        when rd_misc       => tmp_rd_size := MISC_WIDTH_SLV;
                        when rd_strb       => tmp_rd_size := STROBE_WIDTH_SLV;
                        end case;

                        case bytes_txed_lsbs is
                        when "00"   => up_lines.uplink_data <= tmp_rd_size(7 downto 0);
                        when "01"   => up_lines.uplink_data <= tmp_rd_size(15 downto 8);
                        when "10"   => up_lines.uplink_data <= tmp_rd_size(23 downto 16);
                        when others => up_lines.uplink_data <= tmp_rd_size(31 downto 24);
                        end case;
                        -- vsg_on

                        up_lines.uplink_valid <= '0';
                        if handshake_state = start then
                            if dn_lines.uplink_ready = '1' then
                                up_lines.uplink_valid <= '1';
                                bytes_transmitted     <= bytes_transmitted + 1;
                                handshake_state <= shift;
                                if bytes_transmitted(1 downto 0) = "11" then
                                    bytes_transmitted <= (others => '0');
                                    -- vsg_off case_012 case_005
                                    case rd_widths_substate is
                                    when rd_version_id => rd_widths_substate <= rd_write;
                                    when rd_write      => rd_widths_substate <= rd_read;
                                    when rd_read       => rd_widths_substate <= rd_addr;
                                    when rd_addr       => rd_widths_substate <= rd_misc;
                                    when rd_misc       => rd_widths_substate <= rd_strb;
                                    when rd_strb       => rd_widths_substate <= rd_version_id;
                                        state                                <= idle;
                                    -- vsg_on
                                    end case;
                                end if;
                            end if;
                        else
                            handshake_state <= start;
                        end if;
                    when read_access =>
                        up_lines.uplink_valid <= '0';
                        if wait_response = '1' then
                            if read_done = '1' then
                                -- store answer
                                wait_response <= '0';
                                if access_error = '0' then
                                    up_lines.uplink_data <= ACK_RESP;
                                else
                                    up_lines.uplink_data <= NACK_RESP;
                                end if;
                                read_data_reg <= read_data;
                                if dn_lines.uplink_ready = '1' then
                                    up_lines.uplink_valid <= '1';
                                    handshake_state       <= shift;
                                else
                                    resp_pending <= '1';
                                end if;
                            end if;
                        else
                            if handshake_state = start then
                                if dn_lines.uplink_ready = '1' then
                                    up_lines.uplink_valid <= '1';
                                    handshake_state <= shift;
                                    if resp_pending = '1' then
                                        resp_pending <= '0';
                                    else
                                        bytes_transmitted    <= bytes_transmitted + 1;
                                        up_lines.uplink_data <= read_data_reg(7 downto 0);
                                        update_read_data_reg;
                                        if to_integer(bytes_transmitted) = R_DATA_WIDTH_BYTES - 1 then
                                            bytes_transmitted <= (others => '0');
                                            state             <= idle;
                                        end if;
                                    end if;
                                end if;
                            else
                                handshake_state <= start;
                            end if;
                        end if;
                    when write_access =>
                        if dn_lines.dnlink_valid = '1' then
                            bytes_received    <= bytes_received + 1;
                            data_in_reg       <= dn_lines.dnlink_data;
                            data_in_reg_valid <= '1';
                            if bytes_received = W_DATA_WIDTH_BYTES - 1 then
                                data_in_reg_lwdat <= '1';
                                wait_response     <= '1';
                            end if;
                        end if;
                        if data_in_reg_lwdat = '1' then
                            start_write <= '1';
                            lock        <= next_lock;
                        end if;
                        if wait_response = '1' then
                            if write_done = '1' then
                                -- store answer
                                if access_error = '0' then
                                    up_lines.uplink_data <= ACK_RESP;
                                else
                                    up_lines.uplink_data <= NACK_RESP;
                                end if;
                                wait_response <= '0';
                                write_busy    <= '1';
                            end if;
                        end if;
                        if write_busy = '1' then
                            if dn_lines.uplink_ready = '1' then
                                up_lines.uplink_valid <= '1';
                                state                 <= idle;
                            end if;
                        end if;
                    when set_address | set_misc | set_strb =>
                        if dn_lines.dnlink_valid = '1' then
                            bytes_received    <= bytes_received + 1;
                            data_in_reg       <= dn_lines.dnlink_data;
                            data_in_reg_valid <= '1';
                            if bytes_received = expected_bytes then
                                state <= idle;
                                case state is
                                when set_address =>
                                    data_in_reg_laddr <= '1';
                                when set_misc =>
                                    data_in_reg_lmisc <= '1';
                                when others =>
                                    data_in_reg_lstrb <= '1';
                                end case;
                            end if;
                        end if;
                    end case;
                end if;
            end if;
        end if;
    end process;

    rx_regs : block
        constant MAX_BITS_TO_RECEIVE : natural := calc_max_bits_to_receive;
        signal   rx_sr               : std_logic_vector(MAX_BITS_TO_RECEIVE - 1 downto 0);
    begin
        gen_small : if MAX_BITS_TO_RECEIVE <= 8 generate
        begin
            rx_sr <= data_in_reg(rx_sr'range);
        end generate;

        gen_big : if MAX_BITS_TO_RECEIVE > 8 generate
        begin
            rx_sr(rx_sr'left downto rx_sr'left - 7) <= data_in_reg;
            process (clk)
            begin
                if rising_edge(clk) then
                    if ce = '1' then
                        if data_in_reg_valid = '1' then
                            rx_sr(rx_sr'left - 8 downto 0) <= rx_sr(rx_sr'left downto 8);
                        end if;
                    end if;
                end if;
            end process;
        end generate;

        assign_address : if ADDRESS_WIDTH > 0 generate
            constant SR_BASE_IDX : natural := (MAX_BYTES_RECEIVE - ADDRESS_WIDTH_BYTES) * HOST_WORD_SIZE;
        begin
            process (clk, arst)
            begin
                if arst = '1' then
                    address <= (address'range => '0');
                elsif rising_edge(clk) then
                    if srst = '1' then
                        address <= (address'range  => '0');
                    else
                        if ce = '1' then
                            if (data_in_reg_valid  and data_in_reg_laddr) = '1' then
                                address <= rx_sr(address'length - 1 + SR_BASE_IDX downto SR_BASE_IDX);
                            end if;
                        end if;
                    end if;
                end if;
            end process;
        end generate;

        assign_write_data : if W_DATA_WIDTH > 0 generate
            constant SR_BASE_IDX : natural := (MAX_BYTES_RECEIVE - W_DATA_WIDTH_BYTES) * HOST_WORD_SIZE;
        begin
            process (clk, arst)
            begin
                if arst = '1' then
                    write_data <= (write_data'range => '-');
                elsif rising_edge(clk) then
                    if srst = '1' then
                        write_data <= (write_data'range => '-');
                    else
                        if ce = '1' then
                            if (data_in_reg_valid  and data_in_reg_lwdat) = '1' then
                                write_data <= rx_sr(write_data'length - 1 + SR_BASE_IDX downto SR_BASE_IDX);
                            end if;
                        end if;
                    end if;
                end if;
            end process;
        end generate;

        assign_strobe : if STROBE_WIDTH > 0 generate
            constant SR_BASE_IDX : natural := (MAX_BYTES_RECEIVE - STROBE_WIDTH_BYTES) * HOST_WORD_SIZE;
        begin
            process (clk, arst)
            begin
                if arst = '1' then
                    strobe <= (strobe'range => '1');
                elsif rising_edge(clk) then
                    if srst = '1' then
                        strobe <= (strobe'range => '1');
                    else
                        if ce = '1' then
                            if (data_in_reg_valid  and data_in_reg_lstrb) = '1' then
                                strobe <= rx_sr(strobe'length - 1 + SR_BASE_IDX downto SR_BASE_IDX);
                            end if;
                        end if;
                    end if;
                end if;
            end process;
        end generate;

        assign_misc : if MISC_WIDTH > 0 generate
            constant SR_BASE_IDX : natural := (MAX_BYTES_RECEIVE - MISC_WIDTH_BYTES) * HOST_WORD_SIZE;
        begin
            process (clk, arst)
            begin
                if arst = '1' then
                    miscellaneous <= MISC_INIT;
                elsif rising_edge(clk) then
                    if srst = '1' then
                        miscellaneous <= MISC_INIT;
                    else
                        if ce = '1' then
                            if (data_in_reg_valid  and data_in_reg_lmisc) = '1' then
                                miscellaneous <= rx_sr(miscellaneous'length - 1 + SR_BASE_IDX downto SR_BASE_IDX);
                            end if;
                        end if;
                    end if;
                end if;
            end process;
        end generate;
    end block;
end architecture behavioral;
