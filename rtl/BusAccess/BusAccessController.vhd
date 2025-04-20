library ieee;
use ieee.std_logic_1164.all;

library work;
use work.ipdbg_interface_pkg.all;

entity BusAccessController is
    generic (
        ASYNC_RESET   : boolean;
        ADDRESS_WIDTH : natural;
        R_DATA_WIDTH  : positive;
        W_DATA_WIDTH  : positive;
        STROBE_WIDTH  : natural;
        MISC_WIDTH    : natural;
        MISC_INIT     : std_logic_vector
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
end entity BusAccessController;

architecture behavioral of BusAccessController is
    component IpdbgEscaping is
        generic (
            ASYNC_RESET  : boolean;
            DO_HANDSHAKE : boolean
        );
        port (
            clk          : in    std_logic;
            rst          : in    std_logic;
            ce           : in    std_logic;
            dn_lines_in  : in    ipdbg_dn_lines;
            dn_lines_out : out   ipdbg_dn_lines;
            up_lines_out : out   ipdbg_up_lines;
            up_lines_in  : in    ipdbg_up_lines;
            reset        : out   std_logic
        );
    end component IpdbgEscaping;

    component BusAccessStatemachine is
        generic (
            ASYNC_RESET   : boolean;
            ADDRESS_WIDTH : natural;
            R_DATA_WIDTH  : positive;
            W_DATA_WIDTH  : positive;
            STROBE_WIDTH  : natural;
            MISC_WIDTH    : natural;
            MISC_INIT     : std_logic_vector
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
    end component BusAccessStatemachine;

    signal dn_lines_unescaped : ipdbg_dn_lines;
    signal up_lines_unescaped : ipdbg_up_lines;
    signal reset_i            : std_logic;
begin
    escaping_i : component IpdbgEscaping
        generic map (
            ASYNC_RESET  => ASYNC_RESET,
            DO_HANDSHAKE => false
        )
        port map (
            clk          => clk,
            rst          => rst,
            ce           => ce,
            dn_lines_in  => dn_lines,
            dn_lines_out => dn_lines_unescaped,
            up_lines_out => up_lines,
            up_lines_in  => up_lines_unescaped,
            reset        => reset_i
        );

    reset <= reset_i;

    fsm_i : component BusAccessStatemachine
        generic map (
            ASYNC_RESET   => ASYNC_RESET,
            ADDRESS_WIDTH => ADDRESS_WIDTH,
            R_DATA_WIDTH  => R_DATA_WIDTH,
            W_DATA_WIDTH  => W_DATA_WIDTH,
            STROBE_WIDTH  => STROBE_WIDTH,
            MISC_WIDTH    => MISC_WIDTH,
            MISC_INIT     => MISC_INIT
        )
        port map (
            clk           => clk,
            rst           => reset_i,
            ce            => ce,
            dn_lines      => dn_lines_unescaped,
            up_lines      => up_lines_unescaped,
            address       => address,
            read_data     => read_data,
            write_data    => write_data,
            strobe        => strobe,
            miscellaneous => miscellaneous,
            start_write   => start_write,
            start_read    => start_read,
            write_done    => write_done,
            read_done     => read_done,
            access_error  => access_error,
            lock          => lock
        );
end architecture behavioral;
