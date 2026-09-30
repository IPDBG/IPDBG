-- SPDX-FileCopyrightText: The IPDBG authors
-- SPDX-License-Identifier: CERN-OHL-W-2.0

-- IPDBG UART transport: connects one IPDBG core to a UART, e.g. a
-- USB-serial adapter; on the host, sw/UartBridge forwards a TCP port to it.
-- Fixed frame format 8N1: 8 data bits, no parity, 1 stop bit.
-- baudrate = clk frequency / (16 * CLOCKS_PER_ONE_SIXTEENTH_BIT)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ipdbg_interface_pkg.all;

entity IpdbgUart is
    generic(
        CLOCKS_PER_ONE_SIXTEENTH_BIT : positive;
        NUM_META_FLOPS               : positive;
        ASYNC_RESET                  : boolean
    );
    port(
        clk      : in  std_logic;
        rst      : in  std_logic;
        ce       : in  std_logic;
        txd      : out std_logic;
        rxd      : in  std_logic;
        dn_lines : out ipdbg_dn_lines;
        up_lines : in  ipdbg_up_lines
    );
end entity IpdbgUart;

architecture behavioral of IpdbgUart is
    component IpdbgUartTx is
        generic (
            CLOCKS_PER_ONE_SIXTEENTH_BIT : positive;
            PARITY                       : natural range 0 to 2; -- 0: none; 1: odd; 2: even
            STOP_BITS                    : natural range 1 to 3; -- 1, 1.5, 2
            ASYNC_RESET                  : boolean;
            HW_HS                        : boolean
        );
        port (
            clk        : in  std_logic;
            rst        : in  std_logic;
            ce         : in  std_logic;
            txd        : out std_logic;
            cts        : in  std_logic;
            data       : in  std_logic_vector;
            data_valid : in  std_logic;
            data_ready : out std_logic
        );
    end component IpdbgUartTx;

    component IpdbgUartRx is
        generic (
            CLOCKS_PER_ONE_SIXTEENTH_BIT : positive;
            NUM_META_FLOPS               : positive;
            PARITY                       : natural range 0 to 2; -- 0: none; 1: odd; 2: even
            ASYNC_RESET                  : boolean;
            HW_HS                        : boolean
        );
        port (
            clk        : in  std_logic;
            rst        : in  std_logic;
            ce         : in  std_logic;
            rxd        : in  std_logic;
            rts        : out std_logic;
            data       : out std_logic_vector;
            data_valid : out std_logic;
            data_ready : in  std_logic;
            data_err   : out std_logic
        );
    end component IpdbgUartRx;

    signal srst, arst            : std_logic;

    signal tx_data               : std_logic_vector(7 downto 0);
    signal tx_data_valid         : std_logic;
    signal tx_data_ready         : std_logic;

    signal rx_data               : std_logic_vector(7 downto 0);
    signal rx_data_valid         : std_logic;
    signal rx_data_ready         : std_logic;

    signal dn_lines_uplink_ready : std_logic;
    signal dn_lines_dnlink_valid : std_logic;
    signal dn_lines_dnlink_data  : std_logic_vector(7 downto 0);
begin
    async_init: if ASYNC_RESET generate begin
        arst <= rst;
        srst <= '0';
    end generate async_init;
    sync_init: if not ASYNC_RESET generate begin
        arst <= '0';
        srst <= rst;
    end generate sync_init;

    -- a byte is only taken while the register is empty and the transmitter is
    -- idle; tx_data_ready is registered, so it is still '1' in the cycle after
    -- tx_data_valid was set
    dn_lines_uplink_ready <= tx_data_ready and not tx_data_valid;
    up: process(arst, clk)
        procedure reset_assignments is begin
            tx_data <= (others => '-');
            tx_data_valid <= '0';
        end procedure;
    begin
        if arst = '1' then
            reset_assignments;
        elsif rising_edge(clk) then
            if srst = '1' then
                reset_assignments;
            else
                if ce = '1' then
                    if tx_data_valid = '1' and tx_data_ready = '1' then
                        tx_data_valid <= '0'; -- taken by the transmitter
                    end if;
                    if dn_lines_uplink_ready = '1' and up_lines.uplink_valid = '1' then
                        tx_data <= up_lines.uplink_data;
                        tx_data_valid <= '1';
                    end if;
                end if;
            end if;
        end if;
    end process;

    dn_lines.uplink_ready <= dn_lines_uplink_ready;
    dn_lines.dnlink_valid <= dn_lines_dnlink_valid;
    dn_lines.dnlink_data <= dn_lines_dnlink_data;

    rx_data_ready <= up_lines.dnlink_ready;
    down: process(arst, clk)
        procedure reset_assignments is begin
            dn_lines_dnlink_data <= (others => '-');
            dn_lines_dnlink_valid <= '0';
        end procedure;
    begin
        if arst = '1' then
            reset_assignments;
        elsif rising_edge(clk) then
            if srst = '1' then
                reset_assignments;
            else
                if ce = '1' then
                    dn_lines_dnlink_valid <= '0';
                    if up_lines.dnlink_ready = '1' then
                        if rx_data_valid = '1' then
                            dn_lines_dnlink_data <= rx_data;
                            dn_lines_dnlink_valid <= '1';
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

    tx: component IpdbgUartTx
        generic map(
            CLOCKS_PER_ONE_SIXTEENTH_BIT => CLOCKS_PER_ONE_SIXTEENTH_BIT,
            PARITY                       => 0, -- 8N1
            STOP_BITS                    => 1,
            ASYNC_RESET                  => ASYNC_RESET,
            HW_HS                        => false
        )
        port map(
            clk        => clk,
            rst        => rst,
            ce         => ce,
            txd        => txd,
            cts        => '0',
            data       => tx_data,
            data_valid => tx_data_valid,
            data_ready => tx_data_ready
        );

    rx: component IpdbgUartRx
        generic map(
            CLOCKS_PER_ONE_SIXTEENTH_BIT => CLOCKS_PER_ONE_SIXTEENTH_BIT,
            NUM_META_FLOPS               => NUM_META_FLOPS,
            PARITY                       => 0, -- 8N1
            ASYNC_RESET                  => ASYNC_RESET,
            HW_HS                        => false
        )
        port map(
            clk        => clk,
            rst        => rst,
            ce         => ce,
            rxd        => rxd,
            rts        => open,
            data       => rx_data,
            data_valid => rx_data_valid,
            data_ready => rx_data_ready,
            data_err   => open
        );
end architecture behavioral;
