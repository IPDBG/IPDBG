library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Escape is
    port(
        clk          : in  std_logic;
        rst          : in  std_logic;
        ce           : in  std_logic;

        DataInValid  : in std_logic;
        DataIn       : in std_logic_vector(7 downto 0);   --Eingangsdaten die Überprüft werden müssen
        DataOutValid : out std_logic;
        DataOut      : out std_logic_vector(7 downto 0);   --Eingangsdaten die Überprüft werden müssen.

        reset        : out std_logic
    );
end entity;


architecture behavioral of Escape is
    constant EscapeSymbol : std_logic_vector (7 downto 0) := x"55"; --55
    constant ResetSymbol  : std_logic_vector (7 downto 0) := x"EE"; --EE

    type EscapingStates_t is(Normal_s, Escaping_s);
    signal state          : EscapingStates_t :=  Normal_s;
begin

    process (clk, rst) begin
        if rst = '1' then
            reset <= '0';
            DataOut <= (others => '0');
            state <= Normal_s;
            DataOutValid <= '0';
        elsif rising_edge(clk) then
            if ce = '1' then
                DataOutValid <= '0';
                reset <= '0';
                DataOut <= DataIn;
                if DataInValid = '1' then
                    case state is
                    when Normal_s =>
                        if DataIn = EscapeSymbol then
                            state <= Escaping_s;
                        elsif DataIn = ResetSymbol  then
                            reset <= '1';
                        else
                            DataOutValid <= '1';
                        end if;
                    when Escaping_s =>
                        state <= Normal_s;
                        DataOutValid <= '1';
                    end case;
                end if;
            end if;
        end if;
    end process;

end architecture behavioral;
