library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity Escape is
    port(
        clk             : in  std_logic;
        rst             : in  std_logic;
        ce              : in  std_logic;

        DataInValid    : in std_logic;
        DataIn          : in std_logic_vector(7 downto 0);   --Eingangsdaten die Überprüft werden müssen
        DataOutValid   : out std_logic;
        DataOut         : out std_logic_vector(7 downto 0);   --Eingangsdaten die Überprüft werden müssen.

        reset           : out std_logic

         );
end entity;


architecture tab of Escape is

    constant Escape     : std_logic_vector (7 downto 0) := "01010101"; --55
    constant Reset_c    : std_logic_vector (7 downto 0) := "11101110"; --EE




    type EscapingStates_t is(Normal_s, Escaping_s);
    signal state    : EscapingStates_t :=  Normal_s;

begin


    process (clk, rst)


    begin

        if rst = '1' then
            reset <= '0';
            DataOut <= (others => '0');
            state <= Normal_s;
            DataOutValid <= '0';

        elsif rising_edge(clk) then

            DataOutValid <= '0';
            reset <= '0';
            case state is
            when Normal_s =>
                if DataInValid = '1' then
                    if DataIn = Escape then
                        state <= Escaping_s;
                    elsif DataIn = Reset_c  then
                        reset <= '1';
                    else
                        DataOut <= DataIn;
                        DataOutValid <= '1';
                    end if;
                end if;
            when Escaping_s =>
                if DataInValid = '1' then
                    state <= Normal_s;
                    DataOut <= DataIn;
                    DataOutValid <= '1';
                end if;
            end case;
        end if;
    end process ;
end architecture tab;
