-- SPDX-FileCopyrightText: The IPDBG authors
-- SPDX-License-Identifier: CERN-OHL-W-2.0

-- Self-checking testbench for IpdbgClockDomainCrossing: the host model of
-- ipdbg_test_pkg sends bytes, a core in the other clock domain returns each
-- byte + 1, both sides with random back-pressure. Reports
-- "tb_IpdbgClockDomainCrossing: all tests passed".

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ipdbg_interface_pkg.all;
use work.ipdbg_test_pkg.all;

entity tb_IpdbgClockDomainCrossing is
    generic(
        ASYNC_RESET       : boolean  := false;
        T_FUNC_PS         : positive := 13000; -- clock period of the core in ps; the host clock is 10 ns
        SEED              : positive := 1;
        MAX_GAP           : natural  := 3;
        MAX_DELAY         : natural  := 4;
        MAX_BUSY          : natural  := 5;     -- the core is not ready for 0..MAX_BUSY clocks
        READY_AFTER_VALID : boolean  := false
    );
end entity tb_IpdbgClockDomainCrossing;

architecture test of tb_IpdbgClockDomainCrossing is
    constant N_BYTES   : positive := 300;

    signal clk         : std_logic := '0';
    signal clk_func    : std_logic := '0';
    signal rst         : std_logic := '1';
    signal done        : boolean   := false;

    signal dn_valid    : std_logic := '0';
    signal dn_data     : byte_t;
    signal up_ready    : std_logic;
    signal dn_host     : ipdbg_dn_lines;
    signal up_host     : ipdbg_up_lines;
    signal dn_func     : ipdbg_dn_lines;
    signal up_func     : ipdbg_up_lines;
begin
    clk      <= not clk after 5 ns when not done;
    clk_func <= not clk_func after T_FUNC_PS * 1 ps / 2 when not done;

    dn_host <= (uplink_ready => up_ready, dnlink_valid => dn_valid, dnlink_data => dn_data);
    host_sink(clk, up_host.uplink_valid, up_host.uplink_data, up_ready, MAX_DELAY, READY_AFTER_VALID);

    dut : entity work.IpdbgClockDomainCrossing
        generic map(
            ASYNC_RESET => ASYNC_RESET,
            MFF_LENGTH  => 3
        )
        port map(
            clk_func      => clk_func,
            rst_func      => rst,
            ce_func       => '1',
            clk_host      => clk,
            rst_host      => rst,
            ce_host       => '1',
            dn_lines_host => dn_host,
            up_lines_host => up_host,
            dn_lines_func => dn_func,
            up_lines_func => up_func
        );

    -- returns each byte + 1; one byte in the core at a time
    core : process (clk_func)
        variable busy      : natural := 0;
        variable has_byte  : boolean := false;
        variable held      : boolean := false;
        variable held_data : byte_t;
    begin
        if rising_edge(clk_func) then
            if rst = '1' then
                up_func <= (dnlink_ready => '0', uplink_valid => '0', uplink_data => (others => '-'));
            else
                if held then
                    assert dn_func.dnlink_valid = '1' and dn_func.dnlink_data = held_data
                        report "core: valid or data changed before the transfer" severity failure;
                end if;
                held := false;
                if up_func.uplink_valid = '1' and dn_func.uplink_ready = '1' then
                    up_func.uplink_valid <= '0';
                    has_byte := false;
                end if;
                if dn_func.dnlink_valid = '1' then
                    if up_func.dnlink_ready = '1' then
                        has_byte := true;
                        up_func.uplink_valid <= '1';
                        up_func.uplink_data  <= std_logic_vector(unsigned(dn_func.dnlink_data) + 1);
                        busy := random_int(0, MAX_BUSY);
                    else
                        held := true;
                        held_data := dn_func.dnlink_data;
                    end if;
                end if;
                if busy > 0 then
                    busy := busy - 1;
                end if;
                up_func.dnlink_ready <= '1' when busy = 0 and not has_byte else '0';
            end if;
        end if;
    end process;

    stimulus : process
        variable bytes    : byte_array(0 to N_BYTES - 1);
        variable expected : byte_array(0 to N_BYTES - 1);
    begin
        seed_random(SEED);
        for i in bytes'range loop
            bytes(i) := random_slv(8);
            expected(i) := std_logic_vector(unsigned(bytes(i)) + 1);
        end loop;
        wait_clocks(clk, 5);
        rst <= '0';
        wait_clocks(clk, 5);
        host_send(clk, dn_valid, dn_data, up_host.dnlink_ready, bytes, MAX_GAP);
        host_expect(clk, expected, "returned bytes");
        host_expect_nothing(clk, 50, "end");

        report "tb_IpdbgClockDomainCrossing: all tests passed (ASYNC_RESET = " & boolean'image(ASYNC_RESET) &
               ", T_FUNC_PS = " & integer'image(T_FUNC_PS) & ", SEED = " & integer'image(SEED) & ")";
        done <= true;
        wait;
    end process;
end architecture test;
