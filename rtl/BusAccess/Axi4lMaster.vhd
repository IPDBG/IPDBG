library ieee;
use ieee.std_logic_1164.all;

library work;
use work.ipdbg_interface_pkg.all;

entity Axi4lMaster is
    generic (
        ASYNC_RESET : boolean
    );
    port (
        clk      : in    std_logic;
        rst      : in    std_logic;
        ce       : in    std_logic;

        -- host interface (UART or ....)
        dn_lines : in    ipdbg_dn_lines;
        up_lines : out   ipdbg_up_lines;

        -- axi4 light
        -- read address channel
        araddr   : out   std_logic_vector;
        arprot   : out   std_logic_vector(2 downto 0);
        arvalid  : out   std_logic;
        arready  : in    std_logic;
        -- arid     : out   std_logic_vector;             -- ID tag for write transaction
        -- arlen    : out   std_logic_vector(7 downto 0); -- length ((number of transfers) - 1)
        -- arsize   : out   std_logic_vector(2 downto 0); -- data bus width Size (in bytes) of each transfer
        -- arburst  : out   std_logic_vector(1 downto 0); -- Burst type
        -- arlock   : out   std_logic;                    -- Indicates a locked transaction
        -- arcache  : out   std_logic_vector(3 downto 0); -- Indicates caching (and other) properties
        -- arqos    : out   std_logic_vector(3 downto 0); -- Quality of service ID
        -- arregion : out   std_logic_vector(3 downto 0); -- Region indicator
        -- aruser   : out   std_logic_vector;             -- User defined extension

        -- read data channel
        rdata    : in    std_logic_vector;
        rresp    : in    std_logic_vector(1 downto 0);
        rvalid   : in    std_logic;
        rready   : out   std_logic;

        -- write address channel
        awaddr   : out   std_logic_vector;
        awprot   : out   std_logic_vector(2 downto 0);
        awvalid  : out   std_logic;
        awready  : in    std_logic;
        -- awid     : out   std_logic_vector;             -- ID tag for write transaction
        -- awlen    : out   std_logic_vector(7 downto 0); -- length ((number of transfers) - 1)
        -- awsize   : out   std_logic_vector(2 downto 0); -- data bus width (in bytes) of each transfer
        -- awburst  : out   std_logic_vector(1 downto 0); -- Burst type
        -- awlock   : out   std_logic;                    -- Indicates a locked transaction
        -- awcache  : out   std_logic_vector(3 downto 0); -- Indicates caching (and other) properties
        -- awqos    : out   std_logic_vector(3 downto 0); -- Quality of service ID
        -- awregion : out   std_logic_vector(3 downto 0); -- Region indicator
        -- awuser   : out   std_logic_vector;             -- User defined extension

        -- write data channel
        wdata    : out   std_logic_vector; -- 32 or 64 bits wide
        wstrb    : out   std_logic_vector;
        wvalid   : out   std_logic;
        wready   : in    std_logic;

        -- write response channel
        bresp    : in    std_logic_vector(1 downto 0);
        bvalid   : in    std_logic;
        bready   : out   std_logic
    );
end entity Axi4lMaster;

architecture behavioral of Axi4lMaster is
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

    constant DATA_WIDTH    : positive := rdata'length;
    constant ADDRESS_WIDTH : natural  := araddr'length;
    constant STROBE_WIDTH  : natural  := wstrb'length;

    constant RESP_OKAY     : std_logic_vector(1 downto 0) := "00";
    constant RESP_EXOKAY   : std_logic_vector(1 downto 0) := "01";
    constant RESP_SLVERR   : std_logic_vector(1 downto 0) := "10";
    constant RESP_DECERR   : std_logic_vector(1 downto 0) := "11";

    constant MISC_WIDTH    : natural                                   := arprot'length + awprot'length;
    constant MISC_INIT     : std_logic_vector(MISC_WIDTH - 1 downto 0) := "000" & "000";

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
    assert wdata'length = rdata'length
        report "rdata and wdata must have the same width"
        severity failure;
    assert awaddr'length = araddr'length
        report "araddr and awaddr must have the same width"
        severity failure;
    assert DATA_WIDTH = 32 or DATA_WIDTH = 64
        report "rdata and wdata must be 32 or 64 bits wide"
        severity failure;
    assert STROBE_WIDTH * 8 = DATA_WIDTH
        report "wstrb must be 1/8th of the width of wdata"
        severity failure;

    araddr <= address;
    arprot <= miscellaneous(arprot'length - 1 downto 0);

    awaddr <= address;
    awprot <= miscellaneous(awprot'length - 1 + arprot'length downto arprot'length);

    wdata <= write_data;
    wstrb <= strobe;

    axi4l_control : block
        type   states is (idle, writing, reading);
        signal state      : states;
        signal rready_r   : std_logic;
        signal arst, srst : std_logic;
    begin
        async_init : if ASYNC_RESET generate begin
            arst <= reset;
            srst <= '0';
        end generate async_init;
        sync_init : if not ASYNC_RESET generate begin
            arst <= '0';
            srst <= reset;
        end generate sync_init;

        rready <= rready_r;

        process (clk, arst)
            procedure reset_assignments is
            begin
                awvalid      <= '0';
                wvalid       <= '0';
                bready       <= '0';
                arvalid      <= '0';
                rready_r     <= '0';
                state        <= idle;
                read_data    <= (others => '-');
                write_done   <= '0';
                read_done    <= '0';
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
                        if arready = '1' then
                            arvalid <= '0';
                        end if;
                        if rvalid = '1' then
                            rready_r <= '0';
                        end if;

                        if awready = '1' then
                            awvalid <= '0';
                        end if;
                        if wready = '1' then
                            wvalid <= '0';
                        end if;
                        if bvalid = '1' then
                            bready <= '0';
                        end if;

                        write_done   <= '0';
                        read_done    <= '0';
                        access_error <= '0';
                        case state is
                        when idle =>
                            if start_write = '1' then
                                bready  <= '1';
                                awvalid <= '1';
                                wvalid  <= '1';
                                state   <= writing;
                            elsif start_read = '1' then
                                arvalid  <= '1';
                                rready_r <= '1';
                                state    <= reading;
                            end if;
                        when writing =>
                            if bvalid = '1' then
                                if bresp /= RESP_OKAY then
                                    access_error <= '1';
                                end if;
                                state      <= idle;
                                write_done <= '1';
                            end if;
                        when reading =>
                            if rvalid = '1' then
                                if rresp /= RESP_OKAY then
                                    access_error <= '1';
                                end if;
                                state     <= idle;
                                read_done <= '1';
                            end if;
                        end case;

                        if rvalid = '1' and rready_r = '1' then
                            read_data <= rdata;
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
