library ieee;
use ieee.std_logic_1164.all;

library work;
use work.ipdbg_interface_pkg.all;

entity ApbMaster is
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

        -- apb interface
        -- unsupported signals:
        -- pwakeup  : out   std_logic;
        -- pauser   : out   std_logic_vector;
        -- pwuser   : out   std_logic_vector;
        -- pruser   : in    std_logic_vector;
        -- pbuser   : in    std_logic_vector
        paddr    : out   std_logic_vector; -- max 32 bits
        pwrite   : out   std_logic;
        pwdata   : out   std_logic_vector; -- max 32 bits
        prdata   : in    std_logic_vector; -- max 32 bits
        psel     : out   std_logic;        -- split externally based on addresses
        penable  : out   std_logic;
        pready   : in    std_logic;        -- connect to penable when not available from completer
        pslverr  : in    std_logic;
        pprot    : out   std_logic_vector(2 downto 0);
        pstrb    : out   std_logic_vector
    );
end entity ApbMaster;

architecture behavioral of ApbMaster is
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

    constant DATA_WIDTH    : positive := pwdata'length;
    constant ADDRESS_WIDTH : natural  := paddr'length;
    constant STROBE_WIDTH  : natural  := pstrb'length;

    -- initilaize pprot with "000" -> normal, secure, data:
    constant MISC_WIDTH    : natural                                   := pprot'length;
    constant MISC_INIT     : std_logic_vector(MISC_WIDTH - 1 downto 0) := (others => '0');

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
    signal   miscellaneous : std_logic_vector(MISC_WIDTH - 1 downto 0);
begin
    assert pwdata'length = prdata'length
        report "pwdata and prdata must have the same width"
        severity failure;
    assert DATA_WIDTH = 32 or DATA_WIDTH = 16 or DATA_WIDTH = 8
        report "pwdata and prdata must have a width of 8, 16 or 32 bits."
        severity failure;
    assert ADDRESS_WIDTH <= 32
        report "AMBA APB address bus can be up to 32 bits wide."
        severity failure;
    assert STROBE_WIDTH * 8 = DATA_WIDTH
        report "The width of pstrb must be 1/8th of the width of pwdata"
        severity failure;

    paddr  <= address;
    pwdata <= write_data;
    pprot  <= miscellaneous;

    apb_control : block
        signal arst, srst : std_logic;
        signal we         : std_logic;
        signal sel        : std_logic;
        signal enable     : std_logic;
    begin
        async_init : if ASYNC_RESET generate begin
            arst <= reset;
            srst <= '0';
        end generate async_init;
        sync_init : if not ASYNC_RESET generate begin
            arst <= '0';
            srst <= reset;
        end generate sync_init;

        pwrite  <= we;
        psel    <= sel;
        penable <= enable;

        process (clk, arst)
            procedure reset_assignments is
            begin
                we           <= '-';
                enable       <= '-';
                sel          <= '0';
                read_data    <= (others => '-');
                read_done    <= '0';
                write_done   <= '0';
                access_error <= '-';
                pstrb        <= (pstrb'range => '-');
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
                        if sel = '0' then
                            if start_write = '1' then
                                we  <= '1';
                                sel <= '1';
                                if STROBE_WIDTH = 1 then
                                    pstrb <= "1";
                                else
                                    pstrb <= strobe;
                                end if;
                            elsif start_read = '1' then
                                we    <= '0';
                                sel   <= '1';
                                pstrb <= (pstrb'range => '0');
                            end if;
                            enable <= '0';
                        else
                            enable <= '1';
                            if (pready and enable) = '1' then
                                enable <= '0';
                                sel    <= '0';
                                if we = '0' then
                                    read_done <= '1';
                                else
                                    write_done <= '1';
                                end if;
                            end if;
                        end if;

                        if pready = '1' and enable = '1' then
                            if we = '0' then
                                read_data <= prdata;
                            end if;
                            access_error <= pslverr;
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
            lock          => open
        );
end architecture behavioral;
