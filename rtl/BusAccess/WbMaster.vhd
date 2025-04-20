library ieee;
use ieee.std_logic_1164.all;

library work;
use work.ipdbg_interface_pkg.all;

entity WbMaster is
    generic (
        ASYNC_RESET : boolean
    );
    port (
        clk      : in    std_logic;
        rst      : in    std_logic;
        ce       : in    std_logic;

        --      host interface (UART or ....)
        dn_lines : in    ipdbg_dn_lines;
        up_lines : out   ipdbg_up_lines;

        -- wishbone interface
        -- stall_i  : in    std_logic;
        lock_o   : out   std_logic;
        cyc_o    : out   std_logic;
        stb_o    : out   std_logic;
        ack_i    : in    std_logic;
        rty_i    : in    std_logic := '0';
        err_i    : in    std_logic := '0';
        we_o     : out   std_logic;
        adr_o    : out   std_logic_vector;
        sel_o    : out   std_logic_vector;
        dat_o    : out   std_logic_vector;
        dat_i    : in    std_logic_vector
    );
end entity WbMaster;

architecture behavioral of WbMaster is
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

    constant DATA_WIDTH    : positive := dat_o'length;
    constant ADDRESS_WIDTH : natural  := adr_o'length;
    constant STROBE_WIDTH  : natural  := sel_o'length;
    constant MISC_WIDTH    : natural  := 0;

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
    signal   miscellaneous : std_logic_vector(0 downto 0);
    signal   lock          : std_logic;
begin
    assert dat_i'length = dat_o'length
        report "dat_o and dat_i must have the same width"
        severity failure;
    assert DATA_WIDTH mod STROBE_WIDTH = 0
        report "width of dat_i and dat_o must be a multiple of the width of sel_o"
        severity failure;

    adr_o <= address;

    dat_o <= write_data;
    sel_o <= strobe;

    wishbone_control : block
        signal cycstb     : std_logic;
        signal arst, srst : std_logic;
        signal we         : std_logic;
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

        we_o   <= we;
        cyc_o  <= cycstb;
        stb_o  <= cycstb;
        lock_o <= lck;

        process (clk, arst)
            procedure reset_assignments is
            begin
                cycstb       <= '0';
                we           <= '-';
                lck          <= '0';
                read_data    <= (others => '-');
                read_done    <= '0';
                write_done   <= '0';
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
                        if cycstb = '0' then
                            if (start_write or start_read) = '1' then
                                cycstb <= '1';
                                we     <= start_write;
                                if lock = '1' then
                                    lck <= lock;
                                end if;
                            end if;
                        else
                            if (ack_i or rty_i or err_i) = '1' then
                                cycstb <= '0';
                                if we = '0' then
                                    read_done <= '1';
                                else
                                    write_done <= '1';
                                end if;
                                if lock = '0' then
                                    lck <= lock;
                                end if;
                                access_error <= rty_i or err_i;
                            end if;
                        end if;

                        if (ack_i or rty_i or err_i) = '1' and cycstb = '1' then
                            if we = '0' then
                                read_data <= dat_i;
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
            MISC_INIT     => "0"
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
