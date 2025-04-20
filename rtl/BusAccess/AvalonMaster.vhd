library ieee;
use ieee.std_logic_1164.all;

library work;
use work.ipdbg_interface_pkg.all;

entity AvalonMaster is
    generic (
        ASYNC_RESET : boolean
    );
    port (
        clk         : in    std_logic;
        rst         : in    std_logic;
        ce          : in    std_logic;

        --      host interface (UART or ....)
        dn_lines    : in    ipdbg_dn_lines;
        up_lines    : out   ipdbg_up_lines;

        -- apb interface
        address     : out   std_logic_vector; -- max 64 bits
        byteenable  : out   std_logic_vector;
        debugaccess : out   std_logic;
        read        : out   std_logic;
        readdata    : in    std_logic_vector; -- max 1024 bits
        response    : in    std_logic_vector(1 downto 0);
        write       : out   std_logic;
        writedata   : out   std_logic_vector; -- max 1024 bits
        lock        : out   std_logic;
        waitrequest : in    std_logic
    );
end entity AvalonMaster;

architecture behavioral of AvalonMaster is
    component BusAccessController is
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
    end component BusAccessController;

    constant DATA_WIDTH           : positive                                  := readdata'length;
    constant ADDRESS_WIDTH        : natural                                   := address'length;
    constant STROBE_WIDTH         : natural                                   := byteenable'length;
    constant MISC_WIDTH           : natural                                   := 1;
    constant MISC_INIT            : std_logic_vector(MISC_WIDTH - 1 downto 0) := "1";

    constant RESPONSE_OKAY        : std_logic_vector(1 downto 0) := "00";
    constant RESPONSE_RESERVED    : std_logic_vector(1 downto 0) := "01";
    constant RESPONSE_SLVERR      : std_logic_vector(1 downto 0) := "10";
    constant RESPONSE_DECODEERROR : std_logic_vector(1 downto 0) := "11";

    signal   reset                : std_logic;
    signal   read_data            : std_logic_vector(DATA_WIDTH - 1 downto 0);
    signal   write_data           : std_logic_vector(DATA_WIDTH - 1 downto 0);
    signal   strobe               : std_logic_vector(STROBE_WIDTH - 1 downto 0);
    signal   start_write          : std_logic;
    signal   start_read           : std_logic;
    signal   write_done           : std_logic;
    signal   read_done            : std_logic;
    signal   access_error         : std_logic;
    signal   miscellaneous        : std_logic_vector(MISC_WIDTH - 1 downto 0);
    signal   lock_s               : std_logic;
begin
    assert writedata'length = readdata'length
        report "writedata and readdata must have the same width"
        severity failure;
    assert DATA_WIDTH = 1204 or DATA_WIDTH = 512 or DATA_WIDTH = 256 or DATA_WIDTH = 128 or
           DATA_WIDTH = 64 or DATA_WIDTH = 32 or DATA_WIDTH = 16 or DATA_WIDTH = 8
        report "writedata and readdata must have a width of 8, 16, 32, 64, 128, 256, 512 or 1024 bits."
        severity failure;

    assert STROBE_WIDTH * 8 = DATA_WIDTH
        report "The width of byteenable must be 1/8th of the width of hwdata"
        severity failure;

    writedata   <= write_data;
    debugaccess <= miscellaneous(0);

    gen_byteenable1 : if STROBE_WIDTH = 1 generate begin
        byteenable <= "1";
    end generate;
    gen_byteenable2 : if STROBE_WIDTH > 1 generate begin
        byteenable <= strobe;
    end generate;

    apb_control : block
        signal arst, srst : std_logic;
        signal wrt        : std_logic;
        signal rd         : std_logic;
        signal lck        : std_logic;
    begin
        async_init : if ASYNC_RESET generate begin
            arst <= reset;
            srst <= '0';
        end generate async_init;
        sync_init : if not ASYNC_RESET generate begin
            arst <= '0';
            srst <= reset;
        end generate sync_init;

        read  <= rd;
        write <= wrt;

        process (clk, arst)
            procedure reset_assignments is
            begin
                read_data    <= (others => '-');
                read_done    <= '0';
                write_done   <= '0';
                rd           <= '0';
                wrt          <= '0';
                lock         <= '0';
                access_error <= '-';
            end procedure;
        begin
            if arst = '1' then
                reset_assignments;
            elsif rising_edge(clk) then
                if srst = '1' then
                    reset_assignments;
                else
                    if ce = '1' then
                        read_done  <= '0';
                        write_done <= '0';
                        if rd = '0' and wrt = '0' then
                            if start_write = '1' then
                                wrt <= '1';
                            end if;
                            if start_read = '1' then
                                rd <= '1';
                            end if;
                            if lock_s = '1' then
                                lock <= '1';
                            end if;
                        else
                            if waitrequest = '0' then
                                rd           <= '0';
                                wrt          <= '0';
                                read_done    <= rd;
                                write_done   <= wrt;
                                read_data    <= readdata;
                                access_error <= '0';
                                if rd = '1' and response /= RESPONSE_OKAY then
                                    access_error <= '1';
                                end if;
                                if lock_s = '0' then
                                    lock <= '0';
                                end if;
                            end if;
                        end if;
                    end if;
                end if;
            end if;
        end process;
    end block;

    controller_i : component BusAccessController
        generic map (
            ASYNC_RESET   => ASYNC_RESET,
            ADDRESS_WIDTH => ADDRESS_WIDTH,
            R_DATA_WIDTH  => DATA_WIDTH,
            W_DATA_WIDTH  => DATA_WIDTH,
            STROBE_WIDTH  => STROBE_WIDTH,
            MISC_WIDTH    => MISC_WIDTH,
            MISC_INIT     => MISC_INIT
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
            access_error  => access_error,
            lock          => lock_s
        );
end architecture behavioral;
