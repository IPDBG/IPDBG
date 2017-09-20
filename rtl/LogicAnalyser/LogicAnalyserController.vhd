library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity LogicAnalyserController is
    generic(
         DATA_WIDTH         : natural := 8;                                    --! width of a sample
         ADDR_WIDTH         : natural := 4                                     --! 2**ADDR_WIDTH = size if sample memory
    );
    port(
        clk               : in  std_logic;
        rst               : in  std_logic;
        ce                : in  std_logic;

        --      host interface (UART or ....)
        data_dwn_valid     : in  std_logic;
        data_dwn           : in  std_logic_vector(7 downto 0);
        data_up_ready    : in  std_logic;
        data_up_valid    : out std_logic;
        data_up          : out std_logic_vector(7 downto 0);

        --      Trigger
        mask_curr         : out std_logic_vector(DATA_WIDTH-1 downto 0);
        value_curr        : out std_logic_vector(DATA_WIDTH-1 downto 0);
        mask_last         : out std_logic_vector(DATA_WIDTH-1 downto 0);
        value_last        : out std_logic_vector(DATA_WIDTH-1 downto 0);

        --      Logic Analyser
        delay             : out std_logic_vector(ADDR_WIDTH-1 downto 0);
        trigger_active    : out std_logic;
        fire_trigger      : out std_logic;

        full              : in  std_logic;
        data              : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        data_request_next : out std_logic;
        data_valid        : in  std_logic;

        -- init
        finish            : in  std_logic
    );
end entity LogicAnalyserController;


architecture tab of LogicAnalyserController is

    constant HOST_WORD_SIZE : natural := 8;

    constant data_size      : natural := (DATA_WIDTH + HOST_WORD_SIZE - 1)/ HOST_WORD_SIZE;                                  -- Berechnung wie oft dass Mask, Value, Mask_last und Value_last eingelesen werden müssen.
    constant addr_size      : natural := (ADDR_WIDTH + HOST_WORD_SIZE - 1)/ HOST_WORD_SIZE;                                  -- Berechnung wie oft, dass das Delay für das Memory eingelesen werden muss.
    constant DATA_WIDTH_slv : std_logic_vector(31 downto 0) := std_logic_vector(to_unsigned(DATA_WIDTH, 32)); -- DATA_WIDTH_slv = Wert der Übertragung des DATA_WIDTH
    constant ADDR_WIDTH_slv : std_logic_vector(31 downto 0) := std_logic_vector(to_unsigned(ADDR_WIDTH, 32)); -- DATA_WIDTH_slv = Wert der Übertragung des DATA_WIDTH

    ------------------------------------------------------------------Befehle um den LogicAnalyser zu bedienen-------------------------------------------------------------------------------------------------------------------------------------------------------------
    constant activate_trigger_command : std_logic_vector := "11111110";--FE
    constant fire_trigger_command     : std_logic_vector := "00000000";--00
    constant config_trigger_command   : std_logic_vector := "11110000";--f0
    constant logic_analyser_c         : std_logic_vector := "00001111";--0f
    constant select_curr_command      : std_logic_vector := "11110001";--f1
    constant set_mask_curr_command    : std_logic_vector := "11110011";--F3
    constant set_value_curr_command   : std_logic_vector := "11110111";--f7
    constant select_last_command      : std_logic_vector := "11111001";--F9
    constant set_mask_last_command    : std_logic_vector := "11111011";--fb
    constant set_value_last_command   : std_logic_vector := "11111111";--FF
    constant set_delay_command        : std_logic_vector := "00011111";--1f
    constant get_sizes_command        : std_logic_vector := "10101010";--AA
    constant get_id_command           : std_logic_vector := "10111011";--BB

    constant I                        : std_logic_vector := "01001001";
    constant D                        : std_logic_vector := "01000100";
    constant B                        : std_logic_vector := "01000010";
    constant G                        : std_logic_vector := "01000111";
    --State machines
    type states_t              is(init, return_id, return_sizes, logic_analyser, set_delay,
                                         config_trigger, select_config_trigger_curr, select_config_trigger_last,
                                         set_mask_curr, set_value_curr, set_mask_last, set_value_last, data_output);
    signal state : states_t :=  init;

    type Output is(init, Zwischenspeicher, shift, get_next_data);
    signal init_Output    : Output := init;

    --Zähler
    signal data_size_s       : natural range 0 to data_size;
    signal addr_size_s       : natural;

    signal mask_curr_s       : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal value_curr_s      : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal mask_last_s       : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal value_last_s      : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal delay_s           : std_logic_vector(ADDR_WIDTH-1 downto 0) := (others => '0');

    signal counter           : unsigned(ADDR_WIDTH-1 downto 0):= (others => '0');
    signal import_ADDR       : std_logic := '0';
    signal ende_ausgabe      : std_logic := '0';
    signal theend            : std_logic := '0';
    signal la_data_temporary : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal sizes_temporary   : std_logic_vector(31 downto 0) := (others => '0');
    signal send              : std_logic_vector(7 downto 0)  := (others => '0');
begin

    assert(DATA_WIDTH >= 8) report "DATA_WIDTH has to be at least 8 bits" severity error;

    process (clk, rst) begin
        if rst = '1' then
            data_size_s        <= 0;
            addr_size_s        <= 0;
            state              <= init;
            init_Output        <= init;

            mask_curr_s        <= (others => '0');
            value_curr_s       <= (others => '0');
            mask_last_s        <= (others => '0');
            value_last_s       <= (others => '0');
            delay_s            <= (others => '0');

            data_up_valid    <= '0';
            data_up          <= (others => '0');
            trigger_active    <= '0';
            fire_trigger      <= '0';
            data_request_next <= '0';

            counter           <= (others => '0');
            import_ADDR       <= '0';
            la_data_temporary <= (others => '0');
            sizes_temporary   <= (others => '-');
            ende_ausgabe      <= '0';
            theend            <= '0';

        elsif rising_edge(clk) then

            if ce = '1' then
                data_up_valid <= '0';
                case state is
                when init =>
                    if full = '1' then
                        data_request_next <= '1';
                        state <= data_output;
                        counter <= (others => '0');
                        la_data_temporary <= (others => '-');
                        ende_ausgabe <= '0';
                        theend <= '0';
                    end if;

                    if data_dwn_valid = '1' then
                        if data_dwn = get_id_command then
                            state <= return_id;
                        end if;


                        if data_dwn = get_sizes_command then
                            counter <= (others => '0');
                            --x <= '0';
                            sizes_temporary <= (others => '0');
                            state <= return_sizes;
                            import_ADDR <= '0';
                        end if;

                        if data_dwn = activate_trigger_command then
                            trigger_active <= '1';
                        end if;

                        if data_dwn = fire_trigger_command then
                            fire_trigger <= '1';
                        end if;

                        if data_dwn = config_trigger_command then
                            state <= config_trigger;
                        end if;

                        if data_dwn = logic_analyser_c then
                            state <= logic_analyser;
                        end if;

                    end if;

                when return_id =>

                    case init_Output is
                    when init =>
                        if data_up_ready = '1' then
                            init_Output <= Zwischenspeicher;
                            send <= I;
                            counter <= (others => '0');
                        end if;

                    when Zwischenspeicher =>
                        if data_up_ready = '1' then
                            data_up <= send;
                            data_up_valid <= '1';
                            counter <= counter + 1;
                            init_Output <= shift;
                        end if;
                     when shift =>
                        data_up_valid <= '0';
                        init_Output <= get_next_data;

                    when get_next_data =>

                       if counter = to_unsigned(1, counter'length) then
                            send <= D;
                             init_Output <= Zwischenspeicher;
                       end if;
                       if counter = to_unsigned(2, counter'length) then
                            send <= B;
                            init_Output <= Zwischenspeicher;
                       end if;
                       if counter = to_unsigned(3, counter'length) then
                            send <= G;
                            init_Output <= Zwischenspeicher;
                       end if;
                       if counter = to_unsigned(4, counter'length) then
                            init_Output <= init;
                            state <= init;
                       end if;

                    end case;


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
                            end if;
                        end if;

                        if counter = to_unsigned(4, counter'length) then
                            if import_ADDR = '1' then
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

                when logic_analyser =>
                    addr_size_s <= 0;
                    if data_dwn_valid = '1' then
                        if data_dwn = set_delay_command then
                            state <= set_delay;
                        end if;

                    end if;

                when set_delay =>
                    if data_dwn_valid = '1' then
                        if addr_size_s + 1 = addr_size  then
                            state <= init;
                        end if;

                        addr_size_s <= addr_size_s + 1;
                        delay_s <= delay_s(delay_s'left-HOST_WORD_SIZE downto 0) & data_dwn;
                    end if;

                when config_trigger =>
                    if data_dwn_valid = '1' then
                        if data_dwn = select_curr_command then
                            state <= select_config_trigger_curr;
                        end if;

                        if data_dwn = select_last_command then
                            state <= select_config_trigger_last;
                        end if;
                    end if;

                when select_config_trigger_curr =>
                    data_size_s <= 0;

                    if data_dwn_valid = '1' then
                        if data_dwn = set_mask_curr_command then
                            state <= set_mask_curr;
                        end if;

                        if data_dwn = set_value_curr_command then
                            state <= set_value_curr;
                        end if;

                    end if;

                when set_mask_curr =>
                    if data_dwn_valid = '1' then
                        data_size_s <= data_size_s + 1;
                        mask_curr_s <= mask_curr_s(mask_curr_s'left-HOST_WORD_SIZE downto 0) & data_dwn;

                        if data_size_s + 1 = data_size   then
                            state <= init;
                        end if;
                    end if;

                when set_value_curr =>
                    if data_dwn_valid = '1' then
                        data_size_s <= data_size_s + 1;
                        value_curr_s <= value_curr_s(value_curr_s'left-HOST_WORD_SIZE downto 0) & data_dwn;

                        if data_size_s + 1 = data_size then
                            state <= init;
                        end if;
                    end if;

                when select_config_trigger_last =>
                    data_size_s <= 0;
                    if data_dwn_valid = '1' then
                        if data_dwn = set_mask_last_command then
                            state <= set_mask_last;
                        end if;

                        if data_dwn = set_value_last_command then
                            state <= set_value_last;
                        end if;
                    end if;

                when set_mask_last =>
                    if data_dwn_valid = '1' then
                        data_size_s <= data_size_s + 1;
                        mask_last_s <= mask_last_s(mask_last_s'left-HOST_WORD_SIZE downto 0) & data_dwn;

                        if data_size_s +1 = data_size then
                            state <= init;
                        end if;
                    end if;

                when set_value_last =>
                    if data_dwn_valid = '1' then
                        data_size_s <= data_size_s + 1;
                        value_last_s <= value_last_s(value_last_s'left-HOST_WORD_SIZE downto 0) & data_dwn;

                        if data_size_s + 1 = data_size then
                            state <= init;
                        end if;
                    end if;

                when data_output =>
                    if finish = '1' then
                        trigger_active <= '0';
                        ende_ausgabe <= '1';
                    end if;

                    if theend = '1' then
                        state <= init;
                        init_Output <= init;
                    end if;

                    case init_Output is
                    when init =>
                        if data_valid = '1' then
                            la_data_temporary <= data;
                            init_Output <= Zwischenspeicher;
                        end if;

                    when Zwischenspeicher =>
                        data_request_next <= '0';
                        if data_up_ready = '1' then
                            data_up <= la_data_temporary(data_up'range);
                            data_up_valid <= '1';
                            la_data_temporary <= x"00" & la_data_temporary( la_data_temporary'left downto data_up'length);
                            counter <= counter + 1;
                            init_Output <= shift;
                        end if;

                    when shift =>
                        data_up_valid <= '0';
                        if data_up_ready = '0' then
                            init_Output <= Zwischenspeicher;
                        end if;

                        if counter = data_size then
                            data_request_next <= '1';
                            init_Output <= get_next_data;
                        end if;

                    when get_next_data =>
                        if ende_ausgabe = '1' then
                            theend <= '1' ;
                        end if;

                        if data_valid = '1' then
                            counter <= (others => '0');
                            la_data_temporary <= data;
                            init_Output <= Zwischenspeicher;
                        end if;
                    end case;
                end case ;
            end if;
        end if;
    end process ;

    delay      <= delay_s;
    mask_curr  <= mask_curr_s;
    value_curr <= value_curr_s;
    mask_last  <= mask_last_s;
    value_last <= value_last_s;


end architecture tab;
