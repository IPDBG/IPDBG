library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity Trigger is
    generic(
         DATA_WIDTH     : natural := 8
    );
    port(
        clk             : in  std_logic;
        rst             : in  std_logic;
        ce              : in  std_logic;

        SampleEn        : in  std_logic;
        DatenIn         : in std_logic_vector(DATA_WIDTH-1 downto 0);                           --Eingangsdaten die Überprüft werden müssen.

        Mask            : in std_logic_vector(DATA_WIDTH-1 downto 0);                           --Mask gibt an welche Bits von den Ausgangsdaten relevant sind.
        Mask_last       : in std_logic_vector(DATA_WIDTH-1 downto 0);                           --Mask_last gibt an, welche Daten von den letzten Zyklus des DatenIn relevant sind.
        Value           : in std_logic_vector(DATA_WIDTH-1 downto 0);                           --VarMask gibt an, welche Daten am DatenIn anliegen sollten
        Value_last      : in std_logic_vector(DATA_WIDTH-1 downto 0);                           --VarMask gibt an, welche Daten beim letzten Zyklus hätten anliegen müssen.

        Trigger         : out std_logic                                                         --Trigger ist der Trigger, welcher dann auf den Logic Analyser geführt wird.

         );
end entity;


architecture tab of Trigger is
    signal DataIn_last  : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');           -- Daten des letzten Clocks
    signal Mask_n       : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal Mask_last_n  : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    constant allOnes    : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '1');           -- alles "1"

begin

    Mask_last_n <= not Mask_last;
    Mask_n      <= not Mask;

    process (clk, rst)
        variable currentSampleEqValue         : std_logic_vector(DATA_WIDTH-1 downto 0):= (others => '0');
        variable lastSampleMatch              : std_logic_vector(DATA_WIDTH-1 downto 0):= (others => '0');
        variable lastAndCurrentSampleMatch    : std_logic_vector(DATA_WIDTH-1 downto 0):= (others => '0');
        variable lastSampleEqValue            : std_logic_vector(DATA_WIDTH-1 downto 0):= (others => '0');

    begin

        if rst = '1' then
            Trigger <= '0';

        elsif rising_edge(clk) then
            if ce = '1' then
                if SampleEn = '1' then

                    for idx in 0 to DATA_WIDTH-1 loop
                        DataIn_last(idx) <= DatenIn(idx);

                        currentSampleEqValue(idx) := '0';
                        if DatenIn(idx) = Value(idx) then
                            currentSampleEqValue(idx) := '1';
                        end if;


                        lastSampleEqValue(idx) := '0';
                        if DataIn_last(idx) = Value_last(idx) then
                            lastSampleEqValue(idx) := '1';
                        end if;

                        lastSampleMatch (idx):= lastSampleEqValue(idx) or Mask_last_n(idx);
                        lastAndCurrentSampleMatch(idx) := lastSampleMatch(idx) and currentSampleEqValue(idx);

                    end loop;

                    if (lastAndCurrentSampleMatch or Mask_n) = allOnes then
                        Trigger <= '1';
                    else
                        Trigger <= '0';
                    end if;
                end if;
            end if;
        end if;
    end process ;
end architecture tab;



