library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity IoViewController is
    port(
        clk            : in  std_logic;
        rst            : in  std_logic;
        ce             : in  std_logic;

        -- host interface (JTAG-HUB or UART or ....)
        data_in_valid  : in  std_logic;
        data_in        : in  std_logic_vector(7 downto 0);
        data_out_ready : in  std_logic;
        data_out_valid : out std_logic;
        data_out       : out std_logic_vector(7 downto 0);

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

begin

    assert INPUT_WIDTH >= 8 report "input width must at least be 8, (hint: connect unused input to a constant)" severity failure;

    process (clk, rst) begin
        if rst = '1' then
            state                  <= init;
            output_handshake_state <= start;
            data_in_reg              <= (others => '-');
            data_in_reg_valid      <= '0';
            data_in_reg_last       <= '0';
            width_temporary_reg    <= (others => '-');

        elsif rising_edge(clk) then

            if ce = '1' then
                data_in_reg_valid <= '0';
                data_in_reg_last  <= '0';
                data_out_valid    <= '0';
                case state is
                when init =>
                    if data_in_valid = '1' then
                        if data_in = read_widths_cmd then
                            state <= read_width;
                        end if;
                        if data_in = write_output_cmd then
                            state <= set_output;
                        end if;
                        if data_in = read_input_cmd then
                            state <= read_input;
                            data_out_temporary <= Input;
                            counter <= (others => '0');
                        end if;
                        width_bytes_sent_counter <= 0;
                    end if;

                when read_width =>
                    case output_handshake_state is
                    when start =>
                        if data_out_ready = '1' then
                            width_temporary_reg <= OUTPUT_WIDTH_slv;
                            output_handshake_state <= mem;
                            counter <= (others => '0');
                            import_ADDR <= '0';
                        end if;

                    when mem =>
                        if data_out_ready = '1' then
                            data_out <= width_temporary_reg(data_out'range);
                            data_out_valid <= '1';
                            width_temporary_reg <= x"00" & width_temporary_reg(width_temporary_reg'left downto data_out'length);
                            counter <= counter + 1;
                            output_handshake_state <= shift;
                        end if;

                    when shift =>
                        data_out_valid <= '0';

                        if data_out_ready = '0' then
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
                        if data_out_ready = '1' then
                            counter <= (others => '0');
                            import_ADDR <= '1';
                            width_temporary_reg <= INPUT_WIDTH_slv;
                            output_handshake_state <= mem;
                        end if;
                   end case;

                when set_output =>
                    if data_in_valid = '1' then
                        width_bytes_sent_counter <= width_bytes_sent_counter + 1;
                        data_in_reg <= data_in;
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
                        if data_out_ready = '1' then
                            data_out_valid <= '1';
                            data_out <= data_out_temporary(data_out'range);
                            output_handshake_state <= shift;
                            counter <= counter + 1;
                        end if;

                    when shift =>
                        data_out_valid <= '0';
                        if data_out_ready = '0' then
                            if counter = INPUT_WIDTH_BYTES then
                                output_handshake_state <= next_data;
                            else
                                output_handshake_state <= mem;
                                data_out_temporary <= x"00" & data_out_temporary( data_out_temporary'left downto data_out'length);
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
    end process ;

    outputGreater8: if OUTPUT_WIDTH_BYTES > 1 generate
        signal output_s             : std_logic_vector(OUTPUT_WIDTH-HOST_WORD_SIZE-1 downto 0);
        constant output_reset_value : std_logic_Vector(output'left downto 0) := (others => '0');
    begin
        process(rst, clk)begin
            if rst = '1' then
               output <= output_reset_value;
            elsif rising_edge(clk) then
                if ce = '1' then
                    if data_in_reg_valid = '1' then
                        output_s <= data_in_reg & output_s(output_s'left downto HOST_WORD_SIZE);
                    end if;
                    if data_in_reg_last = '1' then
                        output  <=  data_in_reg & output_s(output_s'left downto 0);
                    end if;

                end if;
            end if;
        end process;
    end generate;

    outputSmallerOrEqual8: if OUTPUT_WIDTH_BYTES = 1 generate
        constant output_reset_value : std_logic_Vector(output'left downto 0) := (others => '0');
    begin
        process(rst, clk)begin
            if rst = '1' then
               output <= output_reset_value;
            elsif rising_edge(clk) then
                if ce = '1' then
                    if data_in_reg_last = '1' then
                        output <= data_in_reg(output'range);
                    end if;
                end if;
            end if;
        end process;
    end generate;

end architecture behavioral;
