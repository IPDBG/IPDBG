library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;
use work.ipdbg_interface_pkg.all;

entity IoViewController is
    generic(
        ASYNC_RESET : boolean := true
    );
    port(
        clk           : in  std_logic;
        rst           : in  std_logic;
        ce            : in  std_logic;

        -- host interface (JTAG-HUB or UART or ....)
        dn_lines      : in  ipdbg_dn_lines;
        up_lines      : out ipdbg_up_lines;

        --- Input & Ouput--------
        input         : in  std_logic_vector;
        output        : out std_logic_vector;
        output_update : out std_logic
    );
end entity;

architecture behavioral of IoViewController is

    constant HOST_WORD_SIZE        : natural := 8;
    constant OUTPUT_WIDTH          : natural := output'length;
    constant INPUT_WIDTH           : natural := input'length;

    constant INPUT_WIDTH_BYTES     : natural := (INPUT_WIDTH + HOST_WORD_SIZE - 1)/ HOST_WORD_SIZE;
    constant OUTPUT_WIDTH_BYTES    : natural := (OUTPUT_WIDTH + HOST_WORD_SIZE - 1)/ HOST_WORD_SIZE;
    constant INPUT_WIDTH_slv       : std_logic_vector(31 downto 0) := std_logic_vector(to_unsigned(INPUT_WIDTH, 32));
    constant OUTPUT_WIDTH_slv      : std_logic_vector(31 downto 0) := std_logic_vector(to_unsigned(OUTPUT_WIDTH, 32));

    constant read_widths_cmd       : std_logic_vector := x"AB";
    constant write_output_cmd      : std_logic_vector := x"BB";
    constant read_input_cmd        : std_logic_vector := x"AA";

    -- State machines
    type states_t                  is (init, read_width, set_output, read_input);
    signal state                   : states_t;

    type output_handshake_states_t is(start, mem, shift, next_data);
    signal output_handshake_state  : output_handshake_states_t;

    signal bytes_received          : unsigned(integer(ceil(log2(real(OUTPUT_WIDTH_BYTES+1)))) -1 downto 0);

    signal data_in_reg             : std_logic_vector(HOST_WORD_SIZE-1 downto 0);
    signal data_in_reg_valid       : std_logic;
    signal data_in_reg_last        : std_logic;

    pure function bytes_transmitted_width return natural is
        variable res       : natural := integer(ceil(log2(real(INPUT_WIDTH_BYTES+1))));
        constant min_width : natural := 3 ;-- must be able to tx at least 4 bytes for the widths
    begin
        if res < min_width then
            res := min_width;
        end if;
        return res;
    end bytes_transmitted_width;

    signal bytes_transmitted       : unsigned(bytes_transmitted_width-1 downto 0) := (others => '0');
    signal import_ADDR             : std_logic;
    signal width_temporary_reg     : std_logic_vector(31 downto 0);
    signal data_out_temporary      : std_logic_vector(INPUT'length-1 downto 0);
    signal data_out_temporary_next : std_logic_vector(INPUT'length-1 downto 0);
    signal data_up_next            : std_logic_vector(up_lines.uplink_data'range);

    signal arst, srst              : std_logic;
begin
    async_init: if ASYNC_RESET generate begin
        arst <= rst;
        srst <= '0';
    end generate async_init;
    sync_init: if not ASYNC_RESET generate begin
        arst <= '0';
        srst <= rst;
    end generate sync_init;

    up_lines.dnlink_ready <= '1';

    process (clk, arst)
        procedure fsm_reset_assignment is begin
            state                  <= init;
            output_handshake_state <= start;
            data_in_reg            <= (others => '-');
            data_in_reg_valid      <= '0';
            data_in_reg_last       <= '0';
            up_lines.uplink_valid  <= '0';
            up_lines.uplink_data   <= (others => '-');
            data_out_temporary     <= (others => '-');
            width_temporary_reg    <= (others => '-');
            bytes_received         <= (others => '-');
            bytes_transmitted      <= (others => '-');
            import_ADDR            <= '-';
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
                    up_lines.uplink_valid    <= '0';
                    case state is
                    when init =>
                        if dn_lines.dnlink_valid = '1' then
                            if dn_lines.dnlink_data = read_widths_cmd then
                                state <= read_width;
                            end if;
                            if dn_lines.dnlink_data = write_output_cmd then
                                state <= set_output;
                            end if;
                            if dn_lines.dnlink_data = read_input_cmd then
                                state <= read_input;
                                data_out_temporary <= input;
                            end if;
                        end if;
                        bytes_received <= (others => '0');
                        bytes_transmitted <= (others => '0');

                    when read_width =>
                        case output_handshake_state is
                        when start =>
                            if dn_lines.uplink_ready = '1' then
                                width_temporary_reg <= OUTPUT_WIDTH_slv;
                                output_handshake_state <= mem;
                                bytes_transmitted <= (others => '0');
                                import_ADDR <= '0';
                            end if;

                        when mem =>
                            if dn_lines.uplink_ready = '1' then
                                up_lines.uplink_data <= width_temporary_reg(up_lines.uplink_data'range);
                                up_lines.uplink_valid <= '1';
                                width_temporary_reg <= x"00" & width_temporary_reg(width_temporary_reg'left downto up_lines.uplink_data'length);
                                bytes_transmitted <= bytes_transmitted + 1;
                                output_handshake_state <= shift;
                            end if;

                        when shift =>
                            up_lines.uplink_valid <= '0';

                            if dn_lines.uplink_ready = '0' then
                                output_handshake_state <= mem;
                            end if;

                            if bytes_transmitted = to_unsigned(4, bytes_transmitted'length) then
                                if import_ADDR = '0' then
                                    output_handshake_state <= next_data;
                                else -- import_ADDR = '1' then
                                    output_handshake_state <= start;
                                    state <= init;
                                end if;
                            end if;

                        when next_data =>
                            if dn_lines.uplink_ready = '1' then
                                bytes_transmitted <= (others => '0');
                                import_ADDR <= '1';
                                width_temporary_reg <= INPUT_WIDTH_slv;
                                output_handshake_state <= mem;
                            end if;
                        end case;

                    when set_output =>
                        if dn_lines.dnlink_valid = '1' then
                            bytes_received <= bytes_received + 1;
                            data_in_reg <= dn_lines.dnlink_data;
                            data_in_reg_valid <= '1';

                            if bytes_received = OUTPUT_WIDTH_BYTES-1 then
                                state <= init;
                                data_in_reg_last <= '1';
                            end if;
                        end if;

                    when read_input =>
                        case output_handshake_state is
                        when start =>
                            output_handshake_state <= mem;
                        when mem =>
                            if dn_lines.uplink_ready = '1' then
                                up_lines.uplink_valid <= '1';
                                up_lines.uplink_data <= data_up_next;
                                output_handshake_state <= shift;
                                bytes_transmitted <= bytes_transmitted + 1;
                            end if;

                        when shift =>
                            up_lines.uplink_valid <= '0';
                            if dn_lines.uplink_ready = '0' then
                                if bytes_transmitted = INPUT_WIDTH_BYTES then
                                    output_handshake_state <= next_data;
                                else
                                    output_handshake_state <= mem;
                                    data_out_temporary <= data_out_temporary_next;
                                end if;
                            end if ;

                        when next_data =>
                            bytes_transmitted <= (others => '0');
                            output_handshake_state <= start;
                            state <= init;
                        end case;
                    end case;
                end if;
            end if;
        end if;
    end process ;

    inputGe8:if INPUT_WIDTH >= HOST_WORD_SIZE generate begin
        data_up_next <= data_out_temporary(up_lines.uplink_data'range);
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
        constant TEMPORARY_REG_SIZE : natural := ((OUTPUT_WIDTH-1) / HOST_WORD_SIZE)*HOST_WORD_SIZE;
        constant LAST_ACCESS_WIDTH  : natural := OUTPUT_WIDTH - TEMPORARY_REG_SIZE;
        signal output_s      : std_logic_vector(TEMPORARY_REG_SIZE-1 downto 0);
        signal output_s_next : std_logic_vector(TEMPORARY_REG_SIZE-1 downto 0);
    begin
        process(clk, arst)
            procedure reset_outputs is begin
                output_s <= (others => '-');
                output <= (output'range => '0');
                output_update <= '0';
            end procedure reset_outputs;
        begin
            if arst = '1' then
                reset_outputs;
            elsif rising_edge(clk) then
                if srst = '1' then
                    reset_outputs;
                else
                    if ce = '1' then
                        output_update <= '0';
                        if data_in_reg_valid = '1' then
                            output_s <= output_s_next;
                        end if;
                        if data_in_reg_last = '1' then
                            output  <=  data_in_reg(LAST_ACCESS_WIDTH-1 downto 0) & output_s;
                            output_update <= '1';
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
        process(clk, arst)
            procedure reset_outputs is begin
                output <= (output'range => '0');
                output_update <= '0';
            end procedure reset_outputs;
        begin
            if arst = '1' then
               reset_outputs;
            elsif rising_edge(clk) then
                if srst = '1' then
                    reset_outputs;
                else
                    if ce = '1' then
                        output_update <= '0';
                        if data_in_reg_last = '1' then
                            output <= data_in_reg(output'range);
                            output_update <= '1';
                        end if;
                    end if;
                end if;
            end if;
        end process;
    end generate;

end architecture behavioral;
