-- SPDX-FileCopyrightText: The IPDBG authors
-- SPDX-License-Identifier: CERN-OHL-W-2.0

-- Self-checking testbench for IoProbeTop with the host model of
-- ipdbg_test_pkg: widths and core type, setting the outputs (one update
-- pulse each), reading the inputs, outputs '0' after a reset by the host.
-- Reports "tb_IoProbe: all tests passed".

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ipdbg_interface_pkg.all;
use work.ipdbg_test_pkg.all;

entity tb_IoProbe is
    generic(
        ASYNC_RESET       : boolean  := true;
        INPUT_WIDTH       : positive := 20;
        OUTPUT_WIDTH      : positive := 12;
        SEED              : positive := 1;
        MAX_GAP           : natural  := 3;
        MAX_DELAY         : natural  := 4;
        READY_AFTER_VALID : boolean  := false    -- uplink_ready only after uplink_valid
    );
end entity tb_IoProbe;

architecture test of tb_IoProbe is
    constant READ_WIDTHS : byte_t := x"AB";
    constant WRITE       : byte_t := x"BF";
    constant READ        : byte_t := x"CF";
    constant SET_ADDR    : byte_t := x"D0";
    constant ACK         : byte_t := x"55";

    signal clk           : std_logic := '0';
    signal rst           : std_logic := '1';
    signal done          : boolean   := false;

    signal dn_valid      : std_logic := '0';
    signal dn_data       : byte_t;
    signal up_ready      : std_logic;
    signal dn_lines      : ipdbg_dn_lines;
    signal up_lines      : ipdbg_up_lines;

    signal inputs        : std_logic_vector(INPUT_WIDTH - 1 downto 0) := (others => '0');
    signal outputs       : std_logic_vector(OUTPUT_WIDTH - 1 downto 0);
    signal update        : std_logic;
    signal updates       : natural := 0;
begin
    clk <= not clk after 5 ns when not done;

    dn_lines <= (uplink_ready => up_ready, dnlink_valid => dn_valid, dnlink_data => dn_data);
    host_sink(clk, up_lines.uplink_valid, up_lines.uplink_data, up_ready, MAX_DELAY, READY_AFTER_VALID);

    dut : entity work.IoProbeTop
        generic map(
            ASYNC_RESET => ASYNC_RESET
        )
        port map(
            clk                  => clk,
            rst                  => rst,
            ce                   => '1',
            dn_lines             => dn_lines,
            up_lines             => up_lines,
            probe_inputs         => inputs,
            probe_outputs        => outputs,
            probe_outputs_update => update
        );

    count_updates : process (clk) begin
        if rising_edge(clk) and update = '1' then
            updates <= updates + 1;
        end if;
    end process;

    stimulus : process
        constant W_BYTES : positive := bytes_of(OUTPUT_WIDTH);
        constant R_BYTES : positive := bytes_of(INPUT_WIDTH);

        procedure send(bytes : byte_array) is
        begin
            host_send(clk, dn_valid, dn_data, up_lines.dnlink_ready, bytes, MAX_GAP);
        end procedure;

        procedure set_outputs(value : std_logic_vector; what : string) is
            constant updates_before : natural := updates;
        begin
            send(WRITE & escape(lsb_first(value, W_BYTES)));
            host_expect(clk, (0 => ACK), what);
            assert outputs = value report what & ": outputs " & to_hstring(outputs) &
                ", expected " & to_hstring(value) severity failure;
            assert updates = updates_before + 1 report what & ": " & integer'image(updates - updates_before) &
                " update pulses" severity failure;
        end procedure;

        procedure check_inputs(value : std_logic_vector; what : string) is
        begin
            inputs <= value;
            send((0 => READ));
            host_expect(clk, ACK & lsb_first(value, R_BYTES), what);
        end procedure;
    begin
        seed_random(SEED);
        wait_clocks(clk, 3);
        rst <= '0';
        wait_clocks(clk, 3);
        assert outputs = (outputs'range => '0') report "outputs after rst" severity failure;

        send((0 => RESET_SYMBOL));
        send((0 => READ_WIDTHS));
        host_expect(clk, byte_array'(x"1D", x"00", x"01", x"00") & lsb_first(OUTPUT_WIDTH, 4) &
            lsb_first(INPUT_WIDTH, 4) & lsb_first(0, 4) & lsb_first(0, 4) & lsb_first(0, 4), "widths");

        for i in 1 to 20 loop
            if random_int(0, 1) = 0 then
                set_outputs(random_slv(OUTPUT_WIDTH), "set outputs " & integer'image(i));
            else
                check_inputs(random_slv(INPUT_WIDTH), "read inputs " & integer'image(i));
            end if;
        end loop;
        set_outputs((OUTPUT_WIDTH - 1 downto 0 => '1'), "all outputs '1'");
        check_inputs((INPUT_WIDTH - 1 downto 0 => '1'), "all inputs '1'");

        -- no address: SET_ADDR is ignored
        send((0 => SET_ADDR));
        check_inputs(random_slv(INPUT_WIDTH), "read after SET_ADDR");

        -- reset by the host
        send((0 => RESET_SYMBOL));
        wait_clocks(clk, 3);
        assert outputs = (outputs'range => '0') report "outputs after reset by the host" severity failure;
        set_outputs(random_slv(OUTPUT_WIDTH), "set outputs after reset");

        host_expect_nothing(clk, 50, "end");
        report "tb_IoProbe: all tests passed (ASYNC_RESET = " & boolean'image(ASYNC_RESET) &
               ", SEED = " & integer'image(SEED) & ")";
        done <= true;
        wait;
    end process;
end architecture test;
