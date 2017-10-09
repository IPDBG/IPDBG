library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity IoViewController is
    generic(
        ASYNC_RESET : boolean := true
    );
    port(
        clk            : in  std_logic;
        rst            : in  std_logic;
        ce             : in  std_logic;

        -- host interface (JTAG-HUB or UART or ....)
        data_dwn_valid : in  std_logic;
        data_dwn       : in  std_logic_vector(7 downto 0);
        data_up_ready  : in  std_logic;
        data_up_valid  : out std_logic;
        data_up        : out std_logic_vector(7 downto 0);

        --- Input & Ouput--------
        input          : in  std_logic_vector;
        output         : out std_logic_vector
    );
end entity;

architecture behavioral of IoViewController is

    constant HOST_WORD_SIZE     : natural := 8;
    constant OUTPUT_WIDTH       : natural := output'length;
    constant INPUT_WIDTH        : natural := input'length;

    constant INPUT_WIDTH_BYTES  : natural := (INPUT_WIDTH + HOST_WORD_SIZE - 1)/ HOST_WORD_SIZE;
    constant OUTPUT_WIDTH_BYTES : natural := (OUTPUT_WIDTH + HOST_WORD_SIZE - 1)/ HOST_WORD_SIZE;
    constant INPUT_WIDTH_slv    : std_logic_vector(31 downto 0) := std_logic_vector(to_unsigned(INPUT_WIDTH, 32));
    constant OUTPUT_WIDTH_slv   : std_logic_vector(31 downto 0) := std_logic_vector(to_unsigned(OUTPUT_WIDTH, 32));

    constant read_widths_cmd    : std_logic_vector := x"AB";
    constant write_output_cmd   : std_logic_vector := x"BB";
    constant read_input_cmd     : std_logic_vector := x"AA";

    -- State machines
    type states_t                     is(init, read_width, set_output, read_input);
    signal state                      : states_t;

    type output_handshake_states_t    is(start, mem, shift, next_data);
    signal output_handshake_state     : output_handshake_states_t;

    signal width_bytes_sent_counter   : natural range 0 to OUTPUT_WIDTH_BYTES;

    signal data_in_reg                : std_logic_vector(HOST_WORD_SIZE-1 downto 0);
    signal data_in_reg_valid          : std_logic;
    signal data_in_reg_last           : std_logic;

    signal counter                    : unsigned(INPUT_WIDTH-1 downto 0):= (others => '0');
    signal import_ADDR                : std_logic;
    signal width_temporary_reg        : std_logic_vector(31 downto 0);
    signal data_out_temporary         : std_logic_vector(INPUT'length-1 downto 0);
    signal data_out_temporary_next    : std_logic_vector(INPUT'length-1 downto 0);
    signal data_up_next               : std_logic_vector(data_up'range);

    signal arst, srst                 : std_logic;
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
        procedure fsm_reset_assignment is begin
            state                    <= init;
            output_handshake_state   <= start;
            data_in_reg              <= (others => '-');
            data_in_reg_valid        <= '0';
            data_in_reg_last         <= '0';
            data_up_valid            <= '0';
            data_up                  <= (others => '-');
            data_out_temporary       <= (others => '-');
            width_temporary_reg      <= (others => '-');
            width_bytes_sent_counter <= 0;
            counter                  <= (others => '-');
            import_ADDR              <= '-';
        end procedure fsm_reset_assignment;
    begin
        if arst = '1' then
            fsm_reset_assignment;
        elsif rising_edge(clk) then
            if srst = '1' then
                fsm_reset_assignment;
            else
                if ce = '1' then
                    data_in_reg_valid <= '0';
                    data_in_reg_last  <= '0';
                    data_up_valid    <= '0';
                    case state is
                    when init =>
                        if data_dwn_valid = '1' then
                            if data_dwn = read_widths_cmd then
                                state <= read_width;
                            end if;
                            if data_dwn = write_output_cmd then
                                state <= set_output;
                            end if;
                            if data_dwn = read_input_cmd then
                                state <= read_input;
                                data_out_temporary <= input;
                            end if;
                            width_bytes_sent_counter <= 0;
                            counter <= (others => '0');
                        end if;

                    when read_width =>
                        case output_handshake_state is
                        when start =>
                            if data_up_ready = '1' then
                                width_temporary_reg <= OUTPUT_WIDTH_slv;
                                output_handshake_state <= mem;
                                counter <= (others => '0');
                                import_ADDR <= '0';
                            end if;

                        when mem =>
                            if data_up_ready = '1' then
                                data_up <= width_temporary_reg(data_up'range);
                                data_up_valid <= '1';
                                width_temporary_reg <= x"00" & width_temporary_reg(width_temporary_reg'left downto data_up'length);
                                counter <= counter + 1;
                                output_handshake_state <= shift;
                            end if;

                        when shift =>
                            data_up_valid <= '0';

                            if data_up_ready = '0' then
                                output_handshake_state <= mem;
                            end if;

                            if counter = to_unsigned(4, counter'length) then
                                if import_ADDR = '0' then
                                    output_handshake_state <= next_data;
                                else -- import_ADDR = '1' then
                                    output_handshake_state <= start;
                                    state <= init;
                                end if;
                            end if;

                        when next_data =>
                            if data_up_ready = '1' then
                                counter <= (others => '0');
                                import_ADDR <= '1';
                                width_temporary_reg <= INPUT_WIDTH_slv;
                                output_handshake_state <= mem;
                            end if;
                       end case;

                    when set_output =>
                        if data_dwn_valid = '1' then
                            width_bytes_sent_counter <= width_bytes_sent_counter + 1;
                            data_in_reg <= data_dwn;
                            data_in_reg_valid <= '1';

                            if width_bytes_sent_counter + 1 = OUTPUT_WIDTH_BYTES then
                                state <= init;
                                data_in_reg_last <= '1';
                            end if;
                        end if;

                    when read_input =>
                        case output_handshake_state is
                        when start =>
                            output_handshake_state <= mem;
                        when mem =>
                            if data_up_ready = '1' then
                                data_up_valid <= '1';
                                data_up <= data_up_next;
                                output_handshake_state <= shift;
                                counter <= counter + 1;
                            end if;

                        when shift =>
                            data_up_valid <= '0';
                            if data_up_ready = '0' then
                                if counter = INPUT_WIDTH_BYTES then
                                    output_handshake_state <= next_data;
                                else
                                    output_handshake_state <= mem;
                                    data_out_temporary <= data_out_temporary_next;
                                end if;
                            end if ;

                        when next_data =>
                            counter <= (others => '0');
                            output_handshake_state <= start;
                            state <= init;
                        end case;
                    end case;
                end if;
            end if;
        end if;
    end process ;

    inputGe8:if INPUT_WIDTH >= HOST_WORD_SIZE generate begin
        data_up_next <= data_out_temporary(data_up'range);
        data_out_temporary_next <= x"00" & data_out_temporary(data_out_temporary'left downto HOST_WORD_SIZE);
    end generate;
    inputLess8:if INPUT_WIDTH < HOST_WORD_SIZE generate begin
        process ( data_out_temporary ) begin
            data_up_next <= (others => '0');
            data_up_next(input'length-1 downto 0) <= data_out_temporary;
            data_out_temporary_next <= data_out_temporary; -- will never be used.
        end process;
    end generate;


    outputGreater8: if OUTPUT_WIDTH_BYTES > 1 generate
        constant TEMPORARY_REG_SIZE : natural := (OUTPUT_WIDTH / HOST_WORD_SIZE)*HOST_WORD_SIZE;
        constant LAST_ACCESS_WIDTH  : natural := OUTPUT_WIDTH - TEMPORARY_REG_SIZE;
        signal output_s      : std_logic_vector(TEMPORARY_REG_SIZE-1 downto 0);
        signal output_s_next : std_logic_vector(TEMPORARY_REG_SIZE-1 downto 0);
    begin
        process(clk, arst)
            procedure reset_outputs is begin
                output_s <= (others => '-');
                output <= (output'range => '0');
            end procedure reset_outputs;
        begin
            if arst = '1' then
                reset_outputs;
            elsif rising_edge(clk) then
                if srst = '1' then
                    reset_outputs;
                else
                    if ce = '1' then
                        if data_in_reg_valid = '1' then
                            output_s <= output_s_next;
                        end if;
                        if data_in_reg_last = '1' then
                            output  <=  data_in_reg(LAST_ACCESS_WIDTH-1 downto 0) & output_s;
                        end if;
                    end if;
                end if;
            end if;
        end process;
        temporary_reg_width8: if TEMPORARY_REG_SIZE = HOST_WORD_SIZE generate begin
            output_s_next <= data_in_reg;
        end generate temporary_reg_width8;
        temporary_reg_widthbigger8: if TEMPORARY_REG_SIZE > HOST_WORD_SIZE generate begin
            output_s_next <= data_in_reg & output_s(output_s'left downto HOST_WORD_SIZE);
        end generate temporary_reg_widthbigger8;
    end generate;

    outputSmallerOrEqual8: if OUTPUT_WIDTH_BYTES = 1 generate begin
        process(clk, arst)begin
            if arst = '1' then
               output <= (output'range => '0');
            elsif rising_edge(clk) then
                if srst = '1' then
                    output <= (output'range => '0');
                else
                    if ce = '1' then
                        if data_in_reg_last = '1' then
                            output <= data_in_reg(output'range);
                        end if;
                    end if;
                end if;
            end if;
        end process;
    end generate;

end architecture behavioral;
