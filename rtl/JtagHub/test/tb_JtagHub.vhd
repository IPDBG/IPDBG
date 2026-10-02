-- SPDX-FileCopyrightText: The IPDBG authors
-- SPDX-License-Identifier: CERN-OHL-W-2.0

-- Self-checking testbench for JtagCdc, the part of the JtagHub that all hub
-- variants share. A model of the TAP shifts the data register like the
-- vendor's JTAG primitive; a model of the host behaves like the ipdbg server
-- of OpenOCD (reset, xoff/xon, polling).
--
--   channel 0: no flow control, the core takes every byte immediately
--   channel 1: flow control, a slow core: busy for 600 cycles after each byte
--   channel 2: flow control, a slow core behind IpdbgClockDomainCrossing
--              with its own clock, busy for 500 cycles after each byte
--   channel 3: no flow control, a core that sends bytes to the host
--
-- TDI_HAS_EXT_REGISTER = true models the TDI register outside the hub of the
-- Lattice JTAG primitives. Stops with an error on the first mismatch,
-- reports "tb_JtagHub: all tests passed" at the end.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ipdbg_interface_pkg.all;

entity tb_JtagHub is
    generic(
        TDI_HAS_EXT_REGISTER : boolean := false
    );
end entity tb_JtagHub;

architecture test of tb_JtagHub is
    constant T_CLK      : time := 10 ns;  -- clock of the hub and the cores
    constant T_CLK_FUNC : time := 13 ns;  -- clock of the core behind the clock domain crossing
    constant T_TCK      : time := 50 ns;  -- JTAG clock

    constant FLOW_CONTROL_ENABLE : std_logic_vector(6 downto 0) := "0000110";
    constant N_BYTES             : natural := 40; -- bytes per channel and direction

    constant DR_LENGTH : natural := 13;
    constant TOOL_HUB  : natural := 7;

    signal clk      : std_logic := '0';
    signal clk_func : std_logic := '0';
    signal rst      : std_logic := '1';
    signal done     : boolean   := false;

    -- TAP outputs
    signal drclk, capture, shift, update : std_logic := '0';
    signal tdi_pin, tdi, tdo             : std_logic := '0';

    type dn_array is array (0 to 6) of ipdbg_dn_lines;
    type up_array is array (0 to 6) of ipdbg_up_lines;
    signal dn : dn_array;
    signal up : up_array := (others => unused_up_lines);

    signal dn_func : ipdbg_dn_lines;
    signal up_func : ipdbg_up_lines;

    -- bytes of the test: channel c, byte i
    function test_byte(c, i : natural) return std_logic_vector is begin
        return std_logic_vector(to_unsigned((c * 64 + i * 7 + 3) mod 256, 8));
    end function;

    type counts_t is array (0 to 6) of natural;
    signal received_by_core : counts_t := (others => 0); -- bytes from the host, checked by the cores
    signal sent_by_core     : natural  := 0;             -- bytes to the host, channel 3
begin
    clk      <= not clk after T_CLK / 2 when not done;
    clk_func <= not clk_func after T_CLK_FUNC / 2 when not done;

    -- TDI register outside the hub (Lattice JTAG primitives)
    ext_reg : if TDI_HAS_EXT_REGISTER generate
        process (drclk) begin
            if rising_edge(drclk) then
                tdi <= tdi_pin;
            end if;
        end process;
    end generate;
    no_ext_reg : if not TDI_HAS_EXT_REGISTER generate
        tdi <= tdi_pin;
    end generate;

    dut : entity work.JtagCdc
        generic map(
            MFF_LENGTH           => 3,
            FLOW_CONTROL_ENABLE  => FLOW_CONTROL_ENABLE,
            TDI_HAS_EXT_REGISTER => TDI_HAS_EXT_REGISTER
        )
        port map(
            clk => clk, ce => '1',
            dn_lines_0 => dn(0), dn_lines_1 => dn(1), dn_lines_2 => dn(2), dn_lines_3 => dn(3),
            dn_lines_4 => dn(4), dn_lines_5 => dn(5), dn_lines_6 => dn(6),
            up_lines_0 => up(0), up_lines_1 => up(1), up_lines_2 => up(2), up_lines_3 => up(3),
            up_lines_4 => up(4), up_lines_5 => up(5), up_lines_6 => up(6),
            DRCLK => drclk, USER => '1', UPDATE => update, CAPTURE => capture, SHIFT => shift,
            TDI => tdi, TDO => tdo
        );

    -- channel 0: takes every byte immediately
    core0 : process (clk) begin
        if rising_edge(clk) then
            if dn(0).dnlink_valid = '1' then
                assert dn(0).dnlink_data = test_byte(0, received_by_core(0))
                    report "channel 0: byte " & integer'image(received_by_core(0)) & " wrong" severity failure;
                received_by_core(0) <= received_by_core(0) + 1;
            end if;
        end if;
    end process;
    up(0) <= unused_up_lines;

    -- channel 1: busy for 600 cycles after each byte
    core1 : process (clk)
        variable busy : natural := 0;
    begin
        if rising_edge(clk) then
            if busy > 0 then
                busy := busy - 1;
            end if;
            if dn(1).dnlink_valid = '1' then
                assert up(1).dnlink_ready = '1' report "channel 1: byte while not ready" severity failure;
                assert dn(1).dnlink_data = test_byte(1, received_by_core(1))
                    report "channel 1: byte " & integer'image(received_by_core(1)) & " wrong" severity failure;
                received_by_core(1) <= received_by_core(1) + 1;
                busy := 600;
            end if;
            up(1).dnlink_ready <= '1' when busy = 0 else '0';
        end if;
    end process;
    up(1).uplink_valid <= '0';
    up(1).uplink_data  <= (others => '-');

    -- channel 2: a slow core behind the clock domain crossing
    cdc : entity work.IpdbgClockDomainCrossing
        generic map(ASYNC_RESET => false, MFF_LENGTH => 3)
        port map(
            clk_func => clk_func, rst_func => rst, ce_func => '1',
            clk_host => clk, rst_host => rst, ce_host => '1',
            dn_lines_host => dn(2), up_lines_host => up(2),
            dn_lines_func => dn_func, up_lines_func => up_func
        );
    core2 : process (clk_func)
        variable busy : natural := 0;
    begin
        if rising_edge(clk_func) then
            if busy > 0 then
                busy := busy - 1;
            end if;
            if dn_func.dnlink_valid = '1' then
                assert up_func.dnlink_ready = '1' report "channel 2: byte while not ready" severity failure;
                assert dn_func.dnlink_data = test_byte(2, received_by_core(2))
                    report "channel 2: byte " & integer'image(received_by_core(2)) & " wrong" severity failure;
                received_by_core(2) <= received_by_core(2) + 1;
                busy := 500;
            end if;
            up_func.dnlink_ready <= '1' when busy = 0 else '0';
        end if;
    end process;
    up_func.uplink_valid <= '0';
    up_func.uplink_data  <= (others => '-');

    -- channel 3: sends N_BYTES bytes to the host
    core3 : process (clk) begin
        if rising_edge(clk) then
            if rst = '1' then
                up(3).uplink_valid <= '0';
            else
                if up(3).uplink_valid = '1' and dn(3).uplink_ready = '1' then
                    sent_by_core <= sent_by_core + 1;
                    up(3).uplink_valid <= '0';
                elsif sent_by_core < N_BYTES then
                    up(3).uplink_valid <= '1';
                    up(3).uplink_data  <= test_byte(3, sent_by_core);
                end if;
            end if;
        end if;
    end process;
    up(3).dnlink_ready <= '1';

    -- the host: TAP and ipdbg server
    host : process
        variable dn_xoff      : std_logic_vector(6 downto 0) := (others => '0');
        variable last_dn_tool : natural := TOOL_HUB;
        variable sent         : counts_t := (others => 0);
        variable received_3   : natural := 0;
        variable up_word      : std_logic_vector(DR_LENGTH - 1 downto 0);
        variable xoff_seen    : boolean := false;
        variable scans        : natural := 0;

        procedure tck_cycle is begin
            wait for T_TCK / 2;
            drclk <= '1';
            wait for T_TCK / 2;
            drclk <= '0';
        end procedure;

        -- one DR scan through Capture-DR, Shift-DR, Exit1-DR, Update-DR to Run-Test/Idle
        procedure dr_scan(dn_word : std_logic_vector(DR_LENGTH - 1 downto 0);
                          up_w    : out std_logic_vector(DR_LENGTH - 1 downto 0)) is
        begin
            capture <= '1';
            tck_cycle;
            capture <= '0';
            shift   <= '1';
            for i in 0 to DR_LENGTH - 1 loop
                tdi_pin  <= dn_word(i);
                up_w(i) := tdo;
                tck_cycle;
            end loop;
            shift <= '0';
            tck_cycle;          -- Exit1-DR
            update <= '1';
            tck_cycle;          -- Update-DR
            update <= '0';
            tck_cycle;          -- Run-Test/Idle
            scans := scans + 1;
        end procedure;

        -- data from the hub, like ipdbg_distribute_data_from_hub
        procedure distribute(w : std_logic_vector(DR_LENGTH - 1 downto 0)) is
            variable tool : natural;
        begin
            if w(12) = '1' then
                tool := to_integer(unsigned(w(10 downto 8)));
                if tool = TOOL_HUB then
                    if w(7) = '0' then -- xon
                        dn_xoff := dn_xoff and not w(6 downto 0);
                    end if;
                else
                    assert tool = 3 report "data from channel " & integer'image(tool) severity failure;
                    assert w(7 downto 0) = test_byte(3, received_3)
                        report "channel 3: byte " & integer'image(received_3) & " wrong" severity failure;
                    received_3 := received_3 + 1;
                end if;
            end if;
        end procedure;

        -- like ipdbg_check_for_xoff: the xoff bit belongs to the channel of the
        -- previous scan with data
        procedure check_for_xoff(tool : natural; w : std_logic_vector(DR_LENGTH - 1 downto 0)) is begin
            if w(11) = '1' and last_dn_tool /= TOOL_HUB then
                dn_xoff(last_dn_tool) := '1';
                xoff_seen := true;
            end if;
            last_dn_tool := tool;
        end procedure;

        procedure send_byte(tool : natural) is
            variable w : std_logic_vector(DR_LENGTH - 1 downto 0);
        begin
            w := "10" & std_logic_vector(to_unsigned(tool, 3)) & test_byte(tool, sent(tool));
            dr_scan(w, up_word);
            distribute(up_word);
            check_for_xoff(tool, up_word);
            sent(tool) := sent(tool) + 1;
        end procedure;

        -- An empty scan does not evaluate the xoff bit: the hub records an xoff as
        -- seen by the host only in a scan with valid data. The xoff stays set,
        -- so the next scan with data reports it again.
        procedure poll is begin
            dr_scan((others => '0'), up_word);
            distribute(up_word);
        end procedure;

        variable all_sent : boolean;
    begin
        wait for 5 * T_CLK;
        rst <= '0';
        wait for 5 * T_CLK;

        -- reset of the hub: the answer tells the channels with flow control
        dr_scan("10" & "111" & x"00", up_word);
        poll;
        assert up_word(12) = '1' and up_word(10 downto 8) = "111" and up_word(7 downto 0) = '1' & FLOW_CONTROL_ENABLE
            report "answer to the reset: 0x" & to_hstring("000" & up_word) severity failure;

        -- send N_BYTES to channels 0, 1 and 2 in turns, as fast as xoff allows,
        -- and receive the bytes of channel 3
        loop
            all_sent := true;
            for c in 0 to 2 loop
                if sent(c) < N_BYTES then
                    all_sent := false;
                    if dn_xoff(c) = '0' then
                        send_byte(c);
                    end if;
                end if;
            end loop;
            if dn_xoff /= "0000000" then
                poll;
            end if;
            exit when all_sent;
            assert scans < 20000 report "timeout while sending: dn_xoff " & to_string(dn_xoff) &
                ", sent " & integer'image(sent(0)) & "/" & integer'image(sent(1)) & "/" & integer'image(sent(2)) &
                ", received by the cores " & integer'image(received_by_core(0)) & "/" &
                integer'image(received_by_core(1)) & "/" & integer'image(received_by_core(2)) severity failure;
        end loop;

        -- wait for the slow cores, receive the rest of channel 3
        while received_by_core(1) < N_BYTES or received_by_core(2) < N_BYTES or received_3 < N_BYTES loop
            poll;
            assert scans < 20000 report "timeout: core 1 received " & integer'image(received_by_core(1)) &
                ", core 2 " & integer'image(received_by_core(2)) & ", host from channel 3 " &
                integer'image(received_3) severity failure;
        end loop;
        wait for 20 * T_CLK;

        assert received_by_core(0) = N_BYTES report "channel 0: " & integer'image(received_by_core(0)) & " bytes" severity failure;
        assert received_by_core(1) = N_BYTES report "channel 1: " & integer'image(received_by_core(1)) & " bytes" severity failure;
        assert received_by_core(2) = N_BYTES report "channel 2: " & integer'image(received_by_core(2)) & " bytes" severity failure;
        assert received_3 = N_BYTES report "channel 3: " & integer'image(received_3) & " bytes" severity failure;
        assert xoff_seen report "no xoff from the slow cores, flow control not tested" severity failure;

        report "tb_JtagHub: all tests passed (TDI_HAS_EXT_REGISTER = " & boolean'image(TDI_HAS_EXT_REGISTER) &
               ", " & integer'image(scans) & " scans)";
        done <= true;
        wait;
    end process;
end architecture test;
