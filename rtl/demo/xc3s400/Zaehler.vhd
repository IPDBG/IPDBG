library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity Zaehler is
    generic(
         DATA_WIDTH     : natural := 10
    );
    port(
        clk             : in  std_logic;
        rst             : in  std_logic;
        ce              : in  std_logic;

        DatenOut        : out  std_logic_vector(DATA_WIDTH-1 downto 0);
        Debug           : out std_logic_vector(DATA_WIDTH-1 downto 0)



    );
end entity;


architecture tab of Zaehler is
    signal DatenOut_reg : std_logic_vector(DatenOut'range) := ( 0 => '1', others => '0' );
    --signal i            : signed(20 downto 0) := (others=> '0');
    --signal x            : signed(20 downto 0) := (others => '1');

begin
    DatenOut <= DatenOut_reg;
    Debug <= DatenOut_reg;

    process (clk, rst)

    begin

        if rst = '1' then
           DatenOut_reg <= ( 0 => '1', others => '0' );
        elsif rising_edge(clk) then
            if ce = '1' then
 --               if i = x then
                    DatenOut_reg <= DatenOut_reg(DatenOut'left-1 downto 0) & DatenOut_reg(DatenOut'left);
 --                   i <= (others => '0') ;
  --              else
  --                  i<= i + 1;
  --              end if;

            end if;
        end if;
    end process ;




end architecture tab;



