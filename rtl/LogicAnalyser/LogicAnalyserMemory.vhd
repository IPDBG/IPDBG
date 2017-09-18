library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity LogicAnalyserMemory is
    generic(
         DATA_WIDTH     : natural := 8;
         ADDR_WIDTH     : natural := 8
    );
    port(
        clk             : in  std_logic;
        rst             : in  std_logic;
        ce              : in  std_logic;

        SampleEn        : in  std_logic;
        DatenIn         : in  std_logic_vector(DATA_WIDTH-1 downto 0);

        --      control sampling
        TriggerActive   : in  std_logic;
        Trigger         : in  std_logic;
        Full            : out std_logic;
        delay           : in  std_logic_vector(ADDR_WIDTH-1 downto 0);

        --Read
        DataOut         : out std_logic_vector(DATA_WIDTH-1 downto 0) ;
        DataValid       : out std_logic;
        ReqNextData     : in  std_logic;

        finish          : out std_logic
    );
end entity LogicAnalyserMemory;


architecture tab of LogicAnalyserMemory is

    component pdpRam is
        generic(
            DATA_WIDTH     : natural;
            ADDR_WIDTH     : natural;
            INIT_FILE_NAME : string;
            OUTPUT_REG     : boolean
        );
        port(
            clk          : in  std_logic;
            ce           : in  std_logic;
            writeEnable  : in  std_logic;
            writeAddress : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
            writeData    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            readAddress  : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
            readData     : out std_logic_vector(DATA_WIDTH-1 downto 0)
        );
    end component pdpRam;

    signal zaehler      : unsigned(ADDR_WIDTH-1 downto 0);
    signal Dataready    : unsigned(ADDR_WIDTH-1 downto 0) := (others => '0');
    signal we           : std_logic;

    constant adrMax     : signed(ADDR_WIDTH-1 downto 0)   := (others => '1');
    constant zaehlerMax : unsigned(ADDR_WIDTH-1 downto 0) := (others => '1');
    constant zaehlerMin : unsigned(ADDR_WIDTH-1 downto 0) := (others => '0');

    --State machine
    type WriteRingbuffer_t is(idle, armed, wait_Trigger, fill_up, write_s, spend);
    signal W_R_State    : WriteRingbuffer_t := idle;

    signal writeData    : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal Datenlesen   : std_logic_vector(DATA_WIDTH-1 downto 0):= (others => '0');

    signal Adr_w        : signed(ADDR_WIDTH-1 downto 0);
    signal Adr_r        : signed(ADDR_WIDTH-1 downto 0);

    signal delay_s      : signed(ADDR_WIDTH-1 downto 0);

begin

    process (clk, rst) begin
        if rst = '1' then
            we <= '0';
            zaehler <= (others => '0');
            Dataready <= (others => '0');
            W_R_State <= idle;
            writeData <= (others => '0');
            Adr_w <= (others => '-');
            Adr_r <= (others => '-');
            Full <= '0';
            DataValid <= '0';
            we <= '0';

        elsif rising_edge(clk) then
            if ce = '1' then
                we <= '0';
                writeData <= DatenIn;

                case W_R_State is
                when idle =>
                    finish <= '0';
                    if TriggerActive = '1' then                         -- warten auf ein pos. Signal von  TriggerActive
                        adr_r <= (others => '0');
                        W_R_State <= armed;
                        zaehler <= (others => '0');
                        Full <= '0';
                        adr_w <= (others => '1');
                        finish <= '0';
                        delay_s <= signed(delay);
                    end if;

                when armed =>
                    if TriggerActive = '0' then
                        W_R_State <= idle;
                    elsif SampleEn = '1' then
                        we <= '1';
                        adr_w <= adr_w + 1;
                        zaehler <= zaehler + 1;
                        if std_logic_vector(zaehler) = std_logic_vector(delay_s +1 ) then             --Die Mindestzeit vor dem  Trigger speichern
                            W_R_State <= wait_Trigger ;
                        end if;
                    end if;

                when wait_Trigger =>                                            -- auf den Trigger warten und weiter die Eingangswerte abspeichern
                    if TriggerActive = '0' then
                        W_R_State <= idle;
                    elsif SampleEn = '1' then
                        we <= '1';
                        adr_w <= adr_w + 1;
                        if Trigger = '1' then
                            W_R_State <= fill_up;
                            zaehler <= zaehler + 1;
                        end if;
                    end if;

                when fill_up =>                                                 -- Die Werte nach dem Trigger abspeichern
                    if TriggerActive = '0' then
                        W_R_State <= idle;
                    elsif SampleEn = '1' then
                        we <= '1';
                        adr_w <= adr_w + 1;
                        zaehler <= zaehler + 1;
                        if zaehler = zaehlerMax  then                            -- zaehler auf 111111111111111 prüfen geht leider mit (other => '1') nicht!
                            adr_r <= adr_w + 2;
                            W_R_State <= write_s;
                            Full <= '1';
                        end if;
                    end if;

                when write_s =>                                                 -- Auf ein pos. Signal von aussen warten das die Daten angekegt werden können.
                    if TriggerActive = '0' then
                        W_R_State <= idle;
                    elsif ReqNextData = '1' then
                        if Dataready = to_unsigned(2, DataReady'length) then    -- Dataready auf 000000000010 also auf 2 prüfen unabhängig von der Datenbreite!
                            DataValid <= '1';
                            Zaehler <= Zaehler - 1;
                            DataOut <= Datenlesen;
                            Dataready <= (others => '0');                       -- Dataready auf 000000000000 setzten!
                            W_R_State <= spend ;
                        else
                           Dataready <= Dataready + 1;
                       end if;
                    end if;

                when spend =>                                                   -- Auf ein Siagnal von Aussen warte, dass die Daten am Eingang abgespeichert wurden.
                    if TriggerActive = '0' then
                        W_R_State <= idle;
                    elsif ReqNextData = '0' then
                        DataValid <= '0';
                        adr_r <= adr_r + 1;
                        if zaehler   = zaehlerMin then
                            W_R_State <= idle;
                            finish <= '1';
                        else
                            W_R_State <= write_s;
                        end if;
                    end if;
                end case ;
            end if;
        end if;
    end process;



    mem: block
        signal Adrw_slv     : std_logic_vector(ADDR_WIDTH-1 downto 0);
        signal Adrr_slv     : std_logic_vector(ADDR_WIDTH-1 downto 0);
    begin

        Adrw_slv <= std_logic_vector(adr_w);
        Adrr_slv <= std_logic_vector(adr_r);




        samples : component pdpRam
            generic map(
                DATA_WIDTH     => DATA_WIDTH,
                ADDR_WIDTH     => ADDR_WIDTH,
                INIT_FILE_NAME => "",
                OUTPUT_REG     => true
            )
            port map(
                clk          => clk,
                ce           => ce,
                writeEnable  => we,
                writeAddress => Adrw_slv,
                writeData    => writeData,
                readAddress  => Adrr_slv,
                readData     => Datenlesen
            );
    end block mem;


end architecture tab;




