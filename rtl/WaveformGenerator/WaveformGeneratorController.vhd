library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity WaveformGeneratorController is
    generic(
        DATA_WIDTH           : natural := 8;
        ADDR_WIDTH           : natural := 8
    );
    port(
        clk                  : in  std_logic;
        rst                  : in  std_logic;
        ce                   : in  std_logic;

        ----------------HOST INTERFACE-----------------------
        data_dwn_valid        : in  std_logic;
        data_dwn              : in  std_logic_vector(7 downto 0);
        data_up_ready         : in  std_logic;
        data_up_valid         : out std_logic;
        data_up               : out std_logic_vector(7 downto 0);

        ---------------Signals from the memory --------------
        data_samples          : out std_logic_vector(DATA_WIDTH-1 downto 0);
        data_samples_valid    : out std_logic;
        data_samples_if_reset : out std_logic;
        enable                : out std_logic;
        addr_of_last_sample   : out std_logic_vector(ADDR_WIDTH-1 downto 0)
    );
end entity WaveformGeneratorController;


architecture tab of WaveformGeneratorController is
    constant HOST_WORD_SIZE : natural := 8;

    constant data_size      : natural := (DATA_WIDTH + HOST_WORD_SIZE - 1)/ HOST_WORD_SIZE;                   -- Berechnung wie oft dass Mask, Value, Mask_last und Value_last eingelesen werden muessen.
    constant addr_size      : natural := (ADDR_WIDTH + HOST_WORD_SIZE - 1)/ HOST_WORD_SIZE;                   -- Berechnung wie oft, dass das Delay fuer das Memory eingelesen werden muss.
    constant DATA_WIDTH_slv : std_logic_vector(31 downto 0) := std_logic_vector(to_unsigned(DATA_WIDTH, 32)); -- DATA_WIDTH_slv = Wert der uebertragung des DATA_WIDTH
    constant ADDR_WIDTH_slv : std_logic_vector(31 downto 0) := std_logic_vector(to_unsigned(ADDR_WIDTH, 32)); -- DATA_WIDTH_slv = Wert der uebertragung des DATA_WIDTH


    -----------------------Befehle WaveformGenerator -----------------------
    constant start_command                  :std_logic_vector := "11110000"; --F0
    constant stop_command                   :std_logic_vector := "11110001"; --F1
    constant return_sizes_command           :std_logic_vector := "11110010"; --F2
    constant write_samples_command          :std_logic_vector := "11110011"; --F3
    constant set_numberofsamples_command    :std_logic_vector := "11110100"; --F4

    -----------------------state machines
    type states_t is(init, set_stop, set_start, set_numberofsamples, write_samples, return_sizes);
    signal state : states_t :=  init;

    type Output is(init, Zwischenspeicher, shift, get_next_data);
    signal init_Output    : Output := init;

    signal data_size_s                      : natural range 0 to data_size;
    signal addr_size_s                      : natural range 0 to data_size;
    signal enable_s                         : std_logic;
    signal data_samples_valid_early         : std_logic;
    signal setted_numberofsamples_early     : std_logic;
    signal counter                          : unsigned(ADDR_WIDTH-1 downto 0);
    signal import_ADDR                      : std_logic := '0';
    signal sizes_temporary                  : std_logic_vector(31 downto 0);
    signal data_out_s                       : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal sample_counter                   : unsigned(ADDR_WIDTH-1 downto 0):= (others => '0');
    signal addr_of_last_sample_s            : std_logic_vector(ADDR_WIDTH-1 downto 0);
    signal setted_numberofsamples           : std_logic;
    signal set_addroflastsample_next_byte   : std_logic;
    signal set_dataouts_next_byte    		: std_logic;
    signal data_dwn_delayed          		: std_logic_vector(7 downto 0);

begin


    process (clk, rst) begin

        if rst = '1' then
            data_size_s                     <= 0;
            state                           <= init;
            init_Output                     <= init;
            sizes_temporary                 <= (others => '-');
            counter                         <= (others => '-');
            import_ADDR                     <= '0';
            data_up                         <= (others => '-');
            data_up_valid                   <= '0';
            addr_of_last_sample_s           <= (others => '-');
            sample_counter                  <= (others => '-');
            data_out_s                      <= (others => '-');
            data_samples_valid              <= '0';
            enable_s                        <= '0';
            enable                          <= '0';
            setted_numberofsamples          <= '0';
            data_samples_if_reset           <= '-';
            data_dwn_delayed                <= (others => '-');
            set_addroflastsample_next_byte  <= '0';
            set_dataouts_next_byte          <= '0';
            setted_numberofsamples_early    <= '0';
            data_samples_valid_early        <= '0';
        elsif rising_edge(clk) then
            if ce = '1' then
                data_dwn_delayed <= data_dwn;
                data_samples_valid <= '0';
                data_samples_valid_early <= '0';
                data_samples_if_reset <= '0';
                set_addroflastsample_next_byte <= '0';
                set_dataouts_next_byte <= '0';
                case state is
                when init =>
                    if data_dwn_valid = '1' then
                        if data_dwn = start_command then
                            state <= set_start;
                        end if ;
                        if data_dwn = stop_command then
                            state <= set_stop;
                        end if ;
                        if data_dwn = return_sizes_command then
                            counter <= (others => '0');
                            sizes_temporary <= (others => '0');
                            import_ADDR <= '0';
                            state <= return_sizes;
                            init_Output <= init;
                        end if ;
                        if data_dwn = write_samples_command then
                            data_samples_if_reset <= '1';
                            sample_counter <= (others => '0');
                            data_size_s <= 0;
                            state <= write_samples;
                        end if ;
                        if data_dwn = set_numberofsamples_command then
                            state <= set_numberofsamples;
                        end if ;
                    end if;

                when set_start =>
                    enable <= '1';
                    enable_s <= '1';
                    state <= init;

                when set_stop =>
                    enable <= '0';
                    enable_s <= '0';
                    state <= init;

                when return_sizes =>
                    case init_Output is
                    when init =>
                        if data_up_ready = '1' then
                            sizes_temporary <= DATA_WIDTH_slv;
                            init_Output <= Zwischenspeicher;
                        end if;
                    when Zwischenspeicher =>
                        if data_up_ready = '1' then
                            data_up <= sizes_temporary(data_up'range);
                            data_up_valid <= '1';
                            sizes_temporary <= x"00" & sizes_temporary( sizes_temporary'left downto data_up'length);
                            counter <= counter + 1;
                            init_Output <= shift;
                        end if;
                    when shift =>
                            data_up_valid <= '0';

                            if data_up_ready = '0' then
                                init_Output <= Zwischenspeicher;
                            end if;

                            if counter = to_unsigned(4, counter'length) then
                                if import_ADDR = '0' then
                                    init_Output <= get_next_data;
                                else
                                    init_Output <= init;
                                    state <= init;
                                end if;
                            end if;

                        when get_next_data =>
                            if data_up_ready = '1' then
                                counter <= (others => '0');
                                import_ADDR <= '1';
                                sizes_temporary <= ADDR_WIDTH_slv;
                                init_Output <= Zwischenspeicher;
                            end if;
                        end case;

                when write_samples =>
                    if enable_s = '0' then   --- Nötig ???!
                        if setted_numberofsamples = '1' then
                            if data_dwn_valid = '1' then
                                set_dataouts_next_byte <= '1';
                                if (data_size_s + 1 = data_size) then
                                    data_samples_valid_early <= '1';
                                    sample_counter <= sample_counter + 1;
                                    data_size_s <= 0;
                                    if sample_counter  = unsigned(addr_of_last_sample_s) then
                                        state <= init;
                                    end if;
                                else
                                    data_size_s <= data_size_s + 1;
                                end if;

                            end if;
                        end if;
                    end if;
                when set_numberofsamples =>
                    if data_dwn_valid = '1' then
                        if (addr_size_s + 1 = addr_size) then
                            state <= init;
                            setted_numberofsamples_early <= '1';
                        end if;
                        addr_size_s <= addr_size_s + 1;
                        set_addroflastsample_next_byte <= '1';
                    end if;
                end case;
            end if;
            setted_numberofsamples <= setted_numberofsamples_early;
            data_samples_valid <= data_samples_valid_early;
        end if;
    end process;
    data_samples <= data_out_s;
    addr_of_last_sample <= addr_of_last_sample_s;

    set_addr_of_last_sample_narrow: if ADDR_WIDTH <= HOST_WORD_SIZE generate begin
        process (clk) begin
            if rising_edge(clk) then
                if ce = '1' then
                    if set_addroflastsample_next_byte = '1' then
                        addr_of_last_sample_s <= data_dwn_delayed(addr_of_last_sample_s'range);
                        --setted_numberofsamples <= setted_numberofsamples_early;
                    end if;
                end if;
            end if;
        end process;
    end generate set_addr_of_last_sample_narrow;
    set_addr_of_last_sample_wide: if ADDR_WIDTH > HOST_WORD_SIZE generate begin
        process (clk) begin
            if rising_edge(clk) then
                if ce = '1' then
                    if set_addroflastsample_next_byte = '1' then
                        --setted_numberofsamples <= setted_numberofsamples_early;
                        addr_of_last_sample_s <= addr_of_last_sample_s(addr_of_last_sample_s'left-HOST_WORD_SIZE downto 0) & data_dwn_delayed;
                    end if;
                end if;
            end if;
        end process;
    end generate set_addr_of_last_sample_wide;


    set_dataouts_narrow: if DATA_WIDTH <= HOST_WORD_SIZE generate begin
        process (clk) begin
            if rising_edge(clk) then
                if ce = '1' then
                    if set_dataouts_next_byte = '1' then
                        data_out_s <= data_dwn_delayed(data_out_s'range);
                    end if;
                end if;
            end if;
        end process;
    end generate set_dataouts_narrow;
    set_dataouts_wide: if DATA_WIDTH > HOST_WORD_SIZE generate begin
        process (clk) begin
            if rising_edge(clk) then
                if ce = '1' then
                    if set_dataouts_next_byte = '1' then
                        data_out_s <= data_out_s(data_out_s'left-HOST_WORD_SIZE downto 0) & data_dwn_delayed;
                    end if;
                end if;
            end if;
        end process;
    end generate set_dataouts_wide;


end architecture tab;
