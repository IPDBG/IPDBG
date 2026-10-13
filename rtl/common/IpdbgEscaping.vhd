-- SPDX-FileCopyrightText: The IPDBG authors
-- SPDX-License-Identifier: CERN-OHL-W-2.0

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ipdbg_interface_pkg.all;

entity IpdbgEscaping is
    generic(
         ASYNC_RESET  : boolean := true;
         DO_HANDSHAKE : boolean := false -- no effect, kept for existing instances
    );
    port(
        clk          : in  std_logic;
        rst          : in  std_logic;
        ce           : in  std_logic;
        dn_lines_in  : in  ipdbg_dn_lines;
        dn_lines_out : out ipdbg_dn_lines;
        up_lines_out : out ipdbg_up_lines;
        up_lines_in  : in  ipdbg_up_lines;
        reset        : out std_logic
    );
end entity IpdbgEscaping;

architecture behavioral of IpdbgEscaping is
    constant escape_symbol : std_logic_vector (7 downto 0) := x"55"; --55
    constant reset_symbol  : std_logic_vector (7 downto 0) := x"EE"; --EE

    type escaping_states_t is(normal_s, escaping_s);
    signal state          : escaping_states_t;
    signal arst, srst     : std_logic;
    signal out_valid      : std_logic;
    signal in_ready       : std_logic;
begin
    async_init: if ASYNC_RESET generate begin
        arst <= rst;
        srst <= '0';
    end generate async_init;
    sync_init: if not ASYNC_RESET generate begin
        arst <= '0';
        srst <= rst;
    end generate sync_init;

    -- upstream: unchanged
    up_lines_out.uplink_valid <= up_lines_in.uplink_valid;
    up_lines_out.uplink_data  <= up_lines_in.uplink_data;
    dn_lines_out.uplink_ready <= dn_lines_in.uplink_ready;

    -- downstream: one register stage, takes a byte when it is empty or the
    -- core takes the byte in it
    in_ready <= (not out_valid) or up_lines_in.dnlink_ready;
    up_lines_out.dnlink_ready <= in_ready;
    dn_lines_out.dnlink_valid <= out_valid;

    process (clk, arst)
        procedure rst_assignments is begin
            reset <= '1';
            out_valid <= '0';
            dn_lines_out.dnlink_data <= (others => '-');
            state <= normal_s;
        end procedure rst_assignments;
    begin
        if arst = '1' then
            rst_assignments;
        elsif rising_edge(clk) then
            if srst = '1' then
                rst_assignments;
            else
                if ce = '1' then
                    reset <= '0';
                    if up_lines_in.dnlink_ready = '1' then
                        out_valid <= '0';
                    end if;
                    if dn_lines_in.dnlink_valid = '1' and in_ready = '1' then
                        case state is
                        when normal_s =>
                            if dn_lines_in.dnlink_data = escape_symbol then
                                state <= escaping_s;
                            elsif dn_lines_in.dnlink_data = reset_symbol then
                                reset <= '1';
                                out_valid <= '0';
                            else
                                out_valid <= '1';
                                dn_lines_out.dnlink_data <= dn_lines_in.dnlink_data;
                            end if;
                        when escaping_s =>
                            state <= normal_s;
                            out_valid <= '1';
                            dn_lines_out.dnlink_data <= dn_lines_in.dnlink_data;
                        end case;
                    end if;
                end if;
            end if;
        end if;
    end process;

end architecture behavioral;
