-- SPDX-FileCopyrightText: The IPDBG authors
-- SPDX-License-Identifier: CERN-OHL-W-2.0

-- Model of the host side of the core interface (ipdbg_dn_lines,
-- ipdbg_up_lines) for the testbenches of the cores. It behaves like JtagCdc:
--
--   host_send  downstream: valid is a pulse of one clock, sent only when
--              dnlink_ready = '1', with at least min_gap idle clocks between
--              two pulses (JtagCdc: 1) and a random number of up to max_gap
--              more.
--   host_sink  upstream: uplink_ready is a register. It drops in the clock
--              after the core's valid and comes back after 1 + 0..max_delay
--              clocks (random). A valid while uplink_ready = '0' is a lost
--              byte and stops the simulation. host_receive and host_expect
--              take the received bytes.
--
-- host_send and the expect procedures start and end right after a rising
-- edge of clk.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

package ipdbg_test_pkg is
    subtype byte_t is std_logic_vector(7 downto 0);
    type byte_array is array (natural range <>) of byte_t;

    -- bytes of the escaping layer (IpdbgEscaping)
    constant ESCAPE_SYMBOL : byte_t := x"55";
    constant RESET_SYMBOL  : byte_t := x"EE";

    -- puts ESCAPE_SYMBOL in front of each ESCAPE_SYMBOL and RESET_SYMBOL
    function escape(data : byte_array) return byte_array;
    -- value, zero extended to n bytes, least / most significant byte first
    function lsb_first(value : std_logic_vector; n : positive) return byte_array;
    function msb_first(value : std_logic_vector; n : positive) return byte_array;
    function lsb_first(value : natural; n : positive) return byte_array;
    function bytes_of(bits : positive) return positive; -- ceil(bits / 8)

    type random_t is protected
        procedure seed(s : positive);
        impure function int(lo, hi : integer) return integer; -- lo..hi
        impure function slv(bits : positive) return std_logic_vector;
    end protected random_t;

    type byte_queue is protected
        procedure push(b : byte_t);
        impure function pop return byte_t;
        impure function count return natural;
        procedure clear;
    end protected byte_queue;

    -- seeds the random generators of host_send, host_sink and random_*
    procedure seed_random(s : positive);
    -- random test data
    impure function random_int(lo, hi : integer) return integer;
    impure function random_slv(bits : positive) return std_logic_vector;
    -- number of received bytes not yet taken by host_receive
    impure function received_count return natural;

    procedure host_send(
        signal   clk     : in  std_logic;
        signal   valid   : out std_logic;
        signal   data    : out byte_t;
        signal   ready   : in  std_logic;
        constant bytes   : in  byte_array;
        constant min_gap : in  natural;
        constant max_gap : in  natural);

    -- runs forever, as a concurrent procedure call
    procedure host_sink(
        signal   clk       : in  std_logic;
        signal   valid     : in  std_logic;
        signal   data      : in  byte_t;
        signal   ready     : out std_logic;
        constant max_delay : in  natural);

    procedure host_receive(
        signal   clk     : in  std_logic;
        variable b       : out byte_t;
        constant what    : in  string;
        constant timeout : in  natural := 20000);

    procedure host_expect(
        signal   clk      : in std_logic;
        constant expected : in byte_array;
        constant what     : in string;
        constant timeout  : in natural := 20000);

    -- waits for cycles clocks, fails if the core sends a byte
    procedure host_expect_nothing(
        signal   clk    : in std_logic;
        constant cycles : in natural;
        constant what   : in string);

    procedure wait_clocks(signal clk : in std_logic; constant n : in natural);
end package ipdbg_test_pkg;

package body ipdbg_test_pkg is
    function escape(data : byte_array) return byte_array is
        variable res : byte_array(0 to 2 * data'length);
        variable n   : natural := 0;
    begin
        for i in data'range loop
            if data(i) = ESCAPE_SYMBOL or data(i) = RESET_SYMBOL then
                res(n) := ESCAPE_SYMBOL;
                n := n + 1;
            end if;
            res(n) := data(i);
            n := n + 1;
        end loop;
        return res(0 to n - 1);
    end function escape;

    function lsb_first(value : std_logic_vector; n : positive) return byte_array is
        variable v   : std_logic_vector(8 * n - 1 downto 0) := (others => '0');
        variable res : byte_array(0 to n - 1);
    begin
        assert value'length <= 8 * n report "lsb_first: value too wide" severity failure;
        v(value'length - 1 downto 0) := value;
        for i in 0 to n - 1 loop
            res(i) := v(8 * i + 7 downto 8 * i);
        end loop;
        return res;
    end function lsb_first;

    function msb_first(value : std_logic_vector; n : positive) return byte_array is
        constant lsb : byte_array(0 to n - 1) := lsb_first(value, n);
        variable res : byte_array(0 to n - 1);
    begin
        for i in 0 to n - 1 loop
            res(i) := lsb(n - 1 - i);
        end loop;
        return res;
    end function msb_first;

    function lsb_first(value : natural; n : positive) return byte_array is
    begin
        return lsb_first(std_logic_vector(to_unsigned(value, 8 * n)), n);
    end function lsb_first;

    function bytes_of(bits : positive) return positive is
    begin
        return (bits + 7) / 8;
    end function bytes_of;

    type random_t is protected body
        variable seed1 : positive := 1;
        variable seed2 : positive := 2;

        procedure seed(s : positive) is
        begin
            seed1 := s;
            seed2 := s mod 1000 + 7;
        end procedure seed;

        impure function int(lo, hi : integer) return integer is
            variable r : real;
        begin
            if hi <= lo then
                return lo;
            end if;
            uniform(seed1, seed2, r);
            return minimum(lo + integer(floor(r * real(hi - lo + 1))), hi);
        end function int;

        impure function slv(bits : positive) return std_logic_vector is
            variable res : std_logic_vector(bits - 1 downto 0);
        begin
            for i in res'range loop
                if int(0, 1) = 1 then
                    res(i) := '1';
                else
                    res(i) := '0';
                end if;
            end loop;
            return res;
        end function slv;
    end protected body random_t;

    type byte_queue is protected body
        constant SIZE : positive := 65536;
        type mem_t is array (0 to SIZE - 1) of byte_t;
        variable mem  : mem_t;
        variable head : natural := 0;
        variable tail : natural := 0;

        procedure push(b : byte_t) is
        begin
            assert tail - head < SIZE report "byte_queue: full" severity failure;
            mem(tail mod SIZE) := b;
            tail := tail + 1;
        end procedure push;

        impure function pop return byte_t is
            variable b : byte_t;
        begin
            assert tail > head report "byte_queue: empty" severity failure;
            b := mem(head mod SIZE);
            head := head + 1;
            return b;
        end function pop;

        impure function count return natural is
        begin
            return tail - head;
        end function count;

        procedure clear is
        begin
            head := tail;
        end procedure clear;
    end protected body byte_queue;

    shared variable received : byte_queue;
    shared variable send_rnd : random_t;
    shared variable sink_rnd : random_t;
    shared variable test_rnd : random_t;

    procedure seed_random(s : positive) is
    begin
        send_rnd.seed(s);
        sink_rnd.seed(s + 1);
        test_rnd.seed(s + 2);
    end procedure seed_random;

    impure function random_int(lo, hi : integer) return integer is
    begin
        return test_rnd.int(lo, hi);
    end function random_int;

    impure function random_slv(bits : positive) return std_logic_vector is
    begin
        return test_rnd.slv(bits);
    end function random_slv;

    impure function received_count return natural is
    begin
        return received.count;
    end function received_count;

    procedure wait_clocks(signal clk : in std_logic; constant n : in natural) is
    begin
        for i in 1 to n loop
            wait until rising_edge(clk);
        end loop;
    end procedure wait_clocks;

    procedure host_send(
        signal   clk     : in  std_logic;
        signal   valid   : out std_logic;
        signal   data    : out byte_t;
        signal   ready   : in  std_logic;
        constant bytes   : in  byte_array;
        constant min_gap : in  natural;
        constant max_gap : in  natural) is
    begin
        for i in bytes'range loop
            valid <= '0';
            data  <= (others => 'X');
            wait_clocks(clk, min_gap + send_rnd.int(0, max_gap));
            -- ready of the clock that just ended, like the register of JtagCdc
            while ready /= '1' loop
                wait until rising_edge(clk);
            end loop;
            valid <= '1';
            data  <= bytes(i);
            wait until rising_edge(clk);
        end loop;
        valid <= '0';
        data  <= (others => 'X');
    end procedure host_send;

    procedure host_sink(
        signal   clk       : in  std_logic;
        signal   valid     : in  std_logic;
        signal   data      : in  byte_t;
        signal   ready     : out std_logic;
        constant max_delay : in  natural) is
        variable rdy  : std_logic := '1';
        variable wait_cnt : natural := 0;
    begin
        ready <= '1';
        loop
            wait until rising_edge(clk);
            if valid = '1' then
                assert rdy = '1'
                    report "host: uplink_valid while uplink_ready = '0', byte " & to_hstring(data) & " lost"
                    severity failure;
                received.push(data);
                rdy := '0';
                wait_cnt := sink_rnd.int(0, max_delay);
            elsif rdy = '0' then
                if wait_cnt = 0 then
                    rdy := '1';
                else
                    wait_cnt := wait_cnt - 1;
                end if;
            end if;
            ready <= rdy;
        end loop;
    end procedure host_sink;

    procedure host_receive(
        signal   clk     : in  std_logic;
        variable b       : out byte_t;
        constant what    : in  string;
        constant timeout : in  natural := 20000) is
        variable cycles : natural := 0;
    begin
        while received.count = 0 loop
            wait until rising_edge(clk);
            cycles := cycles + 1;
            assert cycles < timeout report what & ": timeout, no byte from the core" severity failure;
        end loop;
        b := received.pop;
    end procedure host_receive;

    procedure host_expect(
        signal   clk      : in std_logic;
        constant expected : in byte_array;
        constant what     : in string;
        constant timeout  : in natural := 20000) is
        variable b : byte_t;
    begin
        for i in expected'range loop
            host_receive(clk, b, what, timeout);
            assert b = expected(i)
                report what & ": byte " & integer'image(i - expected'low) & " is " & to_hstring(b) &
                       ", expected " & to_hstring(expected(i))
                severity failure;
        end loop;
    end procedure host_expect;

    procedure host_expect_nothing(
        signal   clk    : in std_logic;
        constant cycles : in natural;
        constant what   : in string) is
    begin
        wait_clocks(clk, cycles);
        assert received.count = 0
            report what & ": unexpected byte " & to_hstring(received.pop) & " from the core"
            severity failure;
    end procedure host_expect_nothing;
end package body ipdbg_test_pkg;
