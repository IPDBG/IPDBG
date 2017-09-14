library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity LogicAnalyserTop is
    generic(
         DATA_WIDTH : natural := 4;        --! width of a sample
         ADDR_WIDTH : natural := 4          --! 2**ADDR_WIDTH = size if sample memory
    );
    port(
        clk            : in  std_logic;
        rst            : in  std_logic;
        ce             : in  std_logic;

        --      host interface (UART or ....)
        data_in_valid  : in  std_logic;
        data_in        : in  std_logic_vector(7 downto 0);

        data_out_ready : in  std_logic;
        data_out_valid : out std_logic;
        data_out       : out std_logic_vector(7 downto 0);

        -- LA interface
        sample_en      : in  std_logic;
        probe          : in  std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end entity LogicAnalyserTop;

architecture structure of LogicAnalyserTop is


    component LogicAnalyserMemory is
        generic(
            DATA_WIDTH : natural;
            ADDR_WIDTH : natural
        );
        port(
            clk           : in  std_logic;
            rst           : in  std_logic;
            ce            : in  std_logic;
            SampleEn      : in  std_logic;
            DatenIn       : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            TriggerActive : in  std_logic;
            Trigger       : in  std_logic;
            Full          : out std_logic;
            delay         : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
            DataOut       : out std_logic_vector(DATA_WIDTH-1 downto 0);
            DataValid     : out std_logic;
            ReqNextData   : in  std_logic;
            finish        : out std_logic
        );
    end component LogicAnalyserMemory;

    component LogicAnalyserTrigger is
        generic(
            DATA_WIDTH : natural
        );
        port(
            clk        : in  std_logic;
            rst        : in  std_logic;
            ce         : in  std_logic;
            SampleEn   : in  std_logic;
            DatenIn    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            Mask       : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            Mask_last  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            Value      : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            Value_last : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            Trigger    : out std_logic
        );
    end component LogicAnalyserTrigger;

    component LogicAnalyserController is
        generic(
            DATA_WIDTH : natural;
            ADDR_WIDTH : natural
        );
        port(
            clk              : in  std_logic;
            rst              : in  std_logic;
            ce               : in  std_logic;
            DatenInValid     : in  std_logic;
            DatenIn_Befehle  : in  std_logic_vector(7 downto 0);
            DatenReady_HOST  : in  std_logic;
            DataValid_HOST   : out std_logic;
            DatenOut_HOST    : out std_logic_vector(7 downto 0);
            Mask_O           : out std_logic_vector(DATA_WIDTH-1 downto 0);
            Value_O          : out std_logic_vector(DATA_WIDTH-1 downto 0);
            Mask_last_O      : out std_logic_vector(DATA_WIDTH-1 downto 0);
            Value_last_O     : out std_logic_vector(DATA_WIDTH-1 downto 0);
            delayOut_LA      : out std_logic_vector(ADDR_WIDTH-1 downto 0);
            TriggerActive_LA : out std_logic;
            Trigger_LA       : out std_logic;
            Full_LA          : in  std_logic;
            Daten_LA         : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            NextData_LA      : out std_logic;
            DataValid_LA     : in  std_logic;
            finish_LA        : in  std_logic
        );
    end component LogicAnalyserController;

    component IpdbgEscaping is
        generic(
            DATA_WIDTH : natural
        );
        port(
            clk            : in  std_logic;
            rst            : in  std_logic;
            ce             : in  std_logic;
            data_in_valid  : in  std_logic;
            data_in        : in  std_logic_vector(7 downto 0);
            data_out_valid : out std_logic;
            data_out       : out std_logic_vector(7 downto 0);
            reset          : out std_logic
        );
    end component IpdbgEscaping;

    signal Trigger_end        : std_logic := '0';
    signal TriggerActive_LA   : std_logic := '0';
    signal Trigger_LA         : std_logic := '0';
    signal Full_s             : std_logic := '0';
    signal TriggerActive      : std_logic := '0';
    signal DataValid          : std_logic := '0';
    signal ReqNextData        : std_logic := '0';
    signal Trigger_s          : std_logic := '0';
    signal NextData_LA        : std_logic := '0';
    signal DataValid_LA       : std_logic := '0';
    signal finish_LA          : std_logic := '0';
    signal delay              : std_logic_vector(ADDR_WIDTH-1 downto 0) := (others => '0');
    signal Mask               : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal Mask_last          : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal Value              : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal Value_last         : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal Mask_O             : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal Value_O            : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal Mask_last_O        : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal Value_last_O       : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal delayOut_LA        : std_logic_vector(ADDR_WIDTH-1 downto 0) := (others => '0');
    signal Daten_LA           : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal data_in_valid_uesc : std_logic;
    signal data_in_uesc       : std_logic_vector(7 downto 0);
    signal reset              : std_logic;
begin
    process (clk, rst) begin
        if rst = '1' then
            Trigger_end <= '0';
        elsif rising_edge(clk) then
            if ce = '1' then
                Trigger_end <= Trigger_LA or trigger_s;
            end if;
        end if;
    end process;


    Memory : component LogicAnalyserMemory
        generic map(
            DATA_WIDTH => DATA_WIDTH,
            ADDR_WIDTH => ADDR_WIDTH
        )
        port map(
            clk           => clk,
            rst           => reset,
            ce            => ce,
            SampleEn      => sample_en,
            DatenIn       => probe,
            TriggerActive => TriggerActive_LA,
            Trigger       => Trigger_end,
            Full          => Full_s,
            delay         => delay,
            DataOut       => Daten_LA,
            DataValid     => DataValid_LA,
            ReqNextData   => NextData_LA,
            finish        => finish_LA
        );


    Trigger : component LogicAnalyserTrigger
        generic map(
            DATA_WIDTH => DATA_WIDTH
        )
        port map(
            clk          => clk,
            rst          => reset,
            ce           => ce,
            SampleEn     => sample_en,
            DatenIn      => probe,
            Mask         => Mask_O,
            Mask_last    => Mask_last_O,
            Value        => Value_O,
            Value_last   => Value_last_O,
            Trigger      => Trigger_s
        );

    Controller : component LogicAnalyserController
        generic map(
            DATA_WIDTH => DATA_WIDTH,
            ADDR_WIDTH => ADDR_WIDTH
        )
        port map(
            clk              => clk,
            rst              => reset,
            ce               => ce,
            DatenInValid     => data_in_valid_uesc,
            DatenIn_Befehle  => data_in_uesc,
            DatenReady_HOST  => data_out_ready,
            DataValid_HOST   => data_out_valid,
            DatenOut_HOST    => data_out,
            Mask_O           => Mask_O,
            Value_O          => Value_O,
            Mask_last_O      => Mask_last_O,
            Value_last_O     => Value_last_O,
            delayOut_LA      => delay,
            TriggerActive_LA => TriggerActive_LA,
            Trigger_LA       => Trigger_LA,
            Full_LA          => Full_s,
            Daten_LA         => Daten_LA,
            NextData_LA      => NextData_LA,
            DataValid_LA     => DataValid_LA,
            finish_LA        => finish_LA
        );

    Escaping : component IpdbgEscaping
        generic map(
            DATA_WIDTH => DATA_WIDTH
        )
        port map(
            clk            => clk,
            rst            => rst,
            ce             => ce,
            data_in_valid  => data_in_valid,
            data_in        => data_in,
            data_out_valid => data_in_valid_uesc,
            data_out       => data_in_uesc,
            reset          => reset
        );

end architecture structure;
