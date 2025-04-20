library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;
use work.ipdbg_interface_pkg.all;

entity AhbMaster is
    generic (
        ASYNC_RESET : boolean;
        MASTER_ID   : std_logic_vector
    );
    port (
        clk       : in    std_logic;
        rst       : in    std_logic;
        ce        : in    std_logic;

        --      host interface (UART or ....)
        dn_lines  : in    ipdbg_dn_lines;
        up_lines  : out   ipdbg_up_lines;

        -- apb interface
        haddr     : out   std_logic_vector;
        hwrite    : out   std_logic;
        hsize     : out   std_logic_vector(2 downto 0);
        hburst    : out   std_logic_vector; -- width must be 0 or 3
        hprot     : out   std_logic_vector; -- width must be 0, 4 or 7
        htrans    : out   std_logic_vector(1 downto 0);
        hmastlock : out   std_logic;
        hwdata    : out   std_logic_vector;
        hready    : in    std_logic;
        hresp     : in    std_logic;
        hrdata    : in    std_logic_vector;
        hwstrb    : out   std_logic_vector;
        -- hnonsec   : out   std_logic;
        -- hexcl     : out   std_logic;
        -- hexokay   : in    std_logic
        hmaster   : out   std_logic_vector(MASTER_ID'length - 1 downto 0)
    );
end entity AhbMaster;

architecture behavioral of AhbMaster is
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

    impure function calc_misc_init return std_logic_vector is
        variable prot : std_logic_vector(hprot'length - 1 downto 0);
        variable size : std_logic_vector(hsize'length - 1 downto 0);
    begin
        prot             := (others => '0');
        prot(1 downto 0) := "11";
        size             := std_logic_vector(to_unsigned(integer(round(log2(real(hwdata'length / 8)))), hsize'length));
        return prot & size;
    end function;

    constant DATA_WIDTH    : positive                                  := hwdata'length;
    constant ADDRESS_WIDTH : natural                                   := haddr'length;
    constant STROBE_WIDTH  : natural                                   := hwstrb'length;
    constant MISC_WIDTH    : natural                                   := hprot'length + hsize'length;
    constant MISC_INIT     : std_logic_vector(MISC_WIDTH - 1 downto 0) := calc_misc_init;

    signal   reset         : std_logic;
    signal   address       : std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
    signal   read_data     : std_logic_vector(DATA_WIDTH - 1 downto 0);
    signal   write_data    : std_logic_vector(DATA_WIDTH - 1 downto 0);
    signal   strobe        : std_logic_vector(STROBE_WIDTH - 1 downto 0);
    signal   start_write   : std_logic;
    signal   start_read    : std_logic;
    signal   write_done    : std_logic;
    signal   read_done     : std_logic;
    signal   access_error  : std_logic;
    signal   lock          : std_logic;
    signal   miscellaneous : std_logic_vector(MISC_WIDTH - 1 downto 0);
begin
    assert hwdata'length = hrdata'length
        report "hwdata and hrdata must have the same width"
        severity failure;
    assert ADDRESS_WIDTH <= 32
        report "AMBA AHB address bus can be up to 32 bits wide."
        severity failure;
    assert DATA_WIDTH = 1204 or DATA_WIDTH = 512 or DATA_WIDTH = 256 or DATA_WIDTH = 128 or
           DATA_WIDTH = 64 or DATA_WIDTH = 32 or DATA_WIDTH = 16 or DATA_WIDTH = 8
        report "hwdata and hrdata must have a width of 8, 16, 32, 64, 128, 256, 512 or 1024 bits."
        severity failure;
    assert STROBE_WIDTH * 8 = DATA_WIDTH
        report "The width of hwstrb must be 1/8th of the width of hwdata"
        severity failure;

    haddr   <= address;
    hwdata  <= write_data;
    hmaster <= MASTER_ID;
    hburst  <= "000"; -- hburst: only single transfer busrt
    hsize   <= miscellaneous(hsize'length - 1 downto 0);
    hprot   <= miscellaneous(hprot'length - 1 + hsize'length downto hsize'length);

    apb_control : block
        type     states        is (idle, addr, data);
        signal   state         : states;
        signal   arst, srst    : std_logic;
        signal   we            : std_logic;
        signal   sel           : std_logic;
        constant HTRANS_IDLE   : std_logic_vector(1 downto 0) := "00";
        constant HTRANS_BUSY   : std_logic_vector(1 downto 0) := "01";
        constant HTRANS_NONSEQ : std_logic_vector(1 downto 0) := "10";
        constant HTRANS_SEQ    : std_logic_vector(1 downto 0) := "11";
    begin
        async_init : if ASYNC_RESET generate begin
            arst <= reset;
            srst <= '0';
        end generate async_init;
        sync_init : if not ASYNC_RESET generate begin
            arst <= '0';
            srst <= reset;
        end generate sync_init;

        hwrite <= we;

        -- hmastlock is set to '1' during address cycle when lock is '1'.
        -- will be cleared during data cycle when lock is '0'

        process (clk, arst)
            procedure reset_assignments is
            begin
                state        <= idle;
                htrans       <= HTRANS_IDLE;
                we           <= '-';
                read_data    <= (others => '-');
                read_done    <= '0';
                write_done   <= '0';
                access_error <= '-';
                hmastlock    <= '0';
                hwstrb       <= (hwstrb'range => '-');
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
                        case state is
                        when idle =>
                            if start_write = '1' then
                                we <= '1';
                                if STROBE_WIDTH = 1 then
                                    hwstrb <= "1";
                                else
                                    hwstrb <= strobe;
                                end if;
                            elsif start_read = '1' then
                                we     <= '0';
                                hwstrb <= (hwstrb'range => '0');
                            end if;
                            if (start_write or start_read) = '1' then
                                state  <= addr;
                                htrans <= HTRANS_NONSEQ;
                                if lock = '1' then
                                    hmastlock <= lock;
                                end if;
                            end if;
                        when addr =>
                            if hready = '1' then
                                state  <= data;
                                htrans <= HTRANS_IDLE;
                            end if;
                        when data =>
                            if hready = '1' then
                                state <= idle;
                                if lock = '0' then
                                    hmastlock <= lock;
                                end if;
                                if we = '0' then
                                    read_done <= '1';
                                else
                                    write_done <= '1';
                                end if;
                            end if;
                        end case;

                        if hready = '1' and state = data then
                            if we = '0' then
                                read_data <= hrdata;
                            end if;
                            access_error <= hresp;
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
            lock          => lock
        );
end architecture behavioral;
