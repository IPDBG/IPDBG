-- SPDX-FileCopyrightText: The IPDBG authors
-- SPDX-License-Identifier: CERN-OHL-W-2.0

-- IoProbe: read and set signals of the design from the host.
--
-- Speaks the BusAccess protocol (core type 1, see BusAccessStatemachine.vhd),
-- so it is used with the BusAccess library and IoView:
--   address width 0, no strobe, no misc
--   write: sets probe_outputs (write data width = probe_outputs'length)
--   read:  returns probe_inputs, all bits sampled in the same clock cycle
--          (read data width = probe_inputs'length)
-- Every access is answered with ACK.
--
-- probe_outputs are '0' after reset and after the host connects (the host
-- resets the core on every connect).
--
-- Needs rtl/BusAccess/BusAccessController.vhd, BusAccessStatemachine.vhd and
-- rtl/common/IpdbgEscaping.vhd.

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.ipdbg_interface_pkg.all;

entity IoProbeTop is
    generic(
        ASYNC_RESET : boolean := true
    );
    port(
        clk                  : in  std_logic;
        rst                  : in  std_logic;
        ce                   : in  std_logic;

        -- host interface (JtagHub or UART or ....)
        dn_lines             : in  ipdbg_dn_lines;
        up_lines             : out ipdbg_up_lines;

        probe_inputs         : in  std_logic_vector; -- read by the host, at least 1 bit
        probe_outputs        : out std_logic_vector; -- set by the host, at least 1 bit
        probe_outputs_update : out std_logic         -- one clock cycle pulse when the host wrote probe_outputs
    );
end entity IoProbeTop;

architecture behavioral of IoProbeTop is
    component BusAccessController is
        generic (
            ASYNC_RESET   : boolean;
            ADDRESS_WIDTH : natural;
            R_DATA_WIDTH  : positive;
            W_DATA_WIDTH  : positive;
            STROBE_WIDTH  : natural;
            MISC_WIDTH    : natural;
            MISC_INIT     : std_logic_vector;
            CORE_TYPE     : natural range 0 to 255
        );
        port (
            clk           : in    std_logic;
            rst           : in    std_logic;
            ce            : in    std_logic;
            dn_lines      : in    ipdbg_dn_lines;
            up_lines      : out   ipdbg_up_lines;
            reset         : out   std_logic;
            address       : out   std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
            read_data     : in    std_logic_vector(R_DATA_WIDTH - 1 downto 0);
            write_data    : out   std_logic_vector(W_DATA_WIDTH - 1 downto 0);
            strobe        : out   std_logic_vector(STROBE_WIDTH - 1 downto 0);
            miscellaneous : out   std_logic_vector;
            start_write   : out   std_logic;
            start_read    : out   std_logic;
            write_done    : in    std_logic;
            read_done     : in    std_logic;
            access_error  : in    std_logic;
            lock          : out   std_logic
        );
    end component BusAccessController;

    constant CORE_TYPE_IOPROBE : natural  := 1;
    constant INPUT_WIDTH       : positive := probe_inputs'length;
    constant OUTPUT_WIDTH      : positive := probe_outputs'length;

    signal reset         : std_logic;
    signal address       : std_logic_vector(-1 downto 0);
    signal read_data     : std_logic_vector(INPUT_WIDTH - 1 downto 0);
    signal write_data    : std_logic_vector(OUTPUT_WIDTH - 1 downto 0);
    signal strobe        : std_logic_vector(-1 downto 0);
    signal miscellaneous : std_logic_vector(0 downto 0);
    signal start_write   : std_logic;
    signal start_read    : std_logic;
    signal write_done    : std_logic;
    signal read_done     : std_logic;
    signal lock          : std_logic;

    signal arst, srst    : std_logic;
begin
    controller : component BusAccessController
        generic map (
            ASYNC_RESET   => ASYNC_RESET,
            ADDRESS_WIDTH => 0,
            R_DATA_WIDTH  => INPUT_WIDTH,
            W_DATA_WIDTH  => OUTPUT_WIDTH,
            STROBE_WIDTH  => 0,
            MISC_WIDTH    => 0,
            MISC_INIT     => "0",
            CORE_TYPE     => CORE_TYPE_IOPROBE
        )
        port map (
            clk           => clk,
            rst           => rst,
            ce            => ce,
            dn_lines      => dn_lines,
            up_lines      => up_lines,
            reset         => reset,
            address       => address,
            read_data     => read_data,
            write_data    => write_data,
            strobe        => strobe,
            miscellaneous => miscellaneous,
            start_write   => start_write,
            start_read    => start_read,
            write_done    => write_done,
            read_done     => read_done,
            access_error  => '0',
            lock          => lock
        );

    -- sampled by the controller in the clock cycle with read_done = '1'
    read_data <= probe_inputs;

    async_init : if ASYNC_RESET generate begin
        arst <= reset;
        srst <= '0';
    end generate async_init;
    sync_init : if not ASYNC_RESET generate begin
        arst <= '0';
        srst <= reset;
    end generate sync_init;

    process (clk, arst)
        procedure reset_assignments is
        begin
            probe_outputs        <= (probe_outputs'range => '0');
            probe_outputs_update <= '0';
            write_done           <= '0';
            read_done            <= '0';
        end procedure reset_assignments;
    begin
        if arst = '1' then
            reset_assignments;
        elsif rising_edge(clk) then
            if srst = '1' then
                reset_assignments;
            else
                if ce = '1' then
                    probe_outputs_update <= '0';
                    write_done           <= start_write;
                    read_done            <= start_read;
                    if start_write = '1' then
                        probe_outputs        <= write_data;
                        probe_outputs_update <= '1';
                    end if;
                end if;
            end if;
        end if;
    end process;
end architecture behavioral;
