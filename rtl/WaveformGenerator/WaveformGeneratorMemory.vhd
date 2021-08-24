library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity WaveformGeneratorMemory is
    generic(
        DATA_WIDTH    : natural := 8;
        ADDR_WIDTH    : natural := 8;
        ASYNC_RESET   : boolean := true;
        DOUBLE_BUFFER : boolean := false;
        SYNC_MASTER   : boolean := true
    );
    port(
        clk                   : in  std_logic;
        rst                   : in  std_logic;
        ce                    : in  std_logic;

        -- write
        data_samples          : in  std_logic_vector(DATA_WIDTH-1 downto 0);     -- from controller
        data_samples_valid    : in  std_logic;                                   -- from controller
        data_samples_if_reset : in  std_logic;                                   -- from controller
        data_samples_last     : in  std_logic;

        start                 : in  std_logic;                                   -- from controller
        stop                  : in  std_logic;                                   -- from controller

        enabled               : out std_logic;
        data_out              : out std_logic_vector(DATA_WIDTH-1 downto 0);     -- THE output
        first_sample          : out std_logic;                                   -- THE output
        data_out_enable       : in  std_logic := '1';                            -- timing for output
        one_shot              : in  std_logic;
        sync_out              : out std_logic;
        sync_in               : in  std_logic
    );
end entity WaveformGeneratorMemory;


architecture behavioral of WaveformGeneratorMemory is

    component PdpRam is
        generic
        (
            OUTPUT_REG     : boolean
        );
        port
        (
            clk           : in  std_logic;
            ce            : in  std_logic;
            write_Enable  : in  std_logic;
            write_Address : in  std_logic_vector;
            write_Data    : in  std_logic_vector;
            read_Address  : in  std_logic_vector;
            read_Data     : out std_logic_vector
        );
    end component PdpRam;

    constant RAM_OUTPUT_REG    : boolean := true;

    signal first_sample_s      : std_logic;

    signal read_address        : unsigned(ADDR_WIDTH-1 downto 0);
    signal read_data           : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal read_data_b2        : std_logic_vector(DATA_WIDTH-1 downto 0);

    signal write_enable        : std_logic;
    signal write_enable_b2     : std_logic;
    signal write_data          : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal write_address       : unsigned(ADDR_WIDTH-1 downto 0);
    signal arst, srst          : std_logic;

    signal data_samples_last_d : std_logic;

    signal next_rd_buffer      : std_logic;
    signal next_rd_stb         : std_logic;
    signal next_rd_addr_last   : unsigned(ADDR_WIDTH-1 downto 0);

    signal current_rd_buffer_s : std_logic;

begin
    async_init: if ASYNC_RESET generate begin
        arst <= rst;
        srst <= '0';
    end generate async_init;
    sync_init: if not ASYNC_RESET generate begin
        arst <= '0';
        srst <= rst;
    end generate sync_init;

    writeFsm: block
        signal we_com        : std_logic;
        signal curr_w_buffer : bit;
    begin
        process (clk) begin
            if rising_edge(clk) then
                if ce = '1' then
                    write_enable <= '0';
                    write_enable_b2 <= '0';
                    if data_samples_if_reset = '1' then
                        write_address <= (others => '0');
                        curr_w_buffer <= not curr_w_buffer;
                    elsif we_com = '1' then
                        write_address <= to_01(write_address) + 1;
                    end if;

                    if data_samples_valid = '1' then
                        data_samples_last_d <= data_samples_last;
                        if not DOUBLE_BUFFER or curr_w_buffer = '0' then
                            write_enable <= '1';
                        else
                            write_enable_b2 <= '1';
                        end if;
                    end if;
                    write_data <= data_samples;


                    next_rd_stb <= '0';
                    if we_com = '1' and data_samples_last_d = '1' then
                        if curr_w_buffer = '1' then
                            next_rd_buffer <= '1';
                        else
                            next_rd_buffer <= '0';
                        end if;
                        next_rd_addr_last <= write_address;
                        next_rd_stb <= '1';
                    end if;

                end if;
            end if;
        end process;

        db: if DOUBLE_BUFFER generate begin
            we_com <= write_enable or write_enable_b2;
        end generate;
        sb: if not DOUBLE_BUFFER generate begin
            we_com <= write_enable;
        end generate;

    end block;

    mem: block
        signal write_address_slv : std_logic_vector(ADDR_WIDTH-1 downto 0);
        signal read_address_slv  : std_logic_vector(ADDR_WIDTH-1 downto 0);
    begin

        write_address_slv <= std_logic_vector(write_address);
        read_address_slv  <= std_logic_vector(read_address);

        samples : component PdpRam
            generic map
            (
                OUTPUT_REG     => RAM_OUTPUT_REG
            )
            port map
            (
                clk           => clk,
                ce            => ce,
                write_enable  => write_enable,
                write_address => write_address_slv,
                write_data    => write_data,
                read_address  => read_address_slv,
                read_data     => read_data
            );

        mem2: if DOUBLE_BUFFER generate begin
            samples2 : component PdpRam
                generic map
                (
                    OUTPUT_REG     => RAM_OUTPUT_REG
                )
                port map
                (
                    clk           => clk,
                    ce            => ce,
                    write_enable  => write_enable_b2,
                    write_address => write_address_slv,
                    write_data    => write_data,
                    read_address  => read_address_slv,
                    read_data     => read_data_b2
                );
        end generate;
    end block mem;

    readFsm: block
        type state_t                    is (idle, running, oneshot, wait_sync);
        signal state                    : state_t;
        signal first_address_set        : std_logic;
        signal first_address_set_d      : std_logic;

        signal addr_of_last_sample      : unsigned(ADDR_WIDTH-1 downto 0);
        signal addr_of_last_sample_next : unsigned(ADDR_WIDTH-1 downto 0);
        signal buffer_next              : std_logic;
        signal current_rd_buffer        : std_logic;
        signal current_rd_buffer_d      : std_logic;

        signal set_enable               : std_logic;
        signal enabled_d                : std_logic;
        signal enabled_s                : std_logic;

        signal start_latched            : std_logic;
        signal stop_latched             : std_logic;
        signal one_shot_latched         : std_logic;
        signal sync_out_local           : std_logic;
    begin
        sync_out <= sync_out_local;

        process (clk, arst)
            procedure assign_reset is begin
                read_address <= (others => '-');
                first_sample_s <= '0';
                first_address_set <= '0';
                first_address_set_d <= '0';
                current_rd_buffer_s <= '0';
                current_rd_buffer_d <= '0';
                current_rd_buffer   <= '0';
                buffer_next <= '0';
                addr_of_last_sample_next <= (others => '-');

                first_sample <= '-';
                data_out <= (others => '-');
                enabled <= '0';
                set_enable <= '0';
                enabled_d <= '0';
                enabled_s <= '0';
                sync_out_local <= '0';
            end procedure assign_reset;
        begin
            if arst = '1' then
                assign_reset;
            elsif rising_edge(clk) then
                 if srst = '1' then
                    assign_reset;
                else
                    if ce = '1' then

                        if next_rd_stb = '1' then
                            buffer_next <= next_rd_buffer;
                            addr_of_last_sample_next <= next_rd_addr_last;
                        end if;


                        if data_out_enable = '1' then
                            start_latched <= '0';
                        elsif start = '1' then
                            start_latched <= '1';
                        end if;
                        if data_out_enable = '1' then
                            stop_latched <= '0';
                        elsif stop = '1' then
                            stop_latched <= '1';
                        end if;
                        if data_out_enable = '1' then
                            one_shot_latched <= '0';
                        elsif one_shot = '1' then
                            one_shot_latched <= '1';
                        end if;


                        if data_out_enable = '1' then
                            sync_out_local <= '0';
                            first_address_set <= '0';
                            read_address <= to_01(read_address) + 1;
                            case state is
                            when idle =>
                                read_address <= (others => '0');
                                current_rd_buffer <= buffer_next;
                                addr_of_last_sample <= to_01(addr_of_last_sample_next);
                                set_enable <= '0';
                                if (one_shot_latched or one_shot) = '1' then
                                    state <= oneshot;
                                    first_address_set <= '1';
                                    set_enable <= '1';
                                elsif (start_latched or start) = '1' then
                                    if SYNC_MASTER then
                                        state <= running;
                                        first_address_set <= '1';
                                        set_enable <= '1';
                                    else
                                        state <= wait_sync;
                                    end if;
                                end if;
                            when wait_sync =>
                                read_address <= (others => '0');
                                current_rd_buffer <= buffer_next;
                                addr_of_last_sample <= to_01(addr_of_last_sample_next);
                                set_enable <= '0';
                                if sync_in = '1' then
                                    state <= running;
                                    first_address_set <= '1';
                                    set_enable <= '1';
                                end if;
                            when running =>
                                if to_01(read_address) + 1 = to_01(addr_of_last_sample) then
                                    sync_out_local <= '1';
                                end if;
                                if sync_out_local = '1' then
                                    read_address <= (others => '0');
                                    first_address_set <= '1';
                                    current_rd_buffer <= buffer_next;
                                    addr_of_last_sample <= to_01(addr_of_last_sample_next);
                                end if;
                                if (stop_latched or stop) = '1' then
                                    state <= idle;
                                    set_enable <= '0';
                                end if;
                            when oneshot =>
                                if to_01(read_address) = to_01(addr_of_last_sample) then
                                    state <= idle;
                                    set_enable <= '0';
                                end if;
                            end case;
                        end if;


                        -- This is depending on the timing of the pdpRam. (i.e. we have a strong coupling to the pdpRam)
                        -- An alternative solution was to spend an additional bit of the waveform - a big waste.
                        -- So we live with this coupling.
                        first_address_set_d <= first_address_set;
                        current_rd_buffer_d <= current_rd_buffer;
                        enabled_d           <= set_enable;
                        if RAM_OUTPUT_REG then
                            first_sample_s      <= first_address_set_d;
                            current_rd_buffer_s <= current_rd_buffer_d;
                            enabled_s           <= enabled_d;
                        else
                            first_sample_s      <= first_address_set;
                            current_rd_buffer_s <= current_rd_buffer;
                            enabled_s           <= set_enable;
                        end if;


                        if data_out_enable = '1' then
                            enabled <= enabled_s;
                            first_sample <= first_sample_s;
                            if enabled_s = '1' then
                                if current_rd_buffer_s = '0' or not DOUBLE_BUFFER then
                                    data_out <= read_data;
                                else
                                    data_out <= read_data_b2;
                                end if;
                            else
                                data_out <= (others => '0');
                            end if;
                        end if;
                    end if;
                end if;
            end if;
        end process;
    end block;

end architecture behavioral;
