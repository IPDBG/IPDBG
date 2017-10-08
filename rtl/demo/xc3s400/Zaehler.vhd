library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity Zaehler is
    generic(
         DATA_WIDTH : natural := 10
    );
    port(
        clk      : in  std_logic;
        rst      : in  std_logic;
        ce       : in  std_logic;

        DatenOut : out  std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end entity;


architecture tab of Zaehler is
    signal DatenOut_reg : std_logic_vector(DatenOut'range);
begin
    DatenOut <= DatenOut_reg;

    process (clk)begin
        if rising_edge(clk) then
            if rst = '1' then
                DatenOut_reg <= ( 0 => '1', others => '0' );
            else
                if ce = '1' then
                    DatenOut_reg <= DatenOut_reg(DatenOut'left-1 downto 0) & DatenOut_reg(DatenOut'left);
                end if;
            end if;
        end if;
    end process ;

end architecture tab;
