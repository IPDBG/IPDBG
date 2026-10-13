-- SPDX-FileCopyrightText: The IPDBG authors
-- SPDX-License-Identifier: CERN-OHL-W-2.0

-- Self-checking testbench for BusAccessController (protocol and escaping)
-- with the host model of ipdbg_test_pkg and a bus model with 16 words, a
-- random latency and an error on word 15. Checks the widths, set address,
-- strobe and misc, random writes and reads with ACK and NACK, lock, escaped
-- data, and a reset in the middle of a command. Reports
-- "tb_BusAccess: all tests passed".

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ipdbg_interface_pkg.all;
use work.ipdbg_test_pkg.all;

entity tb_BusAccess is
    generic(
        ASYNC_RESET       : boolean  := true;
        ADDRESS_WIDTH     : natural  := 12;    -- at least 4
        R_DATA_WIDTH      : positive := 32;
        W_DATA_WIDTH      : positive := 32;
        STROBE_WIDTH      : natural  := 4;
        MISC_WIDTH        : natural  := 3;
        SEED              : positive := 1;
        MAX_GAP           : natural  := 3;     -- downstream: 0..MAX_GAP idle clocks before each byte
        MAX_DELAY         : natural  := 4;     -- upstream: ready '0' for 0..MAX_DELAY clocks after each byte
        READY_AFTER_VALID : boolean  := false; -- uplink_ready only after uplink_valid
        MAX_LATENCY       : natural  := 5      -- bus: done after 1 + 0..MAX_LATENCY clocks
    );
end entity tb_BusAccess;

architecture test of tb_BusAccess is
    constant MISC_LEN   : positive := maximum(MISC_WIDTH, 1);
    constant MISC_INIT  : std_logic_vector(MISC_LEN - 1 downto 0) := std_logic_vector(to_unsigned(5 mod 2 ** MISC_LEN, MISC_LEN));
    constant A_BYTES    : natural  := (ADDRESS_WIDTH + 7) / 8;
    constant R_BYTES    : positive := bytes_of(R_DATA_WIDTH);
    constant W_BYTES    : positive := bytes_of(W_DATA_WIDTH);
    constant ERROR_WORD : natural  := 15;

    constant READ_WIDTHS : byte_t := x"AB";
    constant WRITE_LOCK  : byte_t := x"BE";
    constant WRITE       : byte_t := x"BF";
    constant READ_LOCK   : byte_t := x"CE";
    constant READ        : byte_t := x"CF";
    constant SET_ADDR    : byte_t := x"D0";
    constant SET_MISC    : byte_t := x"E5";
    constant SET_STRB    : byte_t := x"92";
    constant ACK         : byte_t := x"55";
    constant NACK        : byte_t := x"33";

    signal clk          : std_logic := '0';
    signal rst          : std_logic := '1';
    signal done         : boolean   := false;

    signal dn_valid     : std_logic := '0';
    signal dn_data      : byte_t;
    signal up_ready     : std_logic;
    signal dn_lines     : ipdbg_dn_lines;
    signal up_lines     : ipdbg_up_lines;

    signal address      : std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
    signal read_data    : std_logic_vector(R_DATA_WIDTH - 1 downto 0);
    signal write_data   : std_logic_vector(W_DATA_WIDTH - 1 downto 0);
    signal strobe       : std_logic_vector(STROBE_WIDTH - 1 downto 0);
    signal misc         : std_logic_vector(MISC_LEN - 1 downto 0);
    signal start_write  : std_logic;
    signal start_read   : std_logic;
    signal write_done   : std_logic := '0';
    signal read_done    : std_logic := '0';
    signal access_error : std_logic := '0';
    signal lock         : std_logic;

    -- the last access, from the bus model
    type word_array is array (0 to 15) of std_logic_vector(W_DATA_WIDTH - 1 downto 0);
    signal acc_count    : natural := 0;
    signal acc_write    : boolean;
    signal acc_address  : std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
    signal acc_data     : std_logic_vector(W_DATA_WIDTH - 1 downto 0);
    signal acc_strobe   : std_logic_vector(STROBE_WIDTH - 1 downto 0);
    signal acc_misc     : std_logic_vector(MISC_LEN - 1 downto 0);
    signal acc_lock     : std_logic;
begin
    clk <= not clk after 5 ns when not done;

    dn_lines <= (uplink_ready => up_ready, dnlink_valid => dn_valid, dnlink_data => dn_data);
    host_sink(clk, up_lines.uplink_valid, up_lines.uplink_data, up_ready, MAX_DELAY, READY_AFTER_VALID);

    dut : entity work.BusAccessController
        generic map(
            ASYNC_RESET   => ASYNC_RESET,
            ADDRESS_WIDTH => ADDRESS_WIDTH,
            R_DATA_WIDTH  => R_DATA_WIDTH,
            W_DATA_WIDTH  => W_DATA_WIDTH,
            STROBE_WIDTH  => STROBE_WIDTH,
            MISC_WIDTH    => MISC_WIDTH,
            MISC_INIT     => MISC_INIT,
            CORE_TYPE     => 0
        )
        port map(
            clk           => clk,
            rst           => rst,
            ce            => '1',
            dn_lines      => dn_lines,
            up_lines      => up_lines,
            reset         => open,
            address       => address,
            read_data     => read_data,
            write_data    => write_data,
            strobe        => strobe,
            miscellaneous => misc,
            start_write   => start_write,
            start_read    => start_read,
            write_done    => write_done,
            read_done     => read_done,
            access_error  => access_error,
            lock          => lock
        );

    bus_model : process
        variable mem     : word_array := (others => (others => '0'));
        variable word    : natural;
        variable latency : natural;
        variable is_write : boolean;
    begin
        read_data    <= (others => 'X');
        write_done   <= '0';
        read_done    <= '0';
        access_error <= 'X';
        wait until rising_edge(clk);
        if (start_write or start_read) = '1' then
            assert not (start_write = '1' and start_read = '1') report "start_write and start_read" severity failure;
            is_write := start_write = '1';
            word := to_integer(unsigned(address(3 downto 0)));
            acc_write   <= is_write;
            acc_address <= address;
            acc_data    <= write_data;
            acc_strobe  <= strobe;
            acc_misc    <= misc;
            acc_lock    <= lock;
            latency := random_int(0, MAX_LATENCY);
            for i in 1 to latency loop
                wait until rising_edge(clk);
                assert (start_write or start_read) = '0' report "start during an access" severity failure;
            end loop;
            if word = ERROR_WORD then
                access_error <= '1';
                read_data <= random_slv(R_DATA_WIDTH);
            else
                access_error <= '0';
                if is_write then
                    mem(word) := write_data;
                else
                    read_data <= std_logic_vector(resize(unsigned(mem(word)), R_DATA_WIDTH));
                end if;
            end if;
            if is_write then
                write_done <= '1';
            else
                read_done <= '1';
            end if;
            acc_count <= acc_count + 1;
            wait until rising_edge(clk);
        end if;
    end process;

    stimulus : process
        variable ref        : word_array := (others => (others => '0'));
        variable curr_addr  : std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
        variable curr_strb  : std_logic_vector(STROBE_WIDTH - 1 downto 0);
        variable curr_misc  : std_logic_vector(MISC_LEN - 1 downto 0);
        variable count      : natural;

        procedure send(bytes : byte_array) is
        begin
            host_send(clk, dn_valid, dn_data, up_lines.dnlink_ready, bytes, MAX_GAP);
        end procedure;

        procedure send_cmd(cmd : byte_t; payload : byte_array) is
        begin
            send(cmd & escape(payload));
        end procedure;

        impure function word_of(a : std_logic_vector) return natural is
        begin
            return to_integer(unsigned(a(3 downto 0)));
        end function;

        procedure set_address(a : std_logic_vector) is
        begin
            send_cmd(SET_ADDR, lsb_first(a, A_BYTES));
            curr_addr := a;
        end procedure;

        procedure wait_access(what : string) is
        begin
            for i in 1 to 1000 loop
                exit when acc_count /= count;
                wait until rising_edge(clk);
            end loop;
            assert acc_count = count + 1 report what & ": no access on the bus" severity failure;
            count := acc_count;
        end procedure;

        procedure check_access(is_write : boolean; locked : std_logic; what : string) is
        begin
            assert acc_write = is_write report what & ": wrong direction" severity failure;
            assert acc_address = curr_addr report what & ": address " & to_hstring(acc_address) &
                ", expected " & to_hstring(curr_addr) severity failure;
            if STROBE_WIDTH > 0 then
                assert acc_strobe = curr_strb report what & ": strobe " & to_hstring(acc_strobe) severity failure;
            end if;
            if MISC_WIDTH > 0 then
                assert acc_misc = curr_misc report what & ": misc " & to_hstring(acc_misc) severity failure;
            end if;
            assert acc_lock = locked report what & ": lock = " & std_logic'image(acc_lock) &
                ", expected " & std_logic'image(locked) severity failure;
        end procedure;

        procedure write_word(data : std_logic_vector; locked : boolean; what : string) is
            variable lck : std_logic := '0';
        begin
            if locked then
                send_cmd(WRITE_LOCK, lsb_first(data, W_BYTES));
                lck := '1';
            else
                send_cmd(WRITE, lsb_first(data, W_BYTES));
            end if;
            wait_access(what);
            check_access(true, lck, what);
            assert acc_data = data report what & ": data " & to_hstring(acc_data) &
                ", expected " & to_hstring(data) severity failure;
            if word_of(curr_addr) = ERROR_WORD then
                host_expect(clk, (0 => NACK), what & ", NACK");
            else
                ref(word_of(curr_addr)) := data;
                host_expect(clk, (0 => ACK), what & ", ACK");
            end if;
        end procedure;

        procedure read_word(locked : boolean; what : string) is
            variable lck      : std_logic := '0';
            variable expected : std_logic_vector(R_DATA_WIDTH - 1 downto 0);
            variable b        : byte_t;
        begin
            if locked then
                send((0 => READ_LOCK));
                lck := '1';
            else
                send((0 => READ));
            end if;
            wait_access(what);
            check_access(false, lck, what);
            if word_of(curr_addr) = ERROR_WORD then
                host_expect(clk, (0 => NACK), what & ", NACK");
                for i in 1 to R_BYTES loop -- the data bytes follow anyway
                    host_receive(clk, b, what & ", data after NACK");
                end loop;
            else
                expected := std_logic_vector(resize(unsigned(ref(word_of(curr_addr))), R_DATA_WIDTH));
                host_expect(clk, ACK & lsb_first(expected, R_BYTES), what);
            end if;
        end procedure;

        variable a          : std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
        variable d          : std_logic_vector(W_DATA_WIDTH - 1 downto 0);
    begin
        seed_random(SEED);
        wait_clocks(clk, 3);
        rst <= '0';
        wait_clocks(clk, 3);
        curr_addr := (others => '0');
        curr_strb := (others => '1');
        curr_misc := MISC_INIT;
        count     := 0;

        -- the host resets the core when it connects
        send((0 => RESET_SYMBOL));

        -- widths
        send((0 => READ_WIDTHS));
        host_expect(clk, byte_array'(x"1D", x"00", x"00", x"00") & lsb_first(W_DATA_WIDTH, 4) & lsb_first(R_DATA_WIDTH, 4) &
            lsb_first(ADDRESS_WIDTH, 4) & lsb_first(MISC_WIDTH, 4) & lsb_first(STROBE_WIDTH, 4), "widths");

        -- reset values: address 0, strobe all ones, MISC_INIT
        write_word(random_slv(W_DATA_WIDTH), false, "write after reset");
        read_word(false, "read after reset");

        -- random accesses
        for i in 1 to 40 loop
            if random_int(0, 2) = 0 then
                a := random_slv(ADDRESS_WIDTH);
                set_address(a);
            end if;
            if STROBE_WIDTH > 0 and random_int(0, 3) = 0 then
                curr_strb := random_slv(maximum(STROBE_WIDTH, 1))(STROBE_WIDTH - 1 downto 0);
                send_cmd(SET_STRB, lsb_first(curr_strb, bytes_of(maximum(STROBE_WIDTH, 1))));
            end if;
            if MISC_WIDTH > 0 and random_int(0, 3) = 0 then
                curr_misc := random_slv(MISC_LEN);
                send_cmd(SET_MISC, lsb_first(curr_misc, bytes_of(MISC_LEN)));
            end if;
            if random_int(0, 1) = 0 then
                write_word(random_slv(W_DATA_WIDTH), false, "random write " & integer'image(i));
            else
                read_word(false, "random read " & integer'image(i));
            end if;
        end loop;

        -- data bytes that need escaping
        set_address(std_logic_vector(to_unsigned(3, ADDRESS_WIDTH)));
        for i in 0 to W_BYTES - 1 loop
            if i mod 2 = 0 then
                d(minimum(8 * i + 7, W_DATA_WIDTH - 1) downto 8 * i) := ESCAPE_SYMBOL(minimum(7, W_DATA_WIDTH - 1 - 8 * i) downto 0);
            else
                d(minimum(8 * i + 7, W_DATA_WIDTH - 1) downto 8 * i) := RESET_SYMBOL(minimum(7, W_DATA_WIDTH - 1 - 8 * i) downto 0);
            end if;
        end loop;
        write_word(d, false, "escaped write");
        read_word(false, "escaped read");

        -- errors
        set_address(std_logic_vector(to_unsigned(ERROR_WORD, ADDRESS_WIDTH)));
        write_word(random_slv(W_DATA_WIDTH), false, "write error");
        read_word(false, "read error");

        -- read-modify-write with lock
        set_address(std_logic_vector(to_unsigned(7, ADDRESS_WIDTH)));
        read_word(true, "locked read");
        write_word(random_slv(W_DATA_WIDTH), true, "locked write");
        write_word(random_slv(W_DATA_WIDTH), false, "write after locked");
        assert lock = '0' report "lock after an unlocked write" severity failure;

        -- reset in the middle of a write: no access
        send(WRITE & escape(lsb_first(random_slv(W_DATA_WIDTH), W_BYTES)(0 to W_BYTES - 2)));
        send((0 => RESET_SYMBOL));
        wait_clocks(clk, 20);
        assert acc_count = count report "access after a reset in the middle of a write" severity failure;
        host_expect_nothing(clk, 20, "reset in the middle of a write");
        curr_addr := (others => '0');
        curr_strb := (others => '1');
        curr_misc := MISC_INIT;
        read_word(false, "read after reset");

        -- reset in the middle of set address
        if A_BYTES > 1 then
            set_address(std_logic_vector(to_unsigned(9, ADDRESS_WIDTH)));
            send(SET_ADDR & escape(lsb_first(random_slv(ADDRESS_WIDTH), A_BYTES)(0 to A_BYTES - 2)));
            send((0 => RESET_SYMBOL));
            curr_addr := (others => '0');
            write_word(random_slv(W_DATA_WIDTH), false, "write after reset in set address");
        end if;

        host_expect_nothing(clk, 50, "end");
        report "tb_BusAccess: all tests passed (ASYNC_RESET = " & boolean'image(ASYNC_RESET) &
               ", widths A/R/W/S/M = " & integer'image(ADDRESS_WIDTH) & "/" & integer'image(R_DATA_WIDTH) & "/" &
               integer'image(W_DATA_WIDTH) & "/" & integer'image(STROBE_WIDTH) & "/" & integer'image(MISC_WIDTH) &
               ", SEED = " & integer'image(SEED) & ", gap " & integer'image(MAX_GAP) &
               ", delay " & integer'image(MAX_DELAY) & ")";
        done <= true;
        wait;
    end process;
end architecture test;
