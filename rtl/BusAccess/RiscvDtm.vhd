library ieee;
use ieee.std_logic_1164.all;

library work;
use work.ipdbg_interface_pkg.all;

entity RiscvDtm is
    generic (
        ASYNC_RESET : boolean
    );
    port (
        clk          : in    std_logic;
        rst          : in    std_logic;
        ce           : in    std_logic;

        --      host interface (UART or ....)
        dn_lines     : in    ipdbg_dn_lines;
        up_lines     : out   ipdbg_up_lines;

        -- debug interface bus
        op           : out   std_logic_vector(1 downto 0);
        write_req    : out   std_logic;
        read_req     : out   std_logic;

        address      : out   std_logic_vector;
        write_data   : out   std_logic_vector(31 downto 0);
        read_data    : in    std_logic_vector(31 downto 0);
        ack          : in    std_logic;
        dmireset     : out   std_logic;
        dmihardreset : out   std_logic
    );
end entity RiscvDtm;

architecture behavioral of RiscvDtm is
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

    constant DATA_WIDTH    : positive := read_data'length;
    constant ADDRESS_WIDTH : natural  := address'length;
    constant STROBE_WIDTH  : natural  := 0;
    constant MISC_WIDTH    : natural  := 2;

    signal   reset         : std_logic;
    signal   read_data_r   : std_logic_vector(DATA_WIDTH - 1 downto 0);
    signal   strobe        : std_logic_vector(0 downto 0);
    signal   start_write   : std_logic;
    signal   start_read    : std_logic;
    signal   write_done    : std_logic;
    signal   read_done     : std_logic;
    signal   miscellaneous : std_logic_vector(1 downto 0);
    alias    hradreset     : std_logic is miscellaneous(1);
begin
    assert read_data'length = write_data'length
        report "read_data and write_data must have the same width"
        severity failure;

    assert address'length >= 7 and address'length <= 32
        report "Number of DMI address bits N must be 7 <= N <= 32"
        severity error; -- don't break here.

    dmireset     <= miscellaneous(0);
    dmihardreset <= hradreset;

    wishbone_control : block
        signal   arst, srst : std_logic;
        signal   busy       : std_logic;
        signal   operation  : std_logic_vector(1 downto 0);
        constant OP_READ    : std_logic_vector(1 downto 0) := "01";
        constant OP_WRITE   : std_logic_vector(1 downto 0) := "10";
        constant OP_NOOP    : std_logic_vector(1 downto 0) := "00";
    begin
        async_init : if ASYNC_RESET generate begin
            arst <= reset;
            srst <= '0';
        end generate async_init;
        sync_init : if not ASYNC_RESET generate begin
            arst <= '0';
            srst <= reset;
        end generate sync_init;

        op <= operation;

        process (clk, arst)
            procedure reset_assignments is
            begin
                busy        <= '0';
                operation   <= OP_NOOP;
                write_req   <= '0';
                read_req    <= '0';
                read_data_r <= (others => '-');
                read_done   <= '0';
                write_done  <= '0';
            end procedure;
        begin
            if arst = '1' then
                reset_assignments;
            elsif rising_edge(clk) then
                if srst = '1' or hradreset = '1' then
                    reset_assignments;
                else
                    if ce = '1' then
                        read_done  <= '0';
                        write_done <= '0';
                        if operation = OP_NOOP then
                            if start_write = '1' then
                                operation <= OP_WRITE;
                                busy      <= '1';
                                write_req <= '1';
                            elsif start_read = '1' then
                                operation <= OP_READ;
                                busy      <= '1';
                                read_req  <= '1';
                            end if;
                        else
                            if ack = '1' then
                                write_req <= '0';
                                read_req  <= '0';
                                if operation = OP_READ then
                                    read_done   <= '1';
                                    read_data_r <= read_data;
                                else
                                    write_done <= '1';
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
            read_data     => read_data_r,
            write_data    => write_data,
            strobe        => strobe,
            miscellaneous => miscellaneous,
            start_write   => start_write,
            start_read    => start_read,
            write_done    => write_done,
            read_done     => read_done,
            access_error  => '0',
            lock          => open
        );
end architecture behavioral;
