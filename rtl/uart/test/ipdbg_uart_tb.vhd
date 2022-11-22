library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ipdbg_interface_pkg.all;

entity ipdbg_uart_tb  is
end entity ipdbg_uart_tb;

architecture test of ipdbg_uart_tb is
    component ipdbg_uart is
        generic(
            CLOCKS_PER_ONE_SIXTEENTH_BIT : positive;
            NUM_META_FLOPS               : positive;
            PARITY                       : natural range 0 to 2; -- 0: none; 1: odd; 2: even
            STOP_BITS                    : natural range 1 to 3; -- 1, 1.5, 2
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
    end component ipdbg_uart;

    component IoViewTop is
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

            --- Input & Ouput--------
            probe_inputs         : in  std_logic_vector;
            probe_outputs        : out std_logic_vector;
            probe_outputs_update : out std_logic
        );
    end component IoViewTop;

    component uart_tx is
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
    end component uart_tx;

    component uart_rx is
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
    end component uart_rx;

    constant CLOCKS_PER_ONE_SIXTEENTH_BIT : positive := 16;
    constant NUM_META_FLOPS               : positive := 3;
    constant PARITY                       : natural := 0; -- 0: none; 1: odd; 2: even
    constant STOP_BITS                    : natural := 1;
    constant ASYNC_RESET                  : boolean := true;
    constant HW_HS                        : boolean := false;
    constant T                            : time := 10 ns;

    signal rst                            : std_logic;
    signal clk                            : std_logic;
    signal ce                             : std_logic;

    signal dn_lines                       : ipdbg_dn_lines;
    signal up_lines                       : ipdbg_up_lines;

    signal io_view_vec                    : std_logic_vector(7 downto 0);

    signal txd                            : std_logic;
    signal rxd                            : std_logic;
    signal tx_data                        : std_logic_vector(7 downto 0);
    signal tx_data_valid                  : std_logic;
    signal tx_data_ready                  : std_logic;
    signal rx_data                        : std_logic_vector(7 downto 0);
    signal rx_data_valid                  : std_logic;
    signal rx_data_ready                  : std_logic;
begin

    process begin
        clk <= '0';
        wait for T / 2;
        clk <= '1';
        wait for T / 2;
    end process;
    process begin
        rst <= '1';
        wait for 5.2 * t;
        rst <= '0';
        wait;
    end process;
    ce <= '1';




    rx_data_ready <= '1';

    process begin
        wait until rst = '0';
        wait for 5 * T;

        while true loop
            wait until rising_edge(clk);
            if tx_data_ready = '1' then
                exit;
            end if;
        end loop;

        wait for T/5;
        tx_data_valid <= '1';
        tx_data <= x"ee";
        wait for T;
        tx_data_valid <= '0';

        wait for 10 * T;


        while true loop
            wait until rising_edge(clk);
            if tx_data_ready = '1' then
                exit;
            end if;
        end loop;
        wait for T/5;
        tx_data_valid <= '1';
        tx_data <= x"ab";
        wait for T;
        tx_data_valid <= '0';

        wait for 10 * T;


        wait;
    end process;


    uut: component ipdbg_uart
        generic map(
            CLOCKS_PER_ONE_SIXTEENTH_BIT => CLOCKS_PER_ONE_SIXTEENTH_BIT,
            NUM_META_FLOPS               => NUM_META_FLOPS,
            PARITY                       => PARITY,
            STOP_BITS                    => STOP_BITS,
            ASYNC_RESET                  => ASYNC_RESET
        )
        port map(
            clk      => clk,
            rst      => rst,
            ce       => ce,
            txd      => txd,
            rxd      => rxd,
            dn_lines => dn_lines,
            up_lines => up_lines
        );

    iov_i: component IoViewTop
        generic map(
            ASYNC_RESET => ASYNC_RESET
        )
        port map(
            clk                  => clk,
            rst                  => rst,
            ce                   => ce,
            dn_lines             => dn_lines,
            up_lines             => up_lines,
            probe_inputs         => io_view_vec,
            probe_outputs        => io_view_vec,
            probe_outputs_update => open
        );

    tx: component uart_tx
        generic map(
            CLOCKS_PER_ONE_SIXTEENTH_BIT => CLOCKS_PER_ONE_SIXTEENTH_BIT,
            PARITY                       => PARITY,
            STOP_BITS                    => STOP_BITS,
            ASYNC_RESET                  => ASYNC_RESET,
            HW_HS                        => HW_HS
        )
        port map(
            clk        => clk,
            rst        => rst,
            ce         => ce,
            txd        => rxd,
            cts        => '0',
            data       => tx_data,
            data_valid => tx_data_valid,
            data_ready => tx_data_ready
        );

    rx: component uart_rx
        generic map(
            CLOCKS_PER_ONE_SIXTEENTH_BIT => CLOCKS_PER_ONE_SIXTEENTH_BIT,
            NUM_META_FLOPS               => NUM_META_FLOPS,
            PARITY                       => PARITY,
            ASYNC_RESET                  => ASYNC_RESET,
            HW_HS                        => HW_HS
        )
        port map(
            clk        => clk,
            rst        => rst,
            ce         => ce,
            rxd        => txd,
            rts        => open,
            data       => rx_data,
            data_valid => rx_data_valid,
            data_ready => rx_data_ready,
            data_err   => open
        );
end architecture test;
