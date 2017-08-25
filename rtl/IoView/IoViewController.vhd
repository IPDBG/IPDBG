library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity IoViewController is
    port(
        clk          : in  std_logic;
        rst          : in  std_logic;
        ce           : in  std_logic;

        -- host interface (JTAG-HUB or UART or ....)
        DataInValid  : in  std_logic;
        DataIn       : in  std_logic_vector(7 downto 0);
        DataOutReady : in  std_logic;
        DataOutValid : out std_logic;
        DataOut      : out std_logic_vector(7 downto 0);

        --- Input & Ouput--------
        Input        : in  std_logic_vector;
        Output       : out std_logic_vector
    );
end entity;


architecture behavioral of IoViewController is

    constant HOST_WORD_SIZE           : natural := 8;
    constant OUTPUT_WIDTH             : natural := Output'length;
    constant INPUT_WIDTH              : natural := Input'length;

    constant INPUT_WIDTH_BYTES        : natural := (INPUT_WIDTH + HOST_WORD_SIZE - 1)/ HOST_WORD_SIZE;
    constant OUTPUT_WIDTH_BYTES       : natural := (OUTPUT_WIDTH + HOST_WORD_SIZE - 1)/ HOST_WORD_SIZE;
    constant INPUT_WIDTH_slv          : std_logic_vector(31 downto 0) := std_logic_vector(to_unsigned(INPUT_WIDTH, 32));
    constant OUTPUT_WIDTH_slv         : std_logic_vector(31 downto 0) := std_logic_vector(to_unsigned(OUTPUT_WIDTH, 32));

    -- Commands for IoViewController
    constant ReadWidthsCmd            : std_logic_vector := x"AB";
    constant WriteOutputCmd           : std_logic_vector := x"BB";
    constant ReadIputsCmd             : std_logic_vector := x"AA";

    -- State machines
    type states_t                     is(init, I_O_WIDTH, set_Output, read_Input);
    signal state                      : states_t;

    type Output_W                     is(start, Zwischenspeicher, schieben, next_Data);
    signal init_Output                : Output_W;

    signal OUTPUT_WIDTH_BYTES_ZAEHLER : natural range 0 to OUTPUT_WIDTH_BYTES;

    signal DataInReg                  : std_logic_vector(HOST_WORD_SIZE-1 downto 0);
    signal DataInRegValid             : std_logic;
    signal DataInRegLast              : std_logic;

    signal zaehler                    : unsigned(INPUT_WIDTH-1 downto 0):= (others => '0');
    signal import_ADDR                : std_logic;
    signal IOZwischenspeicher         : std_logic_vector(31 downto 0);
    signal DatenOutZwischenspeicher   : std_logic_vector(INPUT'length-1 downto 0);

begin

    assert INPUT_WIDTH >= 8 report "input width must at least be 8, (hint: connect unused input to a constant)" severity failure;

    process (clk, rst) begin
        if rst = '1' then
            state <= init;
            init_Output       <= start;
            DataInReg      <= (others => '-');
            DataInRegValid <= '0';
            DataInRegLast  <= '0';
            IOZwischenspeicher <= (others => '-');

        elsif rising_edge(clk) then

            if ce = '1' then
                DataInRegValid <= '0';
                DataInRegLast  <= '0';
                DataOutValid <= '0';
                case state is
                when init =>
                    if DataInValid = '1' then
                        if DataIn = ReadWidthsCmd then
                            state <= I_O_WIDTH;
                        end if;
                        if DataIn = WriteOutputCmd then
                            state <= set_Output;
                        end if;
                        if DataIn = ReadIputsCmd then
                            state <= read_Input;
                            DatenOutZwischenspeicher <= Input;
                            Zaehler <= (others => '0');
                        end if;
                        OUTPUT_WIDTH_BYTES_ZAEHLER <= 0;
                    end if;

                when I_O_WIDTH =>
                    case init_Output is
                    when start =>
                        if DataOutReady = '1' then
                            IOZwischenspeicher <= OUTPUT_WIDTH_slv;
                            init_Output <= Zwischenspeicher;
                            Zaehler <= (others => '0');
                            import_ADDR <= '0';
                        end if;

                    when Zwischenspeicher =>
                        if DataOutReady = '1' then
                            DataOut <= IOZwischenspeicher(DataOut'range);
                            DataOutValid <= '1';
                            IOZwischenspeicher <= x"00" & IOZwischenspeicher(IOZwischenspeicher'left downto DataOut'length);
                            Zaehler <= Zaehler + 1;
                            init_Output <= schieben;
                        end if;

                    when schieben =>
                        DataOutValid <= '0';

                        if DataOutReady = '0' then
                            init_Output <= Zwischenspeicher;
                        end if;

                        if Zaehler = to_unsigned(4, Zaehler'length) then
                            if import_ADDR = '0' then
                                init_Output <= next_Data;
                            end if;
                        end if;

                        if Zaehler = to_unsigned(4, Zaehler'length) then
                            if import_ADDR = '1' then
                                init_Output <= start;
                                state <= init;
                            end if;
                        end if;

                    when next_Data =>
                        if DataOutReady = '1' then
                            Zaehler <= (others => '0');
                            import_ADDR <= '1';
                            IOZwischenspeicher <= INPUT_WIDTH_slv;
                            init_Output <= Zwischenspeicher;
                        end if;
                   end case;

                when set_Output =>
                    if DataInValid = '1' then
                        OUTPUT_WIDTH_BYTES_ZAEHLER <= OUTPUT_WIDTH_BYTES_ZAEHLER + 1;
                        DataInReg <= DataIn;
                        DataInRegValid <= '1';

                        if OUTPUT_WIDTH_BYTES_ZAEHLER + 1 = OUTPUT_WIDTH_BYTES then
                            state <= init;
                            DataInRegLast <= '1';
                        end if;
                    end if;

                when read_Input =>
                    case init_Output is
                    when start =>
                        init_Output <= Zwischenspeicher;
                    when Zwischenspeicher =>
                        if DataOutReady = '1' then
                            DataOutValid <= '1';
                            DataOut <= DatenOutZwischenspeicher(DataOut'range);
                            init_Output <= schieben;
                            Zaehler <= Zaehler + 1;
                        end if;

                    when schieben =>
                        DataOutValid <= '0';
                        if DataOutReady = '0' then
                            if Zaehler = INPUT_WIDTH_BYTES then
                                init_Output <= next_Data;
                            else
                                init_Output <= Zwischenspeicher;
                                DatenOutZwischenspeicher <= x"00" & DatenOutZwischenspeicher( DatenOutZwischenspeicher'left downto DataOut'length);
                            end if;
                        end if ;

                    when next_Data =>
                        Zaehler <= (others => '0');
                        init_Output <= start;
                        state <= init;
                    end case;
                end case;
            end if;
        end if;
    end process ;

    outputGreater8: if OUTPUT_WIDTH_BYTES > 1 generate
        signal Output_s         : std_logic_vector(OUTPUT_WIDTH-HOST_WORD_SIZE-1 downto 0);
        constant OutputResetValue : std_logic_Vector(output'left downto 0) := (others => '0');
    begin
        process(rst, clk)begin
            if rst = '1' then
               Output <= OutputResetValue;
            elsif rising_edge(clk) then
                if ce = '1' then
                    if DataInRegValid = '1' then
                        Output_s <= DataInReg & Output_s(Output_s'left downto HOST_WORD_SIZE);
                    end if;
                    if DataInRegLast = '1' then
                        Output  <=  DataInReg & Output_s(Output_s'left downto 0);
                    end if;

                end if;
            end if;
        end process;
    end generate;

    outputSmallerOrEqual8: if OUTPUT_WIDTH_BYTES = 1 generate
        constant OutputResetValue : std_logic_Vector(output'left downto 0) := (others => '0');
    begin
        process(rst, clk)begin
            if rst = '1' then
               Output <= OutputResetValue;
            elsif rising_edge(clk) then
                if ce = '1' then
                    if DataInRegLast = '1' then
                        Output <= DataInReg(Output'range);
                    end if;
                end if;
            end if;
        end process;
    end generate;

end architecture behavioral;