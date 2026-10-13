-- SPDX-FileCopyrightText: The IPDBG authors
-- SPDX-License-Identifier: CERN-OHL-W-2.0

-- Self-checking testbench for IpdbgEscaping: random escaped data reaches the
-- core unchanged, RESET_SYMBOL resets the core, an escaped RESET_SYMBOL or
-- ESCAPE_SYMBOL is data. Reports "tb_IpdbgEscaping: all tests passed".

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ipdbg_interface_pkg.all;
use work.ipdbg_test_pkg.all;

entity tb_IpdbgEscaping is
    generic(
        ASYNC_RESET : boolean  := true;
        SEED        : positive := 1;
        MAX_GAP     : natural  := 3
    );
end entity tb_IpdbgEscaping;

architecture test of tb_IpdbgEscaping is
    signal clk          : std_logic := '0';
    signal rst          : std_logic := '1';
    signal done         : boolean   := false;
    signal dn_valid     : std_logic := '0';
    signal dn_data      : byte_t;
    signal dn_lines     : ipdbg_dn_lines;
    signal dn_lines_out : ipdbg_dn_lines;
    signal up_lines_in  : ipdbg_up_lines;
    signal up_lines_out : ipdbg_up_lines;
    signal reset        : std_logic;

    shared variable delivered : byte_queue;
    signal resets       : natural := 0;
begin
    clk <= not clk after 5 ns when not done;

    dn_lines <= (uplink_ready => '1', dnlink_valid => dn_valid, dnlink_data => dn_data);
    up_lines_in <= (dnlink_ready => '1', uplink_valid => '0', uplink_data => x"00");

    dut : entity work.IpdbgEscaping
        generic map(
            ASYNC_RESET  => ASYNC_RESET,
            DO_HANDSHAKE => false
        )
        port map(
            clk          => clk,
            rst          => rst,
            ce           => '1',
            dn_lines_in  => dn_lines,
            dn_lines_out => dn_lines_out,
            up_lines_out => up_lines_out,
            up_lines_in  => up_lines_in,
            reset        => reset
        );

    monitor : process (clk) begin
        if rising_edge(clk) and rst = '0' then
            if dn_lines_out.dnlink_valid = '1' then
                delivered.push(dn_lines_out.dnlink_data);
            end if;
            if reset = '1' then
                resets <= resets + 1;
            end if;
        end if;
    end process;

    stimulus : process
        procedure send(bytes : byte_array) is
        begin
            host_send(clk, dn_valid, dn_data, up_lines_out.dnlink_ready, bytes, MAX_GAP);
            wait_clocks(clk, 3);
        end procedure;

        procedure expect_delivered(bytes : byte_array; what : string) is
        begin
            assert delivered.count = bytes'length
                report what & ": " & integer'image(delivered.count) & " bytes delivered, expected " &
                       integer'image(bytes'length)
                severity failure;
            for i in bytes'range loop
                assert delivered.pop = bytes(i)
                    report what & ": byte " & integer'image(i) & " wrong" severity failure;
            end loop;
        end procedure;

        variable data       : byte_array(0 to 499);
        variable resets_old : natural;
    begin
        seed_random(SEED);
        wait_clocks(clk, 3);
        rst <= '0';
        wait_clocks(clk, 3);
        delivered.clear;
        -- reset follows rst, one clock longer
        assert reset = '0' report "reset stays active after rst" severity failure;
        resets_old := resets;

        -- random data, every value at least once
        for i in data'range loop
            if i < 256 then
                data(i) := random_slv(8);
            else
                data(i) := (others => '0');
            end if;
        end loop;
        for i in 0 to 255 loop
            data(i + 244) := std_logic_vector(to_unsigned(i, 8));
        end loop;
        send(escape(data));
        expect_delivered(data, "escaped data");
        assert resets = resets_old report "escaped data: reset" severity failure;

        -- reset symbol
        send((x"12", RESET_SYMBOL, x"34"));
        expect_delivered((x"12", x"34"), "reset symbol");
        assert resets = resets_old + 1 report "reset symbol: no reset" severity failure;

        -- escaped symbols are data
        send((ESCAPE_SYMBOL, RESET_SYMBOL, ESCAPE_SYMBOL, ESCAPE_SYMBOL));
        expect_delivered((RESET_SYMBOL, ESCAPE_SYMBOL), "escaped symbols");
        assert resets = resets_old + 1 report "escaped reset symbol: reset" severity failure;

        -- reset during data, data after the reset
        resets_old := resets;
        send((RESET_SYMBOL, RESET_SYMBOL, x"A5"));
        expect_delivered((0 => x"A5"), "two resets");
        assert resets = resets_old + 2 report "two resets: " & integer'image(resets - resets_old) severity failure;

        -- upstream passes through
        assert up_lines_out = up_lines_in report "up_lines changed" severity failure;
        assert dn_lines_out.uplink_ready = '1' report "uplink_ready changed" severity failure;

        report "tb_IpdbgEscaping: all tests passed (ASYNC_RESET = " & boolean'image(ASYNC_RESET) &
               ", SEED = " & integer'image(SEED) & ")";
        done <= true;
        wait;
    end process;
end architecture test;
