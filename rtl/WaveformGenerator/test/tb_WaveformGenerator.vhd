-- SPDX-FileCopyrightText: The IPDBG authors
-- SPDX-License-Identifier: CERN-OHL-W-2.0

-- Self-checking testbench for WaveformGeneratorTop with the host model of
-- ipdbg_test_pkg: sizes, status, number of samples, writing samples (0xFA
-- every 64 bytes, 0xFB at the end), one shot, start and stop, and with
-- DOUBLE_BUFFER the change to a new waveform while running. The output is
-- compared sample by sample. Reports "tb_WaveformGenerator: all tests
-- passed".

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ipdbg_interface_pkg.all;
use work.ipdbg_test_pkg.all;

entity tb_WaveformGenerator is
    generic(
        ASYNC_RESET   : boolean  := true;
        DATA_WIDTH    : positive := 12;
        ADDR_WIDTH    : positive := 6;
        DOUBLE_BUFFER : boolean  := false;
        SAMPLE_EVERY  : positive := 1;  -- sample_enable every SAMPLE_EVERY clocks
        SEED          : positive := 1;
        MIN_GAP       : natural  := 1;
        MAX_GAP       : natural  := 3;
        MAX_DELAY     : natural  := 4
    );
end entity tb_WaveformGenerator;

architecture test of tb_WaveformGenerator is
    constant START         : byte_t := x"F0";
    constant STOP          : byte_t := x"F1";
    constant RETURN_SIZES  : byte_t := x"F2";
    constant WRITE_SAMPLES : byte_t := x"F3";
    constant SET_SAMPLES   : byte_t := x"F4";
    constant RETURN_STATUS : byte_t := x"F5";
    constant ONE_SHOT      : byte_t := x"F6";
    constant ALIVE         : byte_t := x"FA";
    constant WRITE_DONE    : byte_t := x"FB";

    constant D_BYTES : positive := bytes_of(DATA_WIDTH);
    constant A_BYTES : positive := bytes_of(ADDR_WIDTH);
    constant MAX_SAMPLES : positive := 2 ** ADDR_WIDTH;

    type sample_array is array (natural range <>) of std_logic_vector(DATA_WIDTH - 1 downto 0);

    signal clk           : std_logic := '0';
    signal rst           : std_logic := '1';
    signal done          : boolean   := false;

    signal dn_valid      : std_logic := '0';
    signal dn_data       : byte_t;
    signal up_ready      : std_logic;
    signal dn_lines      : ipdbg_dn_lines;
    signal up_lines      : ipdbg_up_lines;

    signal data_out      : std_logic_vector(DATA_WIDTH - 1 downto 0);
    signal first_sample  : std_logic;
    signal sample_enable : std_logic := '0';
    signal sample_en_d   : std_logic := '0'; -- data_out changed in this clock
    signal output_active : std_logic;
begin
    clk <= not clk after 5 ns when not done;

    dn_lines <= (uplink_ready => up_ready, dnlink_valid => dn_valid, dnlink_data => dn_data);
    host_sink(clk, up_lines.uplink_valid, up_lines.uplink_data, up_ready, MAX_DELAY);

    dut : entity work.WaveformGeneratorTop
        generic map(
            ADDR_WIDTH    => ADDR_WIDTH,
            ASYNC_RESET   => ASYNC_RESET,
            DOUBLE_BUFFER => DOUBLE_BUFFER,
            SYNC_MASTER   => true
        )
        port map(
            clk           => clk,
            rst           => rst,
            ce            => '1',
            dn_lines      => dn_lines,
            up_lines      => up_lines,
            data_out      => data_out,
            first_sample  => first_sample,
            sample_enable => sample_enable,
            output_active => output_active,
            one_shot      => '0',
            sync_out      => open,
            sync_in       => '0'
        );

    enable : process (clk)
        variable cnt : natural := 0;
    begin
        if rising_edge(clk) then
            sample_en_d <= sample_enable;
            cnt := (cnt + 1) mod SAMPLE_EVERY;
            sample_enable <= '1' when cnt = 0 else '0';
        end if;
    end process;

    stimulus : process
        procedure send(bytes : byte_array) is
        begin
            host_send(clk, dn_valid, dn_data, up_lines.dnlink_ready, bytes, MIN_GAP, MAX_GAP);
        end procedure;

        procedure expect_status(enabled : std_logic; what : string) is
            variable status : byte_t := x"00";
        begin
            status(0) := enabled;
            status(1) := '1' when DOUBLE_BUFFER else '0';
            send((0 => RETURN_STATUS));
            host_expect(clk, (0 => status), what);
        end procedure;

        procedure write_waveform(samples : sample_array; what : string) is
            variable bytes  : byte_array(0 to samples'length * D_BYTES - 1);
            variable b      : byte_t;
            variable alives : natural := 0;
        begin
            send(SET_SAMPLES & escape(msb_first(std_logic_vector(to_unsigned(samples'length - 1, ADDR_WIDTH)), A_BYTES)));
            for i in samples'range loop
                bytes((i - samples'low) * D_BYTES to (i - samples'low + 1) * D_BYTES - 1) := msb_first(samples(i), D_BYTES);
            end loop;
            send(WRITE_SAMPLES & escape(bytes));
            loop
                host_receive(clk, b, what);
                exit when b = WRITE_DONE;
                assert b = ALIVE report what & ": " & to_hstring(b) & " instead of FA or FB" severity failure;
                alives := alives + 1;
            end loop;
            -- one 0xFA per 64 bytes, not with the last byte; may be dropped when the host is busy
            assert alives <= (bytes'length - 1) / 64
                report what & ": " & integer'image(alives) & " times FA for " & integer'image(bytes'length) & " bytes"
                severity failure;
            host_expect_nothing(clk, 20, what & ", after FB");
        end procedure;

        -- the next output sample: data_out etc. after a clock with sample_enable
        procedure next_output(variable d : out std_logic_vector; variable first, active : out std_logic) is
        begin
            loop
                wait until rising_edge(clk);
                exit when sample_en_d = '1';
            end loop;
            d      := data_out;
            first  := first_sample;
            active := output_active;
        end procedure;

        -- waits for the first sample, then checks periods times the waveform
        procedure expect_output(samples : sample_array; periods : positive; what : string) is
            variable d             : std_logic_vector(DATA_WIDTH - 1 downto 0);
            variable first, active : std_logic;
            variable n             : natural := 0;
        begin
            loop
                next_output(d, first, active);
                exit when active = '1' and first = '1';
                n := n + 1;
                assert n < 1000 report what & ": no first sample" severity failure;
            end loop;
            for p in 1 to periods loop
                for i in samples'range loop
                    if i /= samples'low or p /= 1 then
                        next_output(d, first, active);
                    end if;
                    assert active = '1' report what & ": output not active at sample " & integer'image(i) severity failure;
                    assert d = samples(i)
                        report what & ": period " & integer'image(p) & ", sample " & integer'image(i - samples'low) &
                               " is " & to_hstring(d) & ", expected " & to_hstring(samples(i))
                        severity failure;
                    assert (first = '1') = (i = samples'low)
                        report what & ": first_sample wrong at sample " & integer'image(i - samples'low) severity failure;
                end loop;
            end loop;
        end procedure;

        procedure random_samples(variable s : out sample_array) is
        begin
            for i in s'range loop
                s(i) := random_slv(DATA_WIDTH);
            end loop;
        end procedure;

        variable wave_a : sample_array(0 to MAX_SAMPLES - 1);
        variable wave_b : sample_array(0 to 4);
        variable d             : std_logic_vector(DATA_WIDTH - 1 downto 0);
        variable first, active : std_logic;
    begin
        seed_random(SEED);
        wait_clocks(clk, 3);
        rst <= '0';
        wait_clocks(clk, 3);
        assert output_active = '0' report "active after rst" severity failure;

        send((0 => RESET_SYMBOL));
        send((0 => RETURN_SIZES));
        host_expect(clk, lsb_first(DATA_WIDTH, 4) & lsb_first(ADDR_WIDTH, 4), "sizes");
        expect_status('0', "status after reset");

        -- the whole memory; with escaped bytes
        random_samples(wave_a);
        wave_a(1) := (others => '0');
        wave_a(1)(minimum(7, DATA_WIDTH - 1) downto 0) := ESCAPE_SYMBOL(minimum(7, DATA_WIDTH - 1) downto 0);
        wave_a(2) := (others => '0');
        wave_a(2)(minimum(7, DATA_WIDTH - 1) downto 0) := RESET_SYMBOL(minimum(7, DATA_WIDTH - 1) downto 0);
        write_waveform(wave_a, "write " & integer'image(MAX_SAMPLES) & " samples");

        -- one shot: once, then inactive
        send((0 => ONE_SHOT));
        expect_output(wave_a, 1, "one shot");
        next_output(d, first, active);
        assert active = '0' report "one shot: active after the last sample" severity failure;
        expect_status('0', "status after one shot");

        -- start, three periods, stop
        send((0 => START));
        expect_output(wave_a, 3, "start");
        expect_status('1', "status while running");
        send((0 => STOP));
        wait_clocks(clk, (MAX_SAMPLES + 10) * SAMPLE_EVERY);
        assert output_active = '0' report "active after stop" severity failure;
        expect_status('0', "status after stop");

        -- a short waveform
        random_samples(wave_b);
        write_waveform(wave_b, "write 5 samples");
        send((0 => START));
        expect_output(wave_b, 4, "short waveform");

        if DOUBLE_BUFFER then
            -- new waveform while running
            random_samples(wave_a);
            write_waveform(wave_a, "write while running");
            expect_output(wave_a, 2, "double buffer");
        end if;
        send((0 => STOP));
        wait_clocks(clk, (MAX_SAMPLES + 10) * SAMPLE_EVERY);
        assert output_active = '0' report "active after the second stop" severity failure;

        -- reset by the host in the middle of writing samples, then a full write
        send(SET_SAMPLES & escape(msb_first(std_logic_vector(to_unsigned(3, ADDR_WIDTH)), A_BYTES)));
        send(WRITE_SAMPLES & escape(msb_first(random_slv(DATA_WIDTH), D_BYTES)));
        send((0 => RESET_SYMBOL));
        host_expect_nothing(clk, 20, "reset while writing");
        random_samples(wave_b);
        write_waveform(wave_b, "write after reset");
        send((0 => ONE_SHOT));
        expect_output(wave_b, 1, "one shot after reset");

        host_expect_nothing(clk, 50, "end");
        report "tb_WaveformGenerator: all tests passed (ASYNC_RESET = " & boolean'image(ASYNC_RESET) &
               ", DATA_WIDTH = " & integer'image(DATA_WIDTH) & ", ADDR_WIDTH = " & integer'image(ADDR_WIDTH) &
               ", DOUBLE_BUFFER = " & boolean'image(DOUBLE_BUFFER) & ", SAMPLE_EVERY = " & integer'image(SAMPLE_EVERY) &
               ", SEED = " & integer'image(SEED) & ")";
        done <= true;
        wait;
    end process;
end architecture test;
