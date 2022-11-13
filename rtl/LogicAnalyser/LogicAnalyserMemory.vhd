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
        generic
        (
            OUTPUT_REG     : boolean
        );
        port
        (
            clk           : in  std_logic;
            ce            : in  std_logic;
            write_enable  : in  std_logic;
            write_address : in  std_logic_vector;
            write_data    : in  std_logic_vector;
            read_address  : in  std_logic_vector;
            read_data     : out std_logic_vector
        );
    end component PdpRam;

    signal counter               : unsigned(ADDR_WIDTH downto 0);
    signal data_ready            : unsigned(1 downto 0);
    signal write_enable          : std_logic;

    constant counter_maximum     : unsigned(counter'range) := to_unsigned(2**ADDR_WIDTH, ADDR_WIDTH+1);
    constant counter_minimum     : unsigned(counter'range) := (others => '0');
    constant counter_nearmax_val : unsigned(counter'range) := to_unsigned(2**ADDR_WIDTH-2, ADDR_WIDTH+1);

    --State machine
    type states_t                is(idle, armed, wait_trigger, fill_up, drain, drain_handshake, wait_ack_finish);
    signal buffering_state       : states_t;

    signal write_data            : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal read_data             : std_logic_vector(DATA_WIDTH-1 downto 0);

    signal write_address         : unsigned(ADDR_WIDTH-1 downto 0);
    signal read_address          : unsigned(ADDR_WIDTH-1 downto 0);

    signal delay_s               : unsigned(ADDR_WIDTH - 1 downto 0);

    signal counter_near_max      : std_logic; --near means max -1
    signal counter_near_delay    : std_logic; --near means delay_s -1

    signal arst, srst            : std_logic;
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
            counter_near_max <= '-';
            counter_near_delay <= '-';
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

                    if sample_enable = '1' then
                        write_address <= to_01(write_address) + 1;
                        write_data <= probe;
                    end if;

                    case buffering_state is
                    when idle =>
                        finish <= '0';
                        counter <= (others => '0');
                        full <= '0';
                        delay_s <= to_01(unsigned(delay));
                        counter_near_max <= '0';
                        if trigger_active = '1' then -- wait until trigger is active
                            --report "delay is " & integer'image(to_integer(unsigned(delay)));
                            if unsigned('0' & delay) = counter_minimum then
                                buffering_state <= wait_trigger;
                            else
                                buffering_state <= armed;
                            end if;
                        end if;
                        data_ready <= (others => '0');
                        if to_01(unsigned(delay)) = 1 then
                            counter_near_delay <= '1';
                        else
                            counter_near_delay <= '0';
                        end if;

                    when armed =>
                        if sample_enable = '1' then
                            write_enable <= '1';
                            counter_near_max <= '0';
                            counter <= counter + 1;
                            counter_near_delay <= '0';
                            if counter_near_delay = '1' then -- ignoring trigger to fill buffer to requested minimum
                                buffering_state <= wait_trigger;
                            end if;
                            if counter = counter_nearmax_val then
                                counter_near_max <= '1';
                            end if;
                            if counter + 2 = ('0' & delay_s) then
                                counter_near_delay <= '1';
                            else
                                counter_near_delay <= '0';
                            end if;
                        end if;

                    when wait_trigger =>
                        if sample_enable = '1' then
                            write_enable <= '1';
                            counter_near_max <= counter_near_max;
                            if trigger = '1' then
                                counter <= counter + 1;
                                if counter_near_max = '1' then
                                    read_address <= write_address + 2;
                                    buffering_state <= drain;
                                    full <= '1';
                                else
                                    buffering_state <= fill_up;
                                end if;
                                if counter = counter_nearmax_val then
                                    counter_near_max <= '1';
                                end if;
                            end if;
                        end if;

                    when fill_up =>
                        if sample_enable = '1' then
                            counter_near_max <= '0';
                            write_enable <= '1';
                            counter <= counter + 1;
                            if counter_near_max = '1' then
                                read_address <= write_address + 2;
                                buffering_state <= drain;
                                full <= '1';
                            end if;
                            if counter = counter_nearmax_val then
                                counter_near_max <= '1';
                            end if;
                        end if;

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
                                buffering_state <= wait_ack_finish;
                                finish <= '1';
                            else
                                buffering_state <= drain;
                            end if;
                        end if;
                        data_ready <= (others => '0');
                    when wait_ack_finish =>
                        -- finish has been pulsed, wait until trigger_active = '0'
                        if trigger_active = '0' then
                            buffering_state <= idle;
                        end if;
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
            generic map
            (
                OUTPUT_REG     => true
            )
            port map
            (
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
