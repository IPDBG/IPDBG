-- SPDX-FileCopyrightText: The IPDBG authors
-- SPDX-License-Identifier: CERN-OHL-W-2.0

-- Self-checking testbench for LogicAnalyserTop with the host model of
-- ipdbg_test_pkg. The probe is a counter that counts every RUN samples, so
-- each capture must contain consecutive values. Checks id, sizes, features,
-- trigger on a value, on a value after a value, on an edge, the manual
-- trigger, the delay (the trigger sample is sample number `delay`), and with
-- RUN_LENGTH_COMPRESSION the run lengths. Reports "tb_LogicAnalyser: all
-- tests passed".

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ipdbg_interface_pkg.all;
use work.ipdbg_test_pkg.all;

entity tb_LogicAnalyser is
    generic(
        ASYNC_RESET            : boolean  := true;
        DATA_WIDTH             : positive := 12; -- at most 30
        ADDR_WIDTH             : positive := 5;
        RUN_LENGTH_COMPRESSION : natural  := 0;
        RUN                    : positive := 1; -- the probe changes every RUN samples
        SAMPLE_EVERY           : positive := 1; -- sample_enable every SAMPLE_EVERY clocks
        SEED                   : positive := 1;
        MAX_GAP                : natural  := 3;
        MAX_DELAY              : natural  := 4;
        READY_AFTER_VALID      : boolean  := false -- uplink_ready only after uplink_valid
    );
end entity tb_LogicAnalyser;

architecture test of tb_LogicAnalyser is
    constant GET_ID           : byte_t := x"BB";
    constant GET_SIZES        : byte_t := x"AA";
    constant ACTIVATE_TRIGGER : byte_t := x"FE";
    constant FIRE_TRIGGER     : byte_t := x"00";
    constant CONFIG_TRIGGER   : byte_t := x"F0";
    constant SELECT_CURR      : byte_t := x"F1";
    constant SET_MASK_CURR    : byte_t := x"F3";
    constant SET_VALUE_CURR   : byte_t := x"F7";
    constant SELECT_LAST      : byte_t := x"F9";
    constant SET_MASK_LAST    : byte_t := x"FB";
    constant SET_VALUE_LAST   : byte_t := x"FF";
    constant SELECT_EDGE      : byte_t := x"F5";
    constant SET_EDGE_MASK    : byte_t := x"F6";
    constant LOGIC_ANALYSER   : byte_t := x"0F";
    constant SET_DELAY        : byte_t := x"1F";
    constant GET_FEATURES     : byte_t := x"10";
    constant GET_RLC_WIDTH    : byte_t := x"60";

    constant RLC     : natural  := RUN_LENGTH_COMPRESSION;
    constant D_BYTES : positive := bytes_of(DATA_WIDTH);
    constant A_BYTES : positive := bytes_of(ADDR_WIDTH);
    constant S_BYTES : positive := bytes_of(DATA_WIDTH + RLC);
    constant SAMPLES : positive := 2 ** ADDR_WIDTH;

    subtype probe_t is std_logic_vector(DATA_WIDTH - 1 downto 0);
    constant ZEROS : probe_t := (others => '0');
    constant ONES  : probe_t := (others => '1');

    -- a capture: the probe value of each sample
    type value_array is array (0 to SAMPLES - 1) of natural;

    signal clk           : std_logic := '0';
    signal rst           : std_logic := '1';
    signal done          : boolean   := false;

    signal dn_valid      : std_logic := '0';
    signal dn_data       : byte_t;
    signal up_ready      : std_logic;
    signal dn_lines      : ipdbg_dn_lines;
    signal up_lines      : ipdbg_up_lines;

    signal sample_enable : std_logic := '0';
    signal probe         : probe_t   := (others => '0');
begin
    clk <= not clk after 5 ns when not done;

    dn_lines <= (uplink_ready => up_ready, dnlink_valid => dn_valid, dnlink_data => dn_data);
    host_sink(clk, up_lines.uplink_valid, up_lines.uplink_data, up_ready, MAX_DELAY, READY_AFTER_VALID);

    dut : entity work.LogicAnalyserTop
        generic map(
            ADDR_WIDTH             => ADDR_WIDTH,
            ASYNC_RESET            => ASYNC_RESET,
            USE_EXT_TRIGGER        => false,
            RUN_LENGTH_COMPRESSION => RLC
        )
        port map(
            clk           => clk,
            rst           => rst,
            ce            => '1',
            dn_lines      => dn_lines,
            up_lines      => up_lines,
            sample_enable => sample_enable,
            ext_trigger   => '0',
            probe         => probe
        );

    -- the probe counts every RUN samples
    signals : process (clk)
        variable cnt  : natural := 0;
        variable runs : natural := 0;
    begin
        if rising_edge(clk) then
            if sample_enable = '1' then
                runs := (runs + 1) mod RUN;
                if runs = 0 then
                    probe <= std_logic_vector(unsigned(probe) + 1);
                end if;
            end if;
            cnt := (cnt + 1) mod SAMPLE_EVERY;
            sample_enable <= '1' when cnt = 0 else '0';
        end if;
    end process;

    stimulus : process
        procedure send(bytes : byte_array) is
        begin
            host_send(clk, dn_valid, dn_data, up_lines.dnlink_ready, bytes, MAX_GAP);
        end procedure;

        procedure configure(sel, cmd : byte_t; value : probe_t) is
        begin
            send(byte_array'(CONFIG_TRIGGER, sel, cmd) & escape(msb_first(value, D_BYTES)));
        end procedure;

        procedure set_trigger(mask_curr, value_curr, mask_last, value_last, mask_edge : probe_t) is
        begin
            configure(SELECT_CURR, SET_MASK_CURR, mask_curr);
            configure(SELECT_CURR, SET_VALUE_CURR, value_curr);
            configure(SELECT_LAST, SET_MASK_LAST, mask_last);
            configure(SELECT_LAST, SET_VALUE_LAST, value_last);
            configure(SELECT_EDGE, SET_EDGE_MASK, mask_edge);
        end procedure;

        procedure program_delay(delay : natural) is
        begin
            send(byte_array'(LOGIC_ANALYSER, SET_DELAY) & escape(msb_first(std_logic_vector(to_unsigned(delay, ADDR_WIDTH)), A_BYTES)));
        end procedure;

        -- receives a capture, checks that the values count up
        procedure receive_capture(variable values : out value_array; what : string) is
            variable bytes : byte_array(0 to S_BYTES - 1);
            variable word  : std_logic_vector(8 * S_BYTES - 1 downto 0);
            variable v, r        : natural;
            variable group_len   : natural := 0;
            variable first_group : boolean := true;
        begin
            for i in 0 to SAMPLES - 1 loop
                for j in bytes'range loop
                    host_receive(clk, bytes(j), what & ", sample " & integer'image(i), 50000);
                end loop;
                -- least significant byte first, the unused bits of the last byte are undefined
                for j in bytes'range loop
                    word(8 * j + 7 downto 8 * j) := bytes(j);
                end loop;
                v := to_integer(unsigned(word(DATA_WIDTH + RLC - 1 downto RLC)));
                r := 1;
                if RLC > 0 then
                    r := to_integer(unsigned(word(RLC - 1 downto 0))) + 1;
                end if;
                values(i) := v;
                -- RUN samples per value; a run may be split into several
                -- compressed samples, e.g. at the trigger
                if i = 0 or v /= values(i - 1) then
                    if i > 0 then
                        assert v = (values(i - 1) + 1) mod 2 ** DATA_WIDTH
                            report what & ": sample " & integer'image(i) & " is " & integer'image(v) &
                                   " after " & integer'image(values(i - 1)) severity failure;
                        assert first_group or group_len = RUN
                            report what & ": " & integer'image(group_len) & " samples of value " &
                                   integer'image(values(i - 1)) severity failure;
                        first_group := false;
                    end if;
                    group_len := r;
                else
                    group_len := group_len + r;
                end if;
                assert group_len <= RUN
                    report what & ": " & integer'image(group_len) & " samples of value " & integer'image(v) severity failure;
            end loop;
            host_expect_nothing(clk, 100, what & ", after the capture");
        end procedure;

        -- a value the probe reaches soon, but after the trigger is configured
        -- and armed; with the given low byte if low_byte >= 0
        impure function soon(low_byte : integer := -1) return natural is
            constant MODULUS : positive := 2 ** minimum(DATA_WIDTH, 8);
            variable v       : natural;
        begin
            v := to_integer(unsigned(probe)) + 2 * SAMPLES + 2000 / (RUN * SAMPLE_EVERY) + random_int(0, SAMPLES);
            if low_byte >= 0 then
                while v mod MODULUS /= low_byte mod MODULUS loop
                    v := v + 1;
                end loop;
            end if;
            return v mod 2 ** DATA_WIDTH;
        end function;

        procedure capture_on_value(value : natural; delay : natural; what : string) is
            variable values : value_array;
            constant p : probe_t := std_logic_vector(to_unsigned(value, DATA_WIDTH));
        begin
            set_trigger(ONES, p, ZEROS, ZEROS, ZEROS);
            program_delay(delay);
            send((0 => ACTIVATE_TRIGGER));
            receive_capture(values, what);
            assert values(delay) = value
                report what & ": sample " & integer'image(delay) & " is " & integer'image(values(delay)) &
                       ", expected " & integer'image(value) severity failure;
        end procedure;

        variable values : value_array;
        variable features     : std_logic_vector(31 downto 0);
        variable value        : natural;
    begin
        seed_random(SEED);
        wait_clocks(clk, 3);
        rst <= '0';
        wait_clocks(clk, 3);

        send((0 => RESET_SYMBOL));
        send((0 => GET_ID));
        if RLC = 0 then
            host_expect(clk, (x"49", x"44", x"42", x"47"), "id"); -- IDBG
        else
            host_expect(clk, (x"69", x"64", x"62", x"67"), "id"); -- idbg
        end if;
        send((0 => GET_SIZES));
        host_expect(clk, lsb_first(DATA_WIDTH, 4) & lsb_first(ADDR_WIDTH, 4), "sizes");
        send((0 => GET_FEATURES));
        features := (others => '0');
        features(1) := '1' when RLC > 0 else '0';
        host_expect(clk, lsb_first(features, 4), "features");
        if RLC > 0 then
            send((0 => GET_RLC_WIDTH));
            host_expect(clk, lsb_first(RLC, 1), "rlc width");
        end if;

        -- value, with delays 0, 1, half, max; the delay counts samples, with
        -- run length compression compressed samples
        if RLC = 0 and RUN = 1 then
            capture_on_value(soon, 0, "trigger on value, delay 0");
            capture_on_value(soon, 1, "trigger on value, delay 1");
            capture_on_value(soon, SAMPLES / 2, "trigger on value, delay half");
            capture_on_value(soon, SAMPLES - 1, "trigger on value, delay max");
            -- escaped bytes in value and delay
            capture_on_value(soon(16#55#), 16#55# mod SAMPLES, "trigger on 0x55");
            capture_on_value(soon(16#EE#), 16#EE# mod SAMPLES, "trigger on 0xEE");
        end if;

        -- value after a value: the trigger fires with the first sample of the run
        value := soon;
        if value = 0 then
            value := 1;
        end if;
        set_trigger(ONES, std_logic_vector(to_unsigned(value, DATA_WIDTH)),
            ONES, std_logic_vector(to_unsigned(value - 1, DATA_WIDTH)), ZEROS);
        program_delay(SAMPLES / 4);
        send((0 => ACTIVATE_TRIGGER));
        receive_capture(values, "trigger on value after value");
        assert values(SAMPLES / 4) = value and (RLC > 0 or RUN = 1 or values(SAMPLES / 4 - 1) = value - 1)
            report "trigger on value after value: samples " & integer'image(values(SAMPLES / 4 - 1)) & ", " &
                   integer'image(values(SAMPLES / 4)) & ", expected " & integer'image(value) severity failure;

        -- rising edge of bit 0
        set_trigger(ZEROS, ZEROS, ZEROS, ZEROS, ZEROS);
        configure(SELECT_CURR, SET_MASK_CURR, (0 => '1', others => '0'));
        configure(SELECT_CURR, SET_VALUE_CURR, (0 => '1', others => '0'));
        configure(SELECT_EDGE, SET_EDGE_MASK, (0 => '1', others => '0'));
        program_delay(SAMPLES / 2);
        send((0 => ACTIVATE_TRIGGER));
        receive_capture(values, "trigger on edge");
        assert values(SAMPLES / 2) mod 2 = 1 and values(SAMPLES / 2 - 1) mod 2 = 0
            report "trigger on edge: samples " & integer'image(values(SAMPLES / 2 - 1)) & ", " &
                   integer'image(values(SAMPLES / 2)) severity failure;

        -- manual trigger: never triggers on its own
        -- (bit 0 has to be '1' before and after a change)
        set_trigger(ZEROS, ZEROS, ZEROS, ZEROS, ZEROS);
        configure(SELECT_CURR, SET_MASK_CURR, (0 => '1', others => '0'));
        configure(SELECT_CURR, SET_VALUE_CURR, (0 => '1', others => '0'));
        configure(SELECT_LAST, SET_MASK_LAST, (0 => '1', others => '0'));
        configure(SELECT_LAST, SET_VALUE_LAST, (0 => '1', others => '0'));
        configure(SELECT_EDGE, SET_EDGE_MASK, (0 => '1', others => '0'));
        program_delay(3);
        send((0 => ACTIVATE_TRIGGER));
        host_expect_nothing(clk, 3 * SAMPLES * SAMPLE_EVERY * RUN, "before the manual trigger");
        send((0 => FIRE_TRIGGER));
        receive_capture(values, "manual trigger");

        -- reset by the host while armed: nothing is sent
        program_delay(1);
        send((0 => ACTIVATE_TRIGGER));
        send((0 => RESET_SYMBOL));
        send((0 => FIRE_TRIGGER));
        host_expect_nothing(clk, 3 * SAMPLES * SAMPLE_EVERY * RUN, "after a reset while armed");
        send((0 => GET_SIZES));
        host_expect(clk, lsb_first(DATA_WIDTH, 4) & lsb_first(ADDR_WIDTH, 4), "sizes after reset");

        report "tb_LogicAnalyser: all tests passed (ASYNC_RESET = " & boolean'image(ASYNC_RESET) &
               ", DATA_WIDTH = " & integer'image(DATA_WIDTH) & ", ADDR_WIDTH = " & integer'image(ADDR_WIDTH) &
               ", RUN_LENGTH_COMPRESSION = " & integer'image(RLC) & ", RUN = " & integer'image(RUN) &
               ", SAMPLE_EVERY = " & integer'image(SAMPLE_EVERY) & ", SEED = " & integer'image(SEED) & ")";
        done <= true;
        wait;
    end process;
end architecture test;
