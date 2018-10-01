library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity LogicAnalyserMemory is
    generic(
         DATA_WIDTH  : natural := 8;
         ADDR_WIDTH  : natural := 8;
         ASYNC_RESET : boolean := true
    );
    port(
        clk               : in  std_logic;
        rst               : in  std_logic;
        ce                : in  std_logic;

        sample_enable     : in  std_logic;
        probe             : in  std_logic_vector(DATA_WIDTH-1 downto 0);

        -- control sampling
        trigger_active    : in  std_logic;
        trigger           : in  std_logic;
        full              : out std_logic;
        delay             : in  std_logic_vector(ADDR_WIDTH-1 downto 0);

        --Read
        data              : out std_logic_vector(DATA_WIDTH-1 downto 0) ;
        data_valid        : out std_logic;
        data_request_next : in  std_logic;

        finish            : out std_logic
    );
end entity LogicAnalyserMemory;


architecture tab of LogicAnalyserMemory is

    component PdpRam is
        generic(
            DATA_WIDTH     : natural;
            ADDR_WIDTH     : natural;
            OUTPUT_REG     : boolean
        );
        port(
            clk           : in  std_logic;
            ce            : in  std_logic;
            write_enable  : in  std_logic;
            write_address : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
            write_data    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            read_address  : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
            read_data     : out std_logic_vector(DATA_WIDTH-1 downto 0)
        );
    end component PdpRam;

    signal counter           : unsigned(ADDR_WIDTH-1 downto 0);
    signal data_ready        : unsigned(1 downto 0);
    signal write_enable      : std_logic;

    constant counter_maximum : unsigned(ADDR_WIDTH-1 downto 0) := (others => '1');
    constant counter_minimum : unsigned(ADDR_WIDTH-1 downto 0) := (others => '0');

    --State machine
    type states_t            is(idle, armed, wait_trigger, fill_up, drain, drain_handshake);
    signal buffering_state   : states_t;

    signal write_data        : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal read_data         : std_logic_vector(DATA_WIDTH-1 downto 0):= (others => '0');

    signal write_address     : unsigned(ADDR_WIDTH-1 downto 0);
    signal read_address      : unsigned(ADDR_WIDTH-1 downto 0);

    signal delay_s           : unsigned(ADDR_WIDTH-1 downto 0);

    signal arst, srst        : std_logic;
begin
    async_init: if ASYNC_RESET generate begin
        arst <= rst;
        srst <= '0';
    end generate async_init;
    sync_init: if not ASYNC_RESET generate begin
        arst <= '0';
        srst <= rst;
    end generate sync_init;

    process (clk, arst)
        procedure assign_reset is begin
            buffering_state <= idle;
            write_enable <= '0';
            counter <= (others => '-');
            data_ready <= (others => '-');
            write_data <= (others => '-');
            write_address <= (others => '-');
            read_address <= (others => '-');
            full <= '0';
            data_valid <= '0';
            finish <= '0';
            delay_s <= (others => '-');
        end procedure assign_reset;
    begin
        if arst = '1' then
            assign_reset;
        elsif rising_edge(clk) then
            if srst = '1' then
                assign_reset;
            else
                if ce = '1' then
                    write_enable <= '0';
                    write_data <= probe;

                    if sample_enable = '1' then
                        write_address <= to_01(write_address) + 1;
                    end if;

                    case buffering_state is
                    when idle =>
                        finish <= '0';
                        counter <= (others => '0');
                        full <= '0';
                        delay_s <= unsigned(delay);
                        if trigger_active = '1' then -- wait until trigger is active
                            buffering_state <= armed;
                        end if;

                    when armed =>
                        if sample_enable = '1' then
                            write_enable <= '1';
                            counter <= counter + 1;
                            if counter = delay_s then -- ignoring trigger to fill buffer to requested minimum
                                buffering_state <= wait_trigger ;
                            end if;
                        end if;

                    when wait_trigger =>
                        if sample_enable = '1' then
                            write_enable <= '1';
                            if trigger = '1' then
                                buffering_state <= fill_up;
                                counter <= counter + 1;
                            end if;
                        end if;

                    when fill_up =>
                        if sample_enable = '1' then
                            write_enable <= '1';
                            counter <= counter + 1;
                            if counter = counter_maximum  then
                                read_address <= write_address + 1;
                                buffering_state <= drain;
                                full <= '1';
                            end if;
                        end if;
                        data_ready <= (others => '0');

                    when drain =>
                        if data_request_next = '1' then
                            if data_ready = to_unsigned(3, data_ready'length) then
                                data_valid <= '1';
                                counter <= counter - 1;
                                data <= read_data;
                                buffering_state <= drain_handshake;
                                data_ready <= (others => '0');
                            else
                                data_ready <= data_ready + 1;
                            end if;
                        end if;

                    when drain_handshake =>
                        if data_request_next = '0' then
                            data_valid <= '0';
                            read_address <= read_address + 1;
                            if counter = counter_minimum then
                                buffering_state <= idle;
                                finish <= '1';
                            else
                                buffering_state <= drain;
                            end if;
                        end if;
                        data_ready <= (others => '0');
                    end case;
                    if trigger_active = '0' then
                        buffering_state <= idle;
                    end if;
                end if; -- ce
            end if;
        end if;
    end process;

    mem: block
        signal write_address_slv : std_logic_vector(ADDR_WIDTH-1 downto 0);
        signal read_address_slv  : std_logic_vector(ADDR_WIDTH-1 downto 0);
        signal write_enable_dly  : std_logic;
        signal write_data_dly    : std_logic_vector(write_data'range);
    begin

        process (clk) begin
            if rising_edge(clk) then
                if ce = '1' then
                    write_enable_dly  <= write_enable;
                    write_address_slv <= std_logic_vector(write_address);
                    write_data_dly    <= write_data;
                    read_address_slv  <= std_logic_vector(to_01(read_address));
                end if;
            end if;
        end process;

        probes : component PdpRam
            generic map(
                DATA_WIDTH     => DATA_WIDTH,
                ADDR_WIDTH     => ADDR_WIDTH,
                OUTPUT_REG     => true
            )
            port map(
                clk           => clk,
                ce            => ce,
                write_enable  => write_enable_dly,
                write_address => write_address_slv,
                write_data    => write_data_dly,
                read_address  => read_address_slv,
                read_data     => read_data
            );
    end block mem;


end architecture tab;

