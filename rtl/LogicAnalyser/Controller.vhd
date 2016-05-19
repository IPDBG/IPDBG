library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity Controller is
    generic(
         DATA_WIDTH         : natural := 8;                                    --! width of a sample
         ADDR_WIDTH         : natural := 4                                     --! 2**ADDR_WIDTH = size if sample memory
    );
    port(
        clk                 : in  std_logic;
        rst                 : in  std_logic;
        ce                  : in  std_logic;

        --      host interface (UART or ....)
        DatenInValid        : in  std_logic;
        DatenIn_Befehle     : in  std_logic_vector(7 downto 0);

        DatenReady_HOST     : in  std_logic;
        DataValid_HOST      : out std_logic;
        DatenOut_HOST       : out std_logic_vector(7 downto 0);

        --      Trigger
        Mask_O              : out std_logic_vector(DATA_WIDTH-1 downto 0);
        Value_O             : out std_logic_vector(DATA_WIDTH-1 downto 0);
        Mask_last_O         : out std_logic_vector(DATA_WIDTH-1 downto 0);
        Value_last_O        : out std_logic_vector(DATA_WIDTH-1 downto 0);

        --      Logic Analyser
        delayOut_LA         : out std_logic_vector(ADDR_WIDTH-1 downto 0);
        TriggerActive_LA    : out std_logic := '0' ;
        Trigger_LA          : out std_logic;

        Full_LA             : in  std_logic;
        Daten_LA            : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        NextData_LA         : out std_logic;
        DataValid_LA        : in  std_logic;


        -- init
        stateDebug               : out std_logic_vector(7 downto 0);
        finish_LA                : in  std_logic
    );
end entity;


architecture tab of Controller is

    constant HOST_WORD_SIZE : natural := 8;

    constant K : natural := (DATA_WIDTH + HOST_WORD_SIZE - 1)/ HOST_WORD_SIZE;                                  -- Berechnung wie oft dass Mask, Value, Mask_last und Value_last eingelesen werden müssen.
    constant M : natural := (ADDR_WIDTH + HOST_WORD_SIZE - 1)/ HOST_WORD_SIZE;                                  -- Berechnung wie oft, dass das Delay für das Memory eingelesen werden muss.
    constant DATA_WIDTH_slv   : std_logic_vector(31 downto 0) := std_logic_vector(to_unsigned(DATA_WIDTH, 32)); -- DATA_WIDTH_slv = Wert der Übertragung des DATA_WIDTH
    constant ADDR_WIDTH_slv   : std_logic_vector(31 downto 0) := std_logic_vector(to_unsigned(ADDR_WIDTH, 32)); -- DATA_WIDTH_slv = Wert der Übertragung des DATA_WIDTH

    ------------------------------------------------------------------Befehle um den LogicAnalyser zu bedienen-------------------------------------------------------------------------------------------------------------------------------------------------------------
    constant Start_c          : std_logic_vector := "11111110";--FE
    constant set_Trigger_c    : std_logic_vector := "00000000";--00
    constant Trigger_c        : std_logic_vector := "11110000";--f0
    constant Logic_Analyser_c : std_logic_vector := "00001111";--0f
    constant Masks_c          : std_logic_vector := "11110001";--f1
    constant Mask_c           : std_logic_vector := "11110011";--F3
    constant Value_c          : std_logic_vector := "11110111";--f7
    constant Last_Masks_c     : std_logic_vector := "11111001";--F9
    constant Mask_Last_c      : std_logic_vector := "11111011";--fb
    constant Value_Last_c     : std_logic_vector := "11111111";--FF
    constant delay_c          : std_logic_vector := "00011111";--1f
    constant KMout_c          : std_logic_vector := "10101010";--AA
    constant get_ID           : std_logic_vector := "10111011";--BB

    constant I                : std_logic_vector := "01001001";
    constant D                : std_logic_vector := "01000100";
    constant B                : std_logic_vector := "01000010";
    constant G                : std_logic_vector := "01000111";
    --State machines
    type Initialisierung is(init, Text_c, wait_Import, Logic_Analyser, delay, Trigger, Masks, Mask, Value, Last_Masks, Mask_last, Value_last, Datenausgabe);
    signal init_statemachine    : Initialisierung :=  init;

    type Output is(start, Zwischenspeicher, schieben, next_Data);
    signal init_Output    : Output := start;


    --Zähler
    signal K_s              : natural ;
    signal M_s              : natural ;



    signal Mask_s           : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal Value_s          : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal Mask_last_s      : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal Value_last_s     : std_logic_vector(ADDR_WIDTH-1 downto 0) := (others => '0');
    signal delay_s          : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal Cancel_s         : std_logic := '0';


    signal zaehler                   : unsigned(ADDR_WIDTH-1 downto 0):= (others => '0');
    signal import_ADDR                         : std_logic := '0';
    signal ende_ausgabe              : std_logic := '0';
    signal theend                    : std_logic := '0';
    signal LaDatenOutZwischenspeicher: std_logic_vector(DATA_WIDTH-1 downto 0);
    signal KMOutZwischenspeicher     : std_logic_vector(31 downto 0) := (others => '0');
    signal send                      : std_logic_vector(7 downto 0)  := (others => '0');


begin

    assert(DATA_WIDTH >= 8) report "DATA_WIDTH has to be at least 8 bits" severity error;


    process(init_statemachine)begin
      case init_statemachine is
              when init => stateDebug <= x"11";
              when Text_c => stateDebug <= x"BB";
              when wait_Import => stateDebug <= x"BB";
              when Logic_Analyser => stateDebug <= x"CC";
              when delay => stateDebug <= x"AA";
              when Trigger => stateDebug <= x"22";
              when Masks => stateDebug <= x"33";
              when Mask => stateDebug <= x"44";
              when Value => stateDebug <= x"55";
              when Last_Masks => stateDebug <= x"66";
              when Mask_last => stateDebug <= x"77";
              when Value_last => stateDebug <= x"88";
              when Datenausgabe => stateDebug <= x"99";
        end case;
     end process;

    process (clk, rst)


    begin

        if rst = '1' then
           K_s <= 0;
           M_s <= 0;
           init_statemachine <= init;
           init_Output       <= start;

           Mask_s            <= (others => '0');
           Value_s           <= (others => '0');
           Mask_last_s       <= (others => '0');
           Value_last_s      <= (others => '0');
           delay_s           <= (others => '0');

            DataValid_HOST   <= '0';
            DatenOut_HOST    <= (others => '0');
            TriggerActive_LA <= '0';
            Trigger_LA       <= '0';
            NextData_LA      <= '0';

            Cancel_s         <= '0';


            zaehler <= (others => '0');
            import_ADDR <= '0';
            LaDatenOutZwischenspeicher <= (others => '0');
            KMOutZwischenspeicher <= (others => '0');
            ende_ausgabe <= '0';
            theend <= '0';




        elsif rising_edge(clk) then

            if ce = '1' then
                Cancel_s <=  '0';
                DataValid_Host <= '0';
                case init_statemachine is
                when init =>
                    if Full_LA = '1' then
                            NextData_LA <= '1';
                            init_statemachine <= Datenausgabe;
                            zaehler <= (others => '0');
                            LaDatenOutZwischenspeicher <= (others => '0');
                            ende_ausgabe <= '0';
                            theend <= '0';
                    end if;

                    if DatenInValid = '1' then
                        if DatenIn_Befehle = Get_ID then
                            init_statemachine <= Text_c;
                        end if;


                        if DatenIn_Befehle = KMout_c then
                            zaehler <= (others => '0');
                            --x <= '0';
                            KMOutZwischenspeicher <= (others => '0');
                            init_statemachine <= wait_Import;
                            import_ADDR <= '0';
                        end if;

                        if DatenIn_Befehle = Start_c then
                            TriggerActive_LA <= '1';
                        end if ;

                        if DatenIn_Befehle = set_Trigger_c then
                            Trigger_LA <= '1';
                        end if ;

                        if Cancel_s = '1' then
                            TriggerActive_LA <= '0';
                        end if ;

                        if DatenIn_Befehle = Trigger_c then
                            init_statemachine <= Trigger;
                        end if ;

                        if DatenIn_Befehle = Logic_Analyser_c then
                            init_statemachine <= Logic_Analyser;
                        end if ;

                    end if;

                when Text_c =>

                    case init_Output is
                    when start =>
                        if DatenReady_HOST = '1' then
                            init_Output <= Zwischenspeicher;
                            send <= I;
                            zaehler <= (others => '0');
                        end if;

                    when Zwischenspeicher =>
                        if DatenReady_HOST = '1' then
                            DatenOut_HOST <= send;
                            DataValid_HOST <= '1';
                            Zaehler <= Zaehler + 1;
                            init_Output <= schieben;
                        end if;
                     when schieben =>
                        DataValid_HOST <= '0';
                        init_Output <= next_Data;

                    when next_Data =>

                       if Zaehler = to_unsigned(1, Zaehler'length) then
                            send <= D;
                             init_Output <= Zwischenspeicher;
                       end if ;
                       if Zaehler = to_unsigned(2, Zaehler'length) then
                            send <= B;
                            init_Output <= Zwischenspeicher;
                       end if ;
                       if Zaehler = to_unsigned(3, Zaehler'length) then
                            send <= G;
                            init_Output <= Zwischenspeicher;
                       end if ;
                       if Zaehler = to_unsigned(4, Zaehler'length) then
                            init_Output <= start;
                            init_statemachine <= init;
                       end if ;

                    end case;


                when wait_Import =>

                    case init_Output is
                    when start =>
                        if DatenReady_HOST = '1' then
                            KMOutZwischenspeicher <= DATA_WIDTH_slv;
                            init_Output <= Zwischenspeicher;
                        end if;

                    when Zwischenspeicher =>
                        if DatenReady_HOST = '1' then
                            DatenOut_HOST <= KMOutZwischenspeicher(DatenOut_HOST'range);
                            DataValid_HOST <= '1';
                            KMOutZwischenspeicher <= x"00" & KMOutZwischenspeicher( KMOutZwischenspeicher'left downto DatenOut_HOST'length);
                            Zaehler <= Zaehler + 1;
                            init_Output <= schieben;
                        end if;

                    when schieben =>
                        DataValid_HOST <= '0';

                        if DatenReady_HOST = '0' then
                            init_Output <= Zwischenspeicher;
                        end if;

                        if Zaehler = to_unsigned(4, Zaehler'length) then
                            if import_ADDR = '0' then
                                init_Output <= next_Data;
                            end if;
                        end if ;

                        if Zaehler = to_unsigned(4, Zaehler'length) then
                            if import_ADDR = '1' then
                                init_Output <= start;
                                init_statemachine <= init;
                            end if;
                        end if;

                    when next_Data =>

                        if DatenReady_HOST = '1' then
                            Zaehler <= (others => '0');
                            import_ADDR <= '1';
                            KMOutZwischenspeicher <= ADDR_WIDTH_slv;
                            init_Output <= Zwischenspeicher;
                        end if;

                    end case;

                when Logic_Analyser =>
                    M_s <= 0;

                    if DatenInValid = '1' then
                        if DatenIn_Befehle = delay_c then
                            init_statemachine <= delay;
                        end if;

                        if Cancel_s = '1' then
                            init_statemachine <= init;
                        end if;

                    end if;


                when delay =>
                    if DatenInValid = '1' then

                        if M_s + 1 = M  then
                            init_statemachine <= init;
                        end if;

                        M_s <= M_s + 1;
                        delay_s <= delay_s(delay_s'left-HOST_WORD_SIZE downto 0) & DatenIn_Befehle;

                        if  Cancel_s = '1' then
                            init_statemachine <= init;
                        end if;


                    end if;


                when Trigger =>
                    if DatenInValid = '1' then

                        if DatenIn_Befehle = Masks_c then
                            init_statemachine <= Masks;
                        end if ;

                        if DatenIn_Befehle = Last_Masks_c then
                            init_statemachine <= Last_Masks;
                        end if;

                        if  Cancel_s = '1' then
                            init_statemachine <= init;

                        end if;
                    end if;

                when Masks =>
                    K_s <= 0;

                    if DatenInValid = '1' then
                        if DatenIn_Befehle = Mask_c then
                            K_s <= 0;
                            init_statemachine <= Mask;
                        end if;

                        if DatenIn_Befehle = Value_c then
                            init_statemachine <= Value;
                        end if;

                        if  Cancel_s = '1' then
                            init_statemachine <= init;
                        end if;
                    end if;

                when Mask =>
                    if DatenInValid = '1' then
                        K_s <= K_s + 1;
                        Mask_s <= Mask_s(Mask_s'left-HOST_WORD_SIZE downto 0) & DatenIn_Befehle;

                        if K_s + 1 = K   then
                            init_statemachine <= init;
                        end if;

                        --if  Cancel_s = '1' then
                        --    init_statemachine <= init;
                        --end if;
                    end if;

                when Value =>
                    if DatenInValid = '1' then
                        K_s <= K_s + 1;
                        Value_s <= Value_s(Value_s'left-HOST_WORD_SIZE downto 0) & DatenIn_Befehle;

                        if K_s + 1 = K then
                            init_statemachine <= init;
                        end if;

                        if  Cancel_s = '1' then
                            init_statemachine <= init;
                       end if;
                    end if;


                when Last_Masks =>
                    K_s <= 0 ;

                    if DatenInValid = '1' then
                        if DatenIn_Befehle = Mask_Last_c then
                            init_statemachine <= Mask_last;
                        end if;

                        if DatenIn_Befehle = Value_Last_c then
                            K_s <= 0 ;
                            init_statemachine <= Value_last;
                        end if;

                        if  Cancel_s = '1' then
                            init_statemachine <= init;
                        end if;
                    end if;

                when Mask_last =>
                    if DatenInValid = '1' then
                        K_s <= K_s + 1;
                        Mask_last_s <= Mask_last_s(Mask_last_s'left-HOST_WORD_SIZE downto 0) & DatenIn_Befehle;
                        if K_s +1 = K then
                            init_statemachine <= init;
                        end if;

                        if  Cancel_s = '1' then
                            init_statemachine <= init;
                        end if;
                    end if ;

                when Value_last =>
                    if DatenInValid = '1' then
                        K_s <= K_s + 1;
                        Value_last_s <= Value_last_s(Value_last_s'left-HOST_WORD_SIZE downto 0) & DatenIn_Befehle;

                        if K_s + 1 = K then
                            init_statemachine <= init;
                        end if;

                        if  Cancel_s = '1' then
                             init_statemachine <= init;
                         end if;
                    end if;

                when Datenausgabe =>
                    if  Cancel_s = '1' then
                        init_statemachine <= init;
                    end if;

                    if finish_LA = '1' then
                        TriggerActive_LA <= '0';
                        ende_ausgabe <= '1';
                    end if;

                    if theend = '1' then
                        init_statemachine <= init;
                        init_Output <= start;
                    end if;

                    case init_Output is
                    when start =>
                        if DataValid_LA = '1' then
                            LaDatenOutZwischenspeicher <= Daten_LA;
                            init_Output <= Zwischenspeicher;
                        end if;

                    when Zwischenspeicher =>
                        NextData_LA <= '0';
                        if DatenReady_HOST = '1' then
                            DatenOut_HOST <= LaDatenOutZwischenspeicher(DatenOut_HOST'range);
                            DataValid_HOST <= '1';
                            LaDatenOutZwischenspeicher <= x"00" & LaDatenOutZwischenspeicher( LaDatenOutZwischenspeicher'left downto DatenOut_HOST'length);
                            Zaehler <= Zaehler + 1;
                            init_Output <= schieben;
                        end if;

                    when schieben =>
                        DataValid_HOST <= '0';
                        if DatenReady_HOST = '0' then
                            init_Output <= Zwischenspeicher;
                        end if;

                        if Zaehler = K then
                            NextData_LA <= '1';
                            init_Output <= next_Data;
                        end if ;

                    when next_Data =>
                        if ende_ausgabe = '1' then
                            theend <= '1' ;
                        end if;

                        if DataValid_LA = '1' then
                            Zaehler <= (others => '0');
                            LaDatenOutZwischenspeicher <= Daten_LA;
                            init_Output <= Zwischenspeicher;
                        end if;
                    end case;
                end case ;
            end if;
        end if;
    end process ;

    delayOut_LA  <= delay_s;
    Mask_O       <= Mask_s;
    Value_O      <= Value_s;
    Mask_last_O  <= Mask_last_s;
    Value_last_O <= Value_last_s;



end architecture tab;
